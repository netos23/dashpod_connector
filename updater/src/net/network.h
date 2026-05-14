#pragma once

#include <cstdint>
#include <filesystem>
#include <functional>
#include <memory>
#include <optional>
#include <string>

#include <nlohmann/json.hpp>

#include "net/events.h"

namespace dashpod::core { struct UpdateConfig; }

namespace dashpod::net {

// ---- Wire schemas ----

struct Patch {
    std::size_t                 number = 0;
    std::string                 hash;            // hex SHA-256 of *inflated* bytes
    std::string                 download_url;
    std::optional<std::string>  hash_signature;
};
nlohmann::json patch_to_json(const Patch& p);
Patch          patch_from_json(const nlohmann::json& j);

struct PatchCheckRequest {
    std::string                 app_id;
    std::string                 channel;
    std::string                 release_version;
    std::string                 platform;
    std::string                 arch;
    std::string                 client_id;
    std::optional<std::size_t>  current_patch_number;

    static PatchCheckRequest from_config(const core::UpdateConfig& cfg,
                                         const std::string& client_id,
                                         std::optional<std::size_t> current_patch_number);
};
nlohmann::json patch_check_request_to_json(const PatchCheckRequest& r);

struct PatchCheckResponse {
    bool                                       patch_available = false;
    std::optional<Patch>                        patch;
    std::optional<std::vector<std::size_t>>     rolled_back_patch_numbers;
};
PatchCheckResponse patch_check_response_from_json(const nlohmann::json& j);

struct DownloadResult {
    std::uint64_t                total_bytes    = 0;
    std::optional<std::uint64_t> content_length;   // from Content-Range/Length when known
};

// ---- Injectable hook surface ----

// Three function objects modelled as std::function so unit tests can
// substitute fakes without recompilation. The default implementation
// performs real HTTP and is a TODO — the orchestration code is
// already testable through the hooks.
struct NetworkHooks {
    std::function<PatchCheckResponse(const std::string& url,
                                     const PatchCheckRequest& req)>
        patch_check_request_fn;

    std::function<DownloadResult(const std::string& url,
                                 const std::filesystem::path& dest,
                                 std::uint64_t resume_from)>
        download_to_path_fn;

    std::function<void(const std::string& url,
                       const PatchEvent& event)>
        report_event_fn;

    // Default constructor wires up real (currently stubbed) HTTP impls.
    NetworkHooks();
};

std::string patches_check_url(const std::string& base_url);
std::string patches_events_url(const std::string& base_url);

// Helpers that the orchestrator calls. Ensure parent dir exists, then
// invoke the hook.
DownloadResult download_to_path(const NetworkHooks& hooks,
                                const std::string& url,
                                const std::filesystem::path& path,
                                std::uint64_t resume_from);

void send_patch_event(const PatchEvent& event,
                      const core::UpdateConfig& config);

}  // namespace dashpod::net
