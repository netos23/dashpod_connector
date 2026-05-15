#pragma once

#include <filesystem>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "core/yaml.h"
#include "io/read_seek.h"

namespace dashpod::net {
struct NetworkHooks;
}

namespace dashpod::core {

// Process-local input from the embedder. Mirrors DashpodAppParameters
// after the C-string fields have been converted to std::string.
struct AppConfig {
    std::string              app_storage_dir;
    std::string              code_cache_dir;
    std::string              release_version;
    std::vector<std::string> original_libapp_paths;
};

// Immutable once set. Cloned freely; mutex-protected at the singleton.
struct UpdateConfig {
    std::filesystem::path       storage_dir;
    std::filesystem::path       download_dir;
    std::filesystem::path       libapp_path;
    bool                        auto_update = true;
    std::string                 channel;
    std::string                 app_id;
    std::string                 release_version;
    std::string                 base_url;
    std::shared_ptr<net::NetworkHooks>            network_hooks;
    std::shared_ptr<IExternalFileProvider>        file_provider;
    std::optional<std::string>                    patch_public_key;
    yaml::PatchVerificationMode                   patch_verification =
        yaml::PatchVerificationMode::Strict;
};

// Sets the global config. Returns true on success, false if it's
// already initialised.
bool set_config(const AppConfig& app_config,
                std::shared_ptr<IExternalFileProvider> file_provider,
                std::filesystem::path libapp_path,
                const yaml::YamlConfig& yaml,
                std::shared_ptr<net::NetworkHooks> hooks);

// Resets the global config (intended for tests; harmless in production
// because we never call it).
void testing_reset_config();

// Holds the config mutex while invoking f. Throws ConfigNotInitialized
// if no config is set.
void with_config(const std::function<void(const UpdateConfig&)>& f);

// Returns a clone of the current config. Same not-initialised semantics
// as with_config.
UpdateConfig copy_config();

// Session-scoped "what patch is this process running". Backed by a
// process-local mutex, not by on-disk state.
std::optional<std::size_t> running_patch_number();
void                       set_running_patch_number(std::optional<std::size_t> n);

// Platform/arch identifiers as seen on the wire.
std::string current_platform();
std::string current_arch();

constexpr const char* kDefaultChannel = "stable";
constexpr const char* kDefaultBaseUrl = "https://api.dashpod.dev";

}  // namespace dashpod::core
