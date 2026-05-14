#pragma once

#include <filesystem>
#include <optional>
#include <string>

#include "cache/updater_state.h"
#include "core/config.h"

namespace dashpod::core {

enum class UpdateStatus {
    NoUpdate,
    UpdateInstalled,
    UpdateHadError,
    UpdateIsBadPatch,
    UpdateInProgress,
};

std::string to_string(UpdateStatus s);

// Initialise the library. Returns false on failure (which includes
// "already initialised"). All exceptions are caught and logged at the
// FFI boundary; this function rethrows internally to make orchestration
// cleaner.
//
// Throws UpdaterError on invalid arguments or YAML.
void init(const AppConfig& app_config,
          std::shared_ptr<IExternalFileProvider> file_provider,
          const std::string& yaml);

// Returns the value of `auto_update` from the bundle's dashpod.yaml.
bool should_auto_update();

// True if a new patch exists that has not yet been downloaded.
bool check_for_downloadable_update(std::optional<std::string> channel);

// Full update cycle: drain events, patch_check, download, install.
UpdateStatus update(std::optional<std::string> channel);

// Spawns a detached thread that performs `update(nullopt)`.
void start_update_thread();

// Patch-pointer reads.
std::optional<cache::PatchInfo> next_boot_patch();
std::optional<cache::PatchInfo> running_patch();

// Validate the patch slated for next boot. Mark bad on failure.
void validate_next_boot_patch();

// Boot lifecycle hooks. Invoked from the host engine.
void report_launch_start();
void report_launch_success();
void report_launch_failure();

}  // namespace dashpod::core
