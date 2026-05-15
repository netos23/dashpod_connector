#pragma once

#include <optional>
#include <string>
#include <string_view>

namespace dashpod::yaml {

enum class PatchVerificationMode {
    Strict,       // verify signature at every boot (default)
    InstallOnly,  // verify signature only at install time
};

constexpr PatchVerificationMode default_verification_mode() {
    return PatchVerificationMode::Strict;
}

struct YamlConfig {
    std::string                          app_id;            // required
    std::optional<std::string>           channel;
    std::optional<std::string>           base_url;
    std::optional<bool>                  auto_update;
    std::optional<std::string>           patch_public_key;
    std::optional<PatchVerificationMode> patch_verification;
};

struct ParseResult {
    bool        ok = false;
    YamlConfig  value{};
    std::string error;   // populated when ok == false
};

// Minimal key:value parser. NOT real YAML — one key per line, no
// nesting, no flow syntax. Matches the upstream parser exactly so the
// bundled dashpod.yaml is parsed identically on every platform.
//
// Unknown keys are ignored for forward compatibility. The only hard
// validation is that `app_id` must be present; everything else has a
// default.
[[nodiscard]] ParseResult parse_yaml(std::string_view input);

}  // namespace dashpod::yaml
