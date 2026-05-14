#include "cache/lifecycle.h"

#include <system_error>

#include "cache/disk_io.h"
#include "cache/signing.h"
#include "core/error.h"
#include "util/logging.h"
#include "util/time.h"

namespace fs = std::filesystem;

namespace dashpod::cache {

namespace {

constexpr const char* PATCHES_DIR     = "patches";
constexpr const char* PATCH_STATE     = "state.json";
constexpr const char* POINTERS_FILE   = "pointers.json";
constexpr const char* INSTALLED_NAME  = "dlc.vmcode";

}  // namespace

std::string to_string(BadReason r) {
    switch (r) {
        case BadReason::BootCrash:           return "BootCrash";
        case BadReason::InvalidPatchBytes:   return "InvalidPatchBytes";
        case BadReason::InstallHashMismatch: return "InstallHashMismatch";
        case BadReason::ValidationFailed:    return "ValidationFailed";
    }
    return "BootCrash";
}

std::optional<BadReason> bad_reason_from_string(const std::string& s) {
    if (s == "BootCrash")           return BadReason::BootCrash;
    if (s == "InvalidPatchBytes")   return BadReason::InvalidPatchBytes;
    if (s == "InstallHashMismatch") return BadReason::InstallHashMismatch;
    if (s == "ValidationFailed")    return BadReason::ValidationFailed;
    return std::nullopt;
}

fs::path download_artifact_path(const fs::path& download_root, std::size_t n) {
    return download_root / std::to_string(n);
}

fs::path installed_artifact_path(const fs::path& state_root, std::size_t n) {
    return state_root / PATCHES_DIR / std::to_string(n) / INSTALLED_NAME;
}

// ---------------- JSON (de)serialisation ----------------

namespace json {

nlohmann::json patch_state_to_json(const PatchState& s) {
    nlohmann::json j;
    std::visit([&j](auto&& v) {
        using T = std::decay_t<decltype(v)>;
        if constexpr (std::is_same_v<T, StateDownloading>) {
            j["kind"] = "Downloading";
            j["url"]  = v.url;
            j["hash"] = v.hash;
            j["signature"] = v.signature.has_value()
                ? nlohmann::json(*v.signature) : nlohmann::json(nullptr);
        } else if constexpr (std::is_same_v<T, StateDownloaded>) {
            j["kind"] = "Downloaded";
            j["url"]  = v.url;
            j["hash"] = v.hash;
            j["signature"] = v.signature.has_value()
                ? nlohmann::json(*v.signature) : nlohmann::json(nullptr);
            j["size"] = v.size;
        } else if constexpr (std::is_same_v<T, StateInstalled>) {
            j["kind"] = "Installed";
            j["signature"] = v.signature.has_value()
                ? nlohmann::json(*v.signature) : nlohmann::json(nullptr);
            j["size"] = v.size;
        } else if constexpr (std::is_same_v<T, StateBad>) {
            j["kind"]   = "Bad";
            j["reason"] = to_string(v.reason);
            j["hash"]      = v.hash.has_value()      ? nlohmann::json(*v.hash)      : nlohmann::json(nullptr);
            j["signature"] = v.signature.has_value() ? nlohmann::json(*v.signature) : nlohmann::json(nullptr);
            j["size"]      = v.size.has_value()      ? nlohmann::json(*v.size)      : nlohmann::json(nullptr);
        }
    }, s);
    return j;
}

static std::optional<std::string> opt_string(const nlohmann::json& j, const char* key) {
    if (!j.contains(key) || j.at(key).is_null()) return std::nullopt;
    return j.at(key).get<std::string>();
}

static std::optional<std::uint64_t> opt_u64(const nlohmann::json& j, const char* key) {
    if (!j.contains(key) || j.at(key).is_null()) return std::nullopt;
    return j.at(key).get<std::uint64_t>();
}

PatchState patch_state_from_json(const nlohmann::json& j) {
    const auto kind = j.at("kind").get<std::string>();
    if (kind == "Downloading") {
        return StateDownloading{
            j.at("url").get<std::string>(),
            j.at("hash").get<std::string>(),
            opt_string(j, "signature"),
        };
    }
    if (kind == "Downloaded") {
        return StateDownloaded{
            j.at("url").get<std::string>(),
            j.at("hash").get<std::string>(),
            opt_string(j, "signature"),
            j.at("size").get<std::uint64_t>(),
        };
    }
    if (kind == "Installed") {
        return StateInstalled{
            opt_string(j, "signature"),
            j.at("size").get<std::uint64_t>(),
        };
    }
    if (kind == "Bad") {
        StateBad b;
        auto reason_str = j.at("reason").get<std::string>();
        auto reason = bad_reason_from_string(reason_str);
        if (!reason.has_value()) {
            throw UpdaterError(UpdaterError::Kind::InvalidState,
                "Unknown BadReason: " + reason_str);
        }
        b.reason    = *reason;
        b.hash      = opt_string(j, "hash");
        b.signature = opt_string(j, "signature");
        b.size      = opt_u64(j, "size");
        return b;
    }
    throw UpdaterError(UpdaterError::Kind::InvalidState,
        "Unknown PatchState kind: " + kind);
}

nlohmann::json pointers_to_json(const ReleasePointers& p) {
    nlohmann::json j;
    j["next_boot_patch"]         = p.next_boot_patch.has_value()
        ? nlohmann::json(*p.next_boot_patch) : nlohmann::json(nullptr);
    j["last_booted_patch"]       = p.last_booted_patch.has_value()
        ? nlohmann::json(*p.last_booted_patch) : nlohmann::json(nullptr);
    j["currently_booting_patch"] = p.currently_booting_patch.has_value()
        ? nlohmann::json(*p.currently_booting_patch) : nlohmann::json(nullptr);
    j["boot_started_at"]         = p.boot_started_at.has_value()
        ? nlohmann::json(*p.boot_started_at) : nlohmann::json(nullptr);
    return j;
}

ReleasePointers pointers_from_json(const nlohmann::json& j) {
    ReleasePointers p;
    auto try_size = [&](const char* key) -> std::optional<std::size_t> {
        if (!j.contains(key) || j.at(key).is_null()) return std::nullopt;
        return j.at(key).get<std::size_t>();
    };
    p.next_boot_patch         = try_size("next_boot_patch");
    p.last_booted_patch       = try_size("last_booted_patch");
    p.currently_booting_patch = try_size("currently_booting_patch");
    if (j.contains("boot_started_at") && !j.at("boot_started_at").is_null()) {
        p.boot_started_at = j.at("boot_started_at").get<std::uint64_t>();
    }
    return p;
}

}  // namespace json

// ---------------- PatchLifecycle ----------------

PatchLifecycle::PatchLifecycle(fs::path state_root,
                                fs::path download_root,
                                ReleasePointers pointers)
    : state_root_(std::move(state_root)),
      download_root_(std::move(download_root)),
      pointers_(std::move(pointers)) {}

PatchLifecycle PatchLifecycle::load_or_default(fs::path state_root,
                                                fs::path download_root) {
    ReleasePointers ptrs;
    fs::path pointers_path = state_root / POINTERS_FILE;
    if (disk_io::file_exists(pointers_path)) {
        try {
            ptrs = json::pointers_from_json(disk_io::read_json(pointers_path));
        } catch (const std::exception& e) {
            DASHPOD_ERROR("Failed to read pointers: ", e.what(),
                          "; using defaults");
            ptrs = {};
        }
    }
    return PatchLifecycle(std::move(state_root), std::move(download_root),
                          std::move(ptrs));
}

fs::path PatchLifecycle::patches_root() const {
    return state_root_ / PATCHES_DIR;
}

fs::path PatchLifecycle::patch_dir(std::size_t n) const {
    return patches_root() / std::to_string(n);
}

fs::path PatchLifecycle::state_path(std::size_t n) const {
    return patch_dir(n) / PATCH_STATE;
}

fs::path PatchLifecycle::pointers_path() const {
    return state_root_ / POINTERS_FILE;
}

fs::path PatchLifecycle::download_artifact_path(std::size_t n) const {
    return ::dashpod::cache::download_artifact_path(download_root_, n);
}

fs::path PatchLifecycle::installed_artifact_path(std::size_t n) const {
    return ::dashpod::cache::installed_artifact_path(state_root_, n);
}

std::optional<PatchState> PatchLifecycle::read_state(std::size_t n) const {
    auto path = state_path(n);
    if (!disk_io::file_exists(path)) return std::nullopt;
    try {
        return json::patch_state_from_json(disk_io::read_json(path));
    } catch (const std::exception& e) {
        DASHPOD_ERROR("Failed to read state for patch ", n, ": ", e.what());
        return std::nullopt;
    }
}

void PatchLifecycle::write_state(std::size_t n, const PatchState& state) {
    disk_io::write_json(json::patch_state_to_json(state), state_path(n));
}

void PatchLifecycle::save_pointers() {
    disk_io::write_json(json::pointers_to_json(pointers_), pointers_path());
}

DownloadAction PatchLifecycle::decide_start(std::size_t n,
                                            const std::string& url,
                                            const std::string& hash) const {
    const auto download_path = download_artifact_path(n);
    auto state = read_state(n);
    if (!state.has_value()) return DownloadActionFresh{};

    return std::visit([&](auto&& s) -> DownloadAction {
        using T = std::decay_t<decltype(s)>;
        if constexpr (std::is_same_v<T, StateDownloading>) {
            if (s.url == url && s.hash == hash) {
                std::error_code ec;
                auto sz = fs::file_size(download_path, ec);
                if (ec) return DownloadActionFresh{};
                return DownloadActionResume{ static_cast<std::uint64_t>(sz) };
            }
            return DownloadActionFresh{};
        } else if constexpr (std::is_same_v<T, StateDownloaded>) {
            if (s.url == url && s.hash == hash &&
                disk_io::file_exists(download_path)) {
                return DownloadActionComplete{};
            }
            return DownloadActionFresh{};
        } else if constexpr (std::is_same_v<T, StateInstalled>) {
            return DownloadActionSkip{ SkipReason::AlreadyInstalled };
        } else if constexpr (std::is_same_v<T, StateBad>) {
            return DownloadActionSkip{ SkipReason::KnownBad };
        }
        return DownloadActionFresh{};
    }, *state);
}

void PatchLifecycle::record_download_started(
    std::size_t n,
    const std::string& url,
    const std::string& hash,
    const std::optional<std::string>& signature) {
    write_state(n, StateDownloading{ url, hash, signature });
}

void PatchLifecycle::record_download_complete(std::size_t n, std::uint64_t size) {
    auto state = read_state(n);
    if (!state.has_value()) {
        throw UpdaterError(UpdaterError::Kind::InvalidState,
            "record_download_complete on unknown patch " + std::to_string(n));
    }
    std::string url;
    std::string hash;
    std::optional<std::string> signature;

    if (auto* d = std::get_if<StateDownloading>(&*state)) {
        url = d->url; hash = d->hash; signature = d->signature;
    } else if (auto* d = std::get_if<StateDownloaded>(&*state)) {
        // idempotent: already complete.
        url = d->url; hash = d->hash; signature = d->signature;
    } else {
        throw UpdaterError(UpdaterError::Kind::InvalidState,
            "record_download_complete on patch " + std::to_string(n) +
            " in unexpected state");
    }
    write_state(n, StateDownloaded{ std::move(url), std::move(hash),
                                    std::move(signature), size });
}

void PatchLifecycle::record_install_complete(std::size_t n,
                                              std::uint64_t installed_size) {
    auto state = read_state(n);
    if (!state.has_value()) {
        throw UpdaterError(UpdaterError::Kind::InvalidState,
            "record_install_complete on unknown patch " + std::to_string(n));
    }
    auto* d = std::get_if<StateDownloaded>(&*state);
    if (d == nullptr) {
        throw UpdaterError(UpdaterError::Kind::InvalidState,
            "record_install_complete on patch " + std::to_string(n) +
            " not in Downloaded state");
    }
    write_state(n, StateInstalled{ d->signature, installed_size });

    // Remove the compressed download — dlc.vmcode is canonical now.
    std::error_code ec;
    auto dl = download_artifact_path(n);
    if (disk_io::file_exists(dl)) {
        fs::remove(dl, ec);
        if (ec) {
            DASHPOD_ERROR("Failed to remove download for patch ", n,
                          ": ", ec.message());
        }
    }
}

void PatchLifecycle::promote_to_next_boot(std::size_t n) {
    auto state = read_state(n);
    if (!state.has_value() || !std::holds_alternative<StateInstalled>(*state)) {
        throw UpdaterError(UpdaterError::Kind::InvalidState,
            "promote_to_next_boot(" + std::to_string(n) +
            ") requires Installed state");
    }
    auto last_booted = pointers_.last_booted_patch;
    if (pointers_.next_boot_patch.has_value()) {
        std::size_t prev = *pointers_.next_boot_patch;
        if (prev != n && (!last_booted.has_value() || *last_booted != prev)) {
            cleanup(prev);
        }
    }
    pointers_.next_boot_patch = n;
    save_pointers();
}

void PatchLifecycle::recompute_next_boot() {
    bool dirty = false;

    if (pointers_.last_booted_patch.has_value()) {
        if (!read_state(*pointers_.last_booted_patch).has_value()) {
            pointers_.last_booted_patch.reset();
            dirty = true;
        }
    }

    auto is_installed = [this](std::size_t n) {
        auto s = read_state(n);
        return s.has_value() && std::holds_alternative<StateInstalled>(*s);
    };

    bool already_valid = pointers_.next_boot_patch.has_value() &&
                         is_installed(*pointers_.next_boot_patch);
    if (!already_valid) {
        std::optional<std::size_t> new_target;
        if (pointers_.last_booted_patch.has_value() &&
            is_installed(*pointers_.last_booted_patch)) {
            new_target = pointers_.last_booted_patch;
        }
        if (pointers_.next_boot_patch != new_target) {
            pointers_.next_boot_patch = new_target;
            dirty = true;
        }
    }

    if (dirty) save_pointers();
}

void PatchLifecycle::mark_bad(std::size_t n, BadReason reason) {
    auto prior = read_state(n);
    StateBad bad;
    bad.reason = reason;
    if (prior.has_value()) {
        std::visit([&](auto&& s) {
            using T = std::decay_t<decltype(s)>;
            if constexpr (std::is_same_v<T, StateDownloading>) {
                bad.hash      = s.hash;
                bad.signature = s.signature;
                std::error_code ec;
                auto sz = fs::file_size(download_artifact_path(n), ec);
                if (!ec) bad.size = static_cast<std::uint64_t>(sz);
            } else if constexpr (std::is_same_v<T, StateDownloaded>) {
                bad.hash      = s.hash;
                bad.signature = s.signature;
                bad.size      = s.size;
            } else if constexpr (std::is_same_v<T, StateInstalled>) {
                bad.signature = s.signature;
                bad.size      = s.size;
            } else if constexpr (std::is_same_v<T, StateBad>) {
                bad.hash      = s.hash;
                bad.signature = s.signature;
                bad.size      = s.size;
            }
        }, *prior);
    }
    write_state(n, bad);
    cleanup(n);
}

void PatchLifecycle::cleanup(std::size_t n) {
    auto state = read_state(n);
    if (state.has_value() && std::holds_alternative<StateBad>(*state)) {
        delete_artifact_files(n);
    } else {
        forget_dir(n);
    }
}

void PatchLifecycle::delete_artifact_files(std::size_t n) {
    auto dir = patch_dir(n);
    std::error_code ec;
    if (fs::is_directory(dir, ec)) {
        for (const auto& entry : fs::directory_iterator(dir, ec)) {
            if (entry.path().filename() == PATCH_STATE) continue;
            std::error_code rm_ec;
            if (entry.is_directory(rm_ec)) fs::remove_all(entry.path(), rm_ec);
            else                            fs::remove    (entry.path(), rm_ec);
            if (rm_ec) {
                DASHPOD_ERROR("Failed to remove ", entry.path().string(),
                              ": ", rm_ec.message());
            }
        }
    }
    auto dl = download_artifact_path(n);
    if (disk_io::file_exists(dl)) {
        std::error_code rm_ec;
        fs::remove(dl, rm_ec);
        if (rm_ec) {
            DASHPOD_ERROR("Failed to remove ", dl.string(), ": ", rm_ec.message());
        }
    }
}

void PatchLifecycle::forget_dir(std::size_t n) {
    std::error_code ec;
    auto dir = patch_dir(n);
    if (fs::exists(dir, ec)) {
        fs::remove_all(dir, ec);
        if (ec) {
            DASHPOD_ERROR("Failed to remove ", dir.string(), ": ", ec.message());
        }
    }
    auto dl = download_artifact_path(n);
    if (disk_io::file_exists(dl)) {
        std::error_code rm_ec;
        fs::remove(dl, rm_ec);
    }
}

void PatchLifecycle::record_boot_start(std::size_t n) {
    auto state = read_state(n);
    if (!state.has_value() || !std::holds_alternative<StateInstalled>(*state)) {
        throw UpdaterError(UpdaterError::Kind::InvalidState,
            "record_boot_start(" + std::to_string(n) +
            ") expected Installed");
    }
    if (!pointers_.next_boot_patch.has_value() ||
        *pointers_.next_boot_patch != n) {
        throw UpdaterError(UpdaterError::Kind::InvalidState,
            "record_boot_start(" + std::to_string(n) +
            ") but next_boot_patch differs");
    }
    pointers_.currently_booting_patch = n;
    pointers_.boot_started_at = time::unix_timestamp();
    save_pointers();
}

void PatchLifecycle::record_boot_success() {
    if (!pointers_.currently_booting_patch.has_value()) {
        throw UpdaterError(UpdaterError::Kind::InvalidState,
            "record_boot_success without currently_booting_patch");
    }
    const std::size_t n = *pointers_.currently_booting_patch;
    pointers_.last_booted_patch       = n;
    pointers_.currently_booting_patch = std::nullopt;
    pointers_.boot_started_at         = std::nullopt;
    save_pointers();
    cleanup_older_than(n);
}

void PatchLifecycle::record_boot_failure(std::size_t n) {
    mark_bad(n, BadReason::BootCrash);
    pointers_.currently_booting_patch = std::nullopt;
    pointers_.boot_started_at         = std::nullopt;
    save_pointers();
    recompute_next_boot();
}

std::optional<std::size_t> PatchLifecycle::detect_boot_crash_on_init() {
    if (!pointers_.currently_booting_patch.has_value()) return std::nullopt;
    const std::size_t n = *pointers_.currently_booting_patch;
    record_boot_failure(n);
    return n;
}

void PatchLifecycle::cleanup_older_than(std::size_t n) {
    std::error_code ec;
    auto root = patches_root();
    if (!fs::is_directory(root, ec)) return;
    for (const auto& entry : fs::directory_iterator(root, ec)) {
        auto name = entry.path().filename().string();
        try {
            std::size_t num = std::stoull(name);
            if (num < n) cleanup(num);
        } catch (const std::exception&) {
            std::error_code rm_ec;
            if (entry.is_directory(rm_ec)) fs::remove_all(entry.path(), rm_ec);
            else                            fs::remove   (entry.path(), rm_ec);
        }
    }
    cleanup_orphan_downloads();
}

void PatchLifecycle::cleanup_orphan_downloads() {
    std::error_code ec;
    if (!fs::is_directory(download_root_, ec)) return;
    for (const auto& entry : fs::directory_iterator(download_root_, ec)) {
        auto name = entry.path().filename().string();
        bool keep = false;
        try {
            std::size_t num = std::stoull(name);
            auto s = read_state(num);
            if (s.has_value() &&
                (std::holds_alternative<StateDownloading>(*s) ||
                 std::holds_alternative<StateDownloaded>(*s))) {
                keep = true;
            }
        } catch (const std::exception&) {
            keep = false;
        }
        if (keep) continue;
        std::error_code rm_ec;
        if (entry.is_directory(rm_ec)) fs::remove_all(entry.path(), rm_ec);
        else                            fs::remove   (entry.path(), rm_ec);
    }
}

void PatchLifecycle::validate_installed_patch(
    std::size_t n,
    const std::optional<std::string>& public_key,
    yaml::PatchVerificationMode mode) const {
    auto state = read_state(n);
    if (!state.has_value() || !std::holds_alternative<StateInstalled>(*state)) {
        throw UpdaterError(UpdaterError::Kind::InvalidState,
            "Patch " + std::to_string(n) + " is not Installed");
    }
    const auto& inst = std::get<StateInstalled>(*state);
    auto path = installed_artifact_path(n);
    if (!disk_io::file_exists(path)) {
        throw UpdaterError(UpdaterError::Kind::Io,
            "Patch " + std::to_string(n) + " artifact missing at " +
            path.string());
    }
    std::error_code ec;
    auto actual_size = fs::file_size(path, ec);
    if (ec) {
        throw UpdaterError(UpdaterError::Kind::Io,
            "Failed to stat " + path.string() + ": " + ec.message());
    }
    if (actual_size != inst.size) {
        throw UpdaterError(UpdaterError::Kind::BadPatch,
            "Patch " + std::to_string(n) + " size mismatch on disk");
    }
    if (mode == yaml::PatchVerificationMode::Strict && public_key.has_value()) {
        if (!inst.signature.has_value()) {
            throw UpdaterError(UpdaterError::Kind::InvalidSignature,
                "Patch " + std::to_string(n) + " missing signature");
        }
        auto actual_hash = signing::hash_file(path);
        if (!signing::check_signature(actual_hash, *inst.signature, *public_key)) {
            throw UpdaterError(UpdaterError::Kind::InvalidSignature,
                "Patch " + std::to_string(n) + " signature invalid");
        }
    }
}

void PatchLifecycle::validate_next_boot_patch(
    const std::optional<std::string>& public_key,
    yaml::PatchVerificationMode mode) {
    if (!pointers_.next_boot_patch.has_value()) return;
    const std::size_t n = *pointers_.next_boot_patch;
    try {
        validate_installed_patch(n, public_key, mode);
    } catch (const std::exception& e) {
        DASHPOD_ERROR("Patch ", n, " failed validation: ", e.what());
        mark_bad(n, BadReason::ValidationFailed);
        recompute_next_boot();
        throw;
    }
}

}  // namespace dashpod::cache
