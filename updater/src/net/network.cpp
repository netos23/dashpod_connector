#include "net/network.h"

#include <system_error>

#include "core/config.h"
#include "core/error.h"
#include "util/logging.h"

namespace fs = std::filesystem;

namespace dashpod::net {

// ---------------- JSON conversions ----------------

nlohmann::json patch_to_json(const Patch& p) {
    nlohmann::json j;
    j["number"]       = p.number;
    j["hash"]         = p.hash;
    j["download_url"] = p.download_url;
    if (p.hash_signature.has_value()) {
        j["hash_signature"] = *p.hash_signature;
    } else {
        j["hash_signature"] = nullptr;
    }
    return j;
}

Patch patch_from_json(const nlohmann::json& j) {
    Patch p;
    p.number       = j.at("number").get<std::size_t>();
    p.hash         = j.at("hash").get<std::string>();
    p.download_url = j.at("download_url").get<std::string>();
    if (j.contains("hash_signature") && !j.at("hash_signature").is_null()) {
        p.hash_signature = j.at("hash_signature").get<std::string>();
    }
    return p;
}

PatchCheckRequest PatchCheckRequest::from_config(
    const core::UpdateConfig& cfg,
    const std::string& client_id,
    std::optional<std::size_t> current_patch_number) {
    return PatchCheckRequest{
        cfg.app_id,
        cfg.channel,
        cfg.release_version,
        core::current_platform(),
        core::current_arch(),
        client_id,
        current_patch_number,
    };
}

nlohmann::json patch_check_request_to_json(const PatchCheckRequest& r) {
    nlohmann::json j;
    j["app_id"]          = r.app_id;
    j["channel"]         = r.channel;
    j["release_version"] = r.release_version;
    j["platform"]        = r.platform;
    j["arch"]            = r.arch;
    j["client_id"]       = r.client_id;
    // Omit (not null) when absent — matches the wire contract.
    if (r.current_patch_number.has_value()) {
        j["current_patch_number"] = *r.current_patch_number;
    }
    return j;
}

PatchCheckResponse patch_check_response_from_json(const nlohmann::json& j) {
    PatchCheckResponse r;
    r.patch_available = j.value("patch_available", false);
    if (j.contains("patch") && !j.at("patch").is_null()) {
        r.patch = patch_from_json(j.at("patch"));
    }
    if (j.contains("rolled_back_patch_numbers") &&
        !j.at("rolled_back_patch_numbers").is_null()) {
        r.rolled_back_patch_numbers =
            j.at("rolled_back_patch_numbers").get<std::vector<std::size_t>>();
    }
    return r;
}

std::string patches_check_url(const std::string& base_url) {
    return base_url + "/api/v1/patches/check";
}

std::string patches_events_url(const std::string& base_url) {
    return base_url + "/api/v1/patches/events";
}

// ---------------- Hook defaults (real HTTP) ----------------

namespace {

PatchCheckResponse default_patch_check_request(const std::string& /*url*/,
                                                const PatchCheckRequest& /*req*/) {
    // TODO: implement real HTTP via libcurl / cpp-httplib.
    throw UpdaterError(UpdaterError::Kind::Network,
        "HTTP client not yet wired up — install a NetworkHooks fake "
        "(default networking is stubbed)");
}

DownloadResult default_download_to_path(const std::string& /*url*/,
                                         const fs::path& /*dest*/,
                                         std::uint64_t /*resume_from*/) {
    throw UpdaterError(UpdaterError::Kind::Network,
        "HTTP client not yet wired up");
}

void default_report_event(const std::string& /*url*/,
                           const PatchEvent& /*event*/) {
    throw UpdaterError(UpdaterError::Kind::Network,
        "HTTP client not yet wired up");
}

}  // namespace

NetworkHooks::NetworkHooks()
    : patch_check_request_fn(default_patch_check_request),
      download_to_path_fn(default_download_to_path),
      report_event_fn(default_report_event) {}

// ---------------- Helpers ----------------

DownloadResult download_to_path(const NetworkHooks& hooks,
                                 const std::string& url,
                                 const fs::path& path,
                                 std::uint64_t resume_from) {
    DASHPOD_INFO("Downloading patch from: ", url);
    if (path.has_parent_path()) {
        std::error_code ec;
        fs::create_directories(path.parent_path(), ec);
        if (ec) {
            throw UpdaterError(UpdaterError::Kind::Io,
                "Failed to create download dir: " + ec.message());
        }
    }
    auto result = hooks.download_to_path_fn(url, path, resume_from);
    DASHPOD_INFO("Downloaded ", result.total_bytes, " bytes to ", path.string());
    return result;
}

void send_patch_event(const PatchEvent& event,
                       const core::UpdateConfig& config) {
    if (!config.network_hooks) {
        throw UpdaterError(UpdaterError::Kind::Network, "No network hooks");
    }
    config.network_hooks->report_event_fn(
        patches_events_url(config.base_url), event);
}

}  // namespace dashpod::net
