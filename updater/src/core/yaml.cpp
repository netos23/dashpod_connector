#include "core/yaml.h"

namespace dashpod::yaml {

namespace {

std::string_view trim(std::string_view s) {
    while (!s.empty() && (s.front() == ' ' || s.front() == '\t')) s.remove_prefix(1);
    while (!s.empty() && (s.back()  == ' ' || s.back()  == '\t' ||
                          s.back()  == '\r')) s.remove_suffix(1);
    return s;
}

}  // namespace

ParseResult parse_yaml(std::string_view input) {
    ParseResult result;
    YamlConfig& cfg = result.value;

    std::optional<std::string> app_id;

    std::size_t start = 0;
    while (start <= input.size()) {
        std::size_t end = input.find('\n', start);
        if (end == std::string_view::npos) end = input.size();
        std::string_view line = trim(input.substr(start, end - start));
        start = end + 1;

        if (line.empty() || line.front() == '#') continue;

        std::size_t colon = line.find(':');
        if (colon == std::string_view::npos) continue;

        std::string_view key   = trim(line.substr(0, colon));
        std::string_view value = trim(line.substr(colon + 1));

        if (key == "app_id") {
            app_id = std::string(value);
        } else if (key == "channel") {
            cfg.channel = std::string(value);
        } else if (key == "base_url") {
            cfg.base_url = std::string(value);
        } else if (key == "auto_update") {
            if (value == "true")       cfg.auto_update = true;
            else if (value == "false") cfg.auto_update = false;
            else {
                result.error = "invalid value for auto_update: '" +
                               std::string(value) + "'";
                return result;
            }
        } else if (key == "patch_public_key") {
            cfg.patch_public_key = std::string(value);
        } else if (key == "patch_verification") {
            if (value == "strict") {
                cfg.patch_verification = PatchVerificationMode::Strict;
            } else if (value == "install_only") {
                cfg.patch_verification = PatchVerificationMode::InstallOnly;
            } else {
                result.error = "invalid value for patch_verification: '" +
                               std::string(value) + "'";
                return result;
            }
        }
        // Unknown keys: ignored for forward compatibility.
    }

    if (!app_id.has_value()) {
        result.error = "missing required field: app_id";
        return result;
    }
    cfg.app_id = std::move(*app_id);
    result.ok = true;
    return result;
}

}  // namespace dashpod::yaml
