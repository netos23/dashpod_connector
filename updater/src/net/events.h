#pragma once

#include <cstdint>
#include <optional>
#include <string>

#include <nlohmann/json.hpp>

namespace dashpod::net {

enum class EventType {
    PatchInstallSuccess,   // wire: __patch_install__
    PatchInstallFailure,   // wire: __patch_install_failure__
    PatchDownload,         // wire: __patch_download__
    PatchUpdateFailure,    // wire: __patch_update_failure__
};

const char* event_type_wire_string(EventType t);
std::optional<EventType> event_type_from_wire(const std::string& s);

// Privacy contract: PatchEvent must never carry PII. `message` is a
// free-form diagnostic capped at 256 chars by the sender.
struct PatchEvent {
    std::string                app_id;
    std::string                arch;
    std::string                client_id;
    EventType                  identifier   = EventType::PatchDownload;
    std::size_t                patch_number = 0;
    std::string                platform;
    std::string                release_version;
    std::uint64_t              timestamp    = 0;
    std::optional<std::string> message;
};

nlohmann::json patch_event_to_json(const PatchEvent& e);
PatchEvent     patch_event_from_json(const nlohmann::json& j);

}  // namespace dashpod::net
