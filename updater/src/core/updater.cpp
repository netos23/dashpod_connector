#include "core/updater.h"

#include <thread>

#include "cache/lifecycle.h"
#include "cache/signing.h"
#include "core/error.h"
#include "core/inflate.h"
#include "core/updater_lock.h"
#include "core/yaml.h"
#include "net/network.h"
#include "util/logging.h"
#include "util/time.h"

namespace dashpod::core {

namespace {

cache::UpdaterState load_state(const UpdateConfig& cfg) {
    return cache::UpdaterState::load_or_new_on_error(
        cfg.storage_dir, cfg.download_dir, cfg.release_version,
        cfg.patch_public_key, cfg.patch_verification);
}

void with_state(const std::function<void(cache::UpdaterState&)>& f) {
    auto cfg = copy_config();
    auto state = load_state(cfg);
    f(state);
}

bool check_inflated_hash(const std::filesystem::path& path,
                          const std::string& expected) {
    try {
        return signing::hash_file(path) == expected;
    } catch (const std::exception& e) {
        DASHPOD_ERROR("check_inflated_hash: ", e.what());
        return false;
    }
}

void roll_back_patches_if_needed(const std::vector<std::size_t>& patch_numbers) {
    with_state([&](cache::UpdaterState& state) {
        for (auto n : patch_numbers) state.uninstall_patch(n);
    });
}

void handle_prior_boot_failure_if_necessary() {
    with_state([&](cache::UpdaterState& state) {
        auto crash = state.lifecycle().detect_boot_crash_on_init();
        if (!crash.has_value()) return;

        auto cfg = copy_config();
        const std::uint64_t now = time::unix_timestamp();
        auto msg = std::string("crash_recovery: patch ") +
                   std::to_string(*crash) +
                   " failed to boot (detected_at=" + std::to_string(now) + ")";

        net::PatchEvent ev;
        ev.app_id           = cfg.app_id;
        ev.arch             = current_arch();
        ev.client_id        = state.client_id();
        ev.identifier       = net::EventType::PatchInstallFailure;
        ev.patch_number     = *crash;
        ev.platform         = current_platform();
        ev.release_version  = cfg.release_version;
        ev.timestamp        = now;
        ev.message          = msg;
        state.queue_event(ev);
    });
}

UpdateStatus update_internal(const UpdaterLockState& /*lock*/,
                              std::optional<std::string> channel_override) {
    auto cfg = copy_config();
    if (channel_override.has_value()) cfg.channel = *channel_override;
    if (!cfg.network_hooks) {
        throw UpdaterError(UpdaterError::Kind::Network, "No network hooks");
    }

    // 1. Drain queued events (up to 3 per cycle).
    std::vector<net::PatchEvent> events_to_send;
    with_state([&](cache::UpdaterState& state) {
        events_to_send = state.copy_events(3);
    });
    for (const auto& ev : events_to_send) {
        try {
            net::send_patch_event(ev, cfg);
        } catch (const std::exception& e) {
            DASHPOD_ERROR("Failed to report event: ", e.what());
        }
    }

    // Build the request after clearing the queue (best-effort — racing
    // a queue addition is fine; the next cycle catches it).
    net::PatchCheckRequest req;
    with_state([&](cache::UpdaterState& state) {
        try { state.clear_events(); }
        catch (const std::exception& e) {
            DASHPOD_ERROR("Failed to clear events: ", e.what());
        }
        std::optional<std::size_t> current = std::nullopt;
        if (auto cur = state.currently_booting_patch(); cur.has_value()) {
            current = cur->number;
        }
        req = net::PatchCheckRequest::from_config(cfg, state.client_id(), current);
    });

    // 2. Patch check.
    auto response = cfg.network_hooks->patch_check_request_fn(
        net::patches_check_url(cfg.base_url), req);
    DASHPOD_INFO("Patch check response received");

    // 3. Apply server-driven rollbacks.
    if (response.rolled_back_patch_numbers.has_value()) {
        roll_back_patches_if_needed(*response.rolled_back_patch_numbers);
    }

    if (!response.patch_available || !response.patch.has_value()) {
        return UpdateStatus::NoUpdate;
    }
    const auto& patch = *response.patch;

    // 4. Plan the download.
    cache::DownloadAction action;
    with_state([&](cache::UpdaterState& state) {
        action = state.lifecycle().decide_start(
            patch.number, patch.download_url, patch.hash);
    });
    if (auto* skip = std::get_if<cache::DownloadActionSkip>(&action)) {
        if (skip->reason == cache::SkipReason::KnownBad) {
            return UpdateStatus::UpdateIsBadPatch;
        }
        return UpdateStatus::NoUpdate;
    }

    // 5. Download (unless DownloadActionComplete says we already have it).
    const auto download_path = cache::download_artifact_path(
        cfg.download_dir, patch.number);
    if (!std::holds_alternative<cache::DownloadActionComplete>(action)) {
        std::uint64_t resume_from = 0;
        if (auto* r = std::get_if<cache::DownloadActionResume>(&action)) {
            resume_from = r->offset;
            DASHPOD_INFO("Resuming download from byte ", resume_from);
        }
        // Record Downloading BEFORE the GET so a crash mid-stream is
        // resumable on the next cycle.
        with_state([&](cache::UpdaterState& state) {
            state.lifecycle().record_download_started(
                patch.number, patch.download_url, patch.hash,
                patch.hash_signature);
        });

        auto dl = net::download_to_path(*cfg.network_hooks, patch.download_url,
                                         download_path, resume_from);
        if (dl.content_length.has_value() &&
            *dl.content_length != dl.total_bytes) {
            with_state([&](cache::UpdaterState& state) {
                state.uninstall_patch(patch.number);
            });
            throw UpdaterError(UpdaterError::Kind::BadServerResponse,
                "Download size mismatch: expected " +
                std::to_string(*dl.content_length) + ", got " +
                std::to_string(dl.total_bytes));
        }
        with_state([&](cache::UpdaterState& state) {
            state.lifecycle().record_download_complete(patch.number,
                                                       dl.total_bytes);
        });
    }

    // 6. Inflate + check hash. Stubbed until zstd+bidiff are wired up.
    const auto installed_path =
        cache::installed_artifact_path(cfg.storage_dir, patch.number);
    if (!cfg.file_provider) {
        throw UpdaterError(UpdaterError::Kind::InvalidState,
            "Missing file_provider for patch inflate");
    }
    auto base = cfg.file_provider->open();
    if (!base) {
        throw UpdaterError(UpdaterError::Kind::Io, "Failed to open base library");
    }
    if (!inflate_patch(download_path, *base, installed_path)) {
        with_state([&](cache::UpdaterState& state) {
            state.lifecycle().mark_bad(patch.number,
                                        cache::BadReason::InvalidPatchBytes);
            state.lifecycle().recompute_next_boot();
        });
        throw UpdaterError(UpdaterError::Kind::BadPatch,
            "Failed to inflate patch " + std::to_string(patch.number));
    }
    if (!check_inflated_hash(installed_path, patch.hash)) {
        with_state([&](cache::UpdaterState& state) {
            state.lifecycle().mark_bad(patch.number,
                                        cache::BadReason::InstallHashMismatch);
            state.lifecycle().recompute_next_boot();
        });
        throw UpdaterError(UpdaterError::Kind::BadPatch,
            "Hash mismatch for patch " + std::to_string(patch.number));
    }

    std::error_code ec;
    auto installed_size = std::filesystem::file_size(installed_path, ec);
    if (ec) {
        throw UpdaterError(UpdaterError::Kind::Io,
            "Failed to stat installed artifact: " + ec.message());
    }

    with_state([&](cache::UpdaterState& state) {
        state.lifecycle().record_install_complete(patch.number, installed_size);
        state.lifecycle().promote_to_next_boot(patch.number);
    });

    // 7. Fire a PatchDownload event on a detached thread so the
    //    caller's update() returns without blocking on the network.
    auto cfg_copy = cfg;
    auto client_id = std::string();
    with_state([&](cache::UpdaterState& state) { client_id = state.client_id(); });
    auto patch_number = patch.number;
    std::thread([cfg_copy, client_id, patch_number]() {
        net::PatchEvent ev;
        ev.app_id          = cfg_copy.app_id;
        ev.arch            = current_arch();
        ev.client_id       = client_id;
        ev.identifier      = net::EventType::PatchDownload;
        ev.patch_number    = patch_number;
        ev.platform        = current_platform();
        ev.release_version = cfg_copy.release_version;
        ev.timestamp       = time::unix_timestamp();
        try {
            net::send_patch_event(ev, cfg_copy);
        } catch (const std::exception& e) {
            DASHPOD_ERROR("Failed to report patch download: ", e.what());
        }
    }).detach();

    return UpdateStatus::UpdateInstalled;
}

}  // namespace

std::string to_string(UpdateStatus s) {
    switch (s) {
        case UpdateStatus::NoUpdate:         return "No update";
        case UpdateStatus::UpdateInstalled:  return "Update installed";
        case UpdateStatus::UpdateHadError:   return "Update had error";
        case UpdateStatus::UpdateIsBadPatch:
            return "Update available but previously failed to install. Not installing.";
        case UpdateStatus::UpdateInProgress: return "Update already in progress";
    }
    return "Unknown";
}

void init(const AppConfig& app_config,
          std::shared_ptr<IExternalFileProvider> file_provider,
          const std::string& yaml) {
    auto parsed = yaml::parse_yaml(yaml);
    if (!parsed.ok) {
        throw UpdaterError(UpdaterError::Kind::InvalidArgument,
            "Invalid yaml: " + parsed.error);
    }
    if (app_config.original_libapp_paths.empty()) {
        throw UpdaterError(UpdaterError::Kind::InvalidArgument,
            "original_libapp_paths must be non-empty");
    }
    auto libapp_path = std::filesystem::path(app_config.original_libapp_paths.front());

    auto hooks = std::make_shared<net::NetworkHooks>();
    if (!set_config(app_config, std::move(file_provider),
                     std::move(libapp_path), parsed.value, std::move(hooks))) {
        throw UpdaterError(UpdaterError::Kind::AlreadyInitialized,
            "Updater already initialized");
    }

    try {
        handle_prior_boot_failure_if_necessary();
    } catch (const std::exception& e) {
        DASHPOD_ERROR("Failed to clean up after prior failed patch: ", e.what());
    }
}

bool should_auto_update() {
    auto cfg = copy_config();
    return cfg.auto_update;
}

bool check_for_downloadable_update(std::optional<std::string> channel) {
    auto cfg = copy_config();
    if (channel.has_value()) cfg.channel = *channel;
    if (!cfg.network_hooks) {
        throw UpdaterError(UpdaterError::Kind::Network, "No network hooks");
    }

    std::string client_id;
    std::optional<std::size_t> current;
    with_state([&](cache::UpdaterState& state) {
        client_id = state.client_id();
        if (auto cur = state.currently_booting_patch(); cur.has_value()) {
            current = cur->number;
        }
    });

    auto req = net::PatchCheckRequest::from_config(cfg, client_id, current);
    auto response = cfg.network_hooks->patch_check_request_fn(
        net::patches_check_url(cfg.base_url), req);

    if (response.rolled_back_patch_numbers.has_value()) {
        roll_back_patches_if_needed(*response.rolled_back_patch_numbers);
    }
    if (!response.patch.has_value()) return false;
    const auto& patch = *response.patch;

    cache::DownloadAction action;
    with_state([&](cache::UpdaterState& state) {
        action = state.lifecycle().decide_start(
            patch.number, patch.download_url, patch.hash);
    });
    return std::holds_alternative<cache::DownloadActionFresh>(action) ||
           std::holds_alternative<cache::DownloadActionResume>(action) ||
           std::holds_alternative<cache::DownloadActionComplete>(action);
}

UpdateStatus update(std::optional<std::string> channel) {
    try {
        UpdateStatus result = UpdateStatus::NoUpdate;
        with_updater_thread_lock([&](const UpdaterLockState& lock) {
            result = update_internal(lock, std::move(channel));
        });
        return result;
    } catch (const UpdaterError& e) {
        if (e.kind() == UpdaterError::Kind::UpdateAlreadyInProgress) {
            return UpdateStatus::UpdateInProgress;
        }
        throw;
    }
}

void start_update_thread() {
    std::thread([]() {
        try {
            auto status = update(std::nullopt);
            DASHPOD_INFO("Update thread finished with status: ",
                          to_string(status));
        } catch (const std::exception& e) {
            DASHPOD_ERROR("Update thread failed: ", e.what());
        }
    }).detach();
}

std::optional<cache::PatchInfo> next_boot_patch() {
    std::optional<cache::PatchInfo> out;
    with_state([&](cache::UpdaterState& state) {
        out = state.next_boot_patch();
    });
    return out;
}

std::optional<cache::PatchInfo> running_patch() {
    std::optional<cache::PatchInfo> out;
    with_state([&](cache::UpdaterState& state) {
        out = state.running_patch();
    });
    return out;
}

void validate_next_boot_patch() {
    with_state([&](cache::UpdaterState& state) {
        state.validate_next_boot_patch();
    });
}

void report_launch_start() {
    DASHPOD_INFO("Reporting launch start.");
    with_state([&](cache::UpdaterState& state) {
        auto nbp = state.next_boot_patch();
        state.set_running_patch(nbp.has_value()
                                ? std::optional<std::size_t>(nbp->number)
                                : std::nullopt);
        if (nbp.has_value()) {
            state.record_boot_start_for_patch(nbp->number);
        }
    });
}

void report_launch_failure() {
    DASHPOD_INFO("Reporting launch failure.");
    auto cfg = copy_config();
    with_state([&](cache::UpdaterState& state) {
        auto booting = state.currently_booting_patch();
        if (!booting.has_value()) {
            throw UpdaterError(UpdaterError::Kind::InvalidState,
                "currently_booting_patch is None");
        }
        try {
            state.record_boot_failure_for_patch(booting->number);
        } catch (const std::exception& e) {
            DASHPOD_ERROR("Failed to record boot failure: ", e.what());
        }
        net::PatchEvent ev;
        ev.app_id          = cfg.app_id;
        ev.arch            = current_arch();
        ev.client_id       = state.client_id();
        ev.identifier      = net::EventType::PatchInstallFailure;
        ev.patch_number    = booting->number;
        ev.platform        = current_platform();
        ev.release_version = cfg.release_version;
        ev.timestamp       = time::unix_timestamp();
        ev.message         = std::string("engine_report: patch ") +
                              std::to_string(booting->number) + " failed to launch";
        state.queue_event(ev);
    });
}

void report_launch_success() {
    DASHPOD_INFO("Reporting launch success.");
    auto cfg = copy_config();
    with_state([&](cache::UpdaterState& state) {
        auto booting = state.currently_booting_patch();
        if (!booting.has_value()) return;

        auto previous_boot = state.last_successfully_booted_patch();
        state.record_boot_success();

        auto current_boot = state.last_successfully_booted_patch();
        if (previous_boot.has_value() && current_boot.has_value() &&
            previous_boot->number == current_boot->number) {
            return;  // unchanged — don't report
        }

        auto client_id     = state.client_id();
        auto patch_number  = booting->number;
        std::thread([cfg, client_id, patch_number]() {
            net::PatchEvent ev;
            ev.app_id          = cfg.app_id;
            ev.arch            = current_arch();
            ev.client_id       = client_id;
            ev.identifier      = net::EventType::PatchInstallSuccess;
            ev.patch_number    = patch_number;
            ev.platform        = current_platform();
            ev.release_version = cfg.release_version;
            ev.timestamp       = time::unix_timestamp();
            try {
                net::send_patch_event(ev, cfg);
            } catch (const std::exception& e) {
                DASHPOD_ERROR("Failed to report install success: ", e.what());
            }
        }).detach();
    });
}

}  // namespace dashpod::core
