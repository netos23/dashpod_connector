#pragma once

#include <filesystem>
#include <optional>
#include <string>
#include <vector>

#include "cache/lifecycle.h"
#include "core/yaml.h"
#include "net/events.h"

namespace dashpod::cache {

// Lightweight public-facing patch handle exposed to FFI callers.
struct PatchInfo {
    std::filesystem::path path;
    std::size_t           number = 0;
};

// Per-release, per-device top-level state. Owns state.json and the
// queued event log, and delegates patch state to PatchLifecycle.
class UpdaterState {
public:
    // Load state for the given release_version. If the on-disk
    // release_version differs (or the file is missing/corrupt), wipe
    // per-release state and start fresh — but carry forward client_id.
    static UpdaterState load_or_new_on_error(
        const std::filesystem::path& cache_dir,
        const std::filesystem::path& download_dir,
        const std::string& release_version,
        const std::optional<std::string>& patch_public_key,
        yaml::PatchVerificationMode verification_mode);

    void save();

    [[nodiscard]] const std::string& client_id() const noexcept { return client_id_; }

    // Patch info wrappers — bridge to PatchLifecycle pointers.
    [[nodiscard]] std::optional<PatchInfo> currently_booting_patch() const;
    [[nodiscard]] std::optional<PatchInfo> last_successfully_booted_patch() const;
    [[nodiscard]] std::optional<PatchInfo> next_boot_patch();
    [[nodiscard]] std::optional<PatchInfo> running_patch() const;
    void set_running_patch(std::optional<std::size_t> number);

    [[nodiscard]] std::optional<std::uint64_t> boot_started_at() const;

    [[nodiscard]] PatchLifecycle&       lifecycle() noexcept       { return lifecycle_; }
    [[nodiscard]] const PatchLifecycle& lifecycle() const noexcept { return lifecycle_; }

    // High-level transitions delegated to the lifecycle.
    void record_boot_start_for_patch(std::size_t n);
    void record_boot_success();
    void record_boot_failure_for_patch(std::size_t n);

    [[nodiscard]] bool is_known_bad_patch(std::size_t n) const;
    void               uninstall_patch(std::size_t n);
    void               validate_next_boot_patch();

    // Event queue.
    void               queue_event(const net::PatchEvent& event);
    [[nodiscard]] std::vector<net::PatchEvent> copy_events(std::size_t limit) const;
    void               clear_events();

private:
    UpdaterState(std::filesystem::path cache_dir,
                 PatchLifecycle lifecycle,
                 std::string client_id,
                 std::string release_version,
                 std::optional<std::string> patch_public_key,
                 yaml::PatchVerificationMode verification_mode);

    [[nodiscard]] PatchInfo patch_info(std::size_t n) const;

    std::filesystem::path        cache_dir_;
    PatchLifecycle               lifecycle_;
    std::optional<std::string>   patch_public_key_;
    yaml::PatchVerificationMode  verification_mode_;
    std::string                  client_id_;
    std::string                  release_version_;
    std::vector<net::PatchEvent> queued_events_;
};

}  // namespace dashpod::cache
