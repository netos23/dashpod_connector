#include "net/events.h"

#include "core/error.h"

namespace dashpod::net {

const char* event_type_wire_string(EventType t) {
    switch (t) {
        case EventType::PatchInstallSuccess: return "__patch_install__";
        case EventType::PatchInstallFailure: return "__patch_install_failure__";
        case EventType::PatchDownload:       return "__patch_download__";
        case EventType::PatchUpdateFailure:  return "__patch_update_failure__";
    }
    return "__patch_download__";
}

std::optional<EventType> event_type_from_wire(const std::string& s) {
    if (s == "__patch_install__")         return EventType::PatchInstallSuccess;
    if (s == "__patch_install_failure__") return EventType::PatchInstallFailure;
    if (s == "__patch_download__")        return EventType::PatchDownload;
    if (s == "__patch_update_failure__")  return EventType::PatchUpdateFailure;
    return std::nullopt;
}

nlohmann::json patch_event_to_json(const PatchEvent& e) {
    nlohmann::json j;
    j["app_id"]          = e.app_id;
    j["arch"]            = e.arch;
    j["client_id"]       = e.client_id;
    j["type"]            = event_type_wire_string(e.identifier);
    j["patch_number"]    = e.patch_number;
    j["platform"]        = e.platform;
    j["release_version"] = e.release_version;
    j["timestamp"]       = e.timestamp;
    j["message"]         = e.message.has_value()
        ? nlohmann::json(*e.message) : nlohmann::json(nullptr);
    return j;
}

PatchEvent patch_event_from_json(const nlohmann::json& j) {
    PatchEvent e;
    e.app_id          = j.at("app_id").get<std::string>();
    e.arch            = j.at("arch").get<std::string>();
    e.client_id       = j.at("client_id").get<std::string>();
    auto type_str     = j.at("type").get<std::string>();
    auto t            = event_type_from_wire(type_str);
    if (!t.has_value()) {
        throw UpdaterError(UpdaterError::Kind::BadServerResponse,
            "Unknown event type: " + type_str);
    }
    e.identifier      = *t;
    e.patch_number    = j.at("patch_number").get<std::size_t>();
    e.platform        = j.at("platform").get<std::string>();
    e.release_version = j.at("release_version").get<std::string>();
    e.timestamp       = j.at("timestamp").get<std::uint64_t>();
    if (j.contains("message") && !j.at("message").is_null()) {
        e.message = j.at("message").get<std::string>();
    }
    return e;
}

}  // namespace dashpod::net
