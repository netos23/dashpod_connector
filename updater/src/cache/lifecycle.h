#pragma once

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <variant>

#include <nlohmann/json.hpp>

#include "core/yaml.h"

namespace dashpod::cache {

// Per-patch lifecycle state. Persisted at {state_root}/patches/{N}/state.json
// as a tagged union via the "kind" discriminator.

struct StateDownloading {
    std::string url;
    std::string hash;                       // expected SHA-256 of inflated bytes
    std::optional<std::string> signature;   // base64 RSA-PKCS1-SHA256 signature
};

struct StateDownloaded {
    std::string url;
    std::string hash;
    std::optional<std::string> signature;
    std::uint64_t size = 0;                 // bytes-on-disk for the download
};

struct StateInstalled {
    std::optional<std::string> signature;
    std::uint64_t size = 0;                 // bytes-on-disk for dlc.vmcode
};

enum class BadReason {
    BootCrash,
    InvalidPatchBytes,
    InstallHashMismatch,
    ValidationFailed,
};

std::string to_string(BadReason r);
std::optional<BadReason> bad_reason_from_string(const std::string& s);

struct StateBad {
    BadReason                  reason = BadReason::BootCrash;
    std::optional<std::string> hash;
    std::optional<std::string> signature;
    std::optional<std::uint64_t> size;
};

using PatchState = std::variant<
    StateDownloading,
    StateDownloaded,
    StateInstalled,
    StateBad
>;

// Per-release pointers. Single document at {state_root}/pointers.json.
struct ReleasePointers {
    std::optional<std::size_t>  next_boot_patch;
    std::optional<std::size_t>  last_booted_patch;
    std::optional<std::size_t>  currently_booting_patch;
    std::optional<std::uint64_t> boot_started_at;
};

// What update_internal should do when starting work on a patch.
struct DownloadActionFresh    {};
struct DownloadActionResume   { std::uint64_t offset = 0; };
struct DownloadActionComplete {};
enum class SkipReason { AlreadyInstalled, KnownBad };
struct DownloadActionSkip     { SkipReason reason; };

using DownloadAction = std::variant<
    DownloadActionFresh,
    DownloadActionResume,
    DownloadActionComplete,
    DownloadActionSkip
>;

// Free helpers: usable without a PatchLifecycle instance.
std::filesystem::path download_artifact_path(
    const std::filesystem::path& download_root, std::size_t n);
std::filesystem::path installed_artifact_path(
    const std::filesystem::path& state_root, std::size_t n);

// Per-release patch lifecycle. Owns {state_root}/patches/, pointers.json,
// and {download_root}/{N} files for in-flight downloads.
class PatchLifecycle {
public:
    static PatchLifecycle load_or_default(std::filesystem::path state_root,
                                          std::filesystem::path download_root);

    [[nodiscard]] const ReleasePointers& pointers() const noexcept { return pointers_; }

    // Returns nullopt if patch N has no state on disk ("Unknown").
    [[nodiscard]] std::optional<PatchState> read_state(std::size_t n) const;
    void write_state(std::size_t n, const PatchState& state);
    void save_pointers();

    // ----- High-level transitions -----
    [[nodiscard]] DownloadAction decide_start(std::size_t n,
                                              const std::string& url,
                                              const std::string& hash) const;

    void record_download_started(std::size_t n,
                                  const std::string& url,
                                  const std::string& hash,
                                  const std::optional<std::string>& signature);
    void record_download_complete(std::size_t n, std::uint64_t size);
    void record_install_complete(std::size_t n, std::uint64_t installed_size);

    void promote_to_next_boot(std::size_t n);
    void recompute_next_boot();

    void mark_bad(std::size_t n, BadReason reason);
    void cleanup(std::size_t n);

    // ----- Boot tracking -----
    void record_boot_start(std::size_t n);
    void record_boot_success();
    void record_boot_failure(std::size_t n);
    std::optional<std::size_t> detect_boot_crash_on_init();

    // Validates that next_boot_patch is bootable. On failure, marks it
    // Bad{ValidationFailed} and recomputes pointers.
    void validate_next_boot_patch(const std::optional<std::string>& public_key,
                                   yaml::PatchVerificationMode mode);

    [[nodiscard]] std::filesystem::path download_artifact_path(std::size_t n) const;
    [[nodiscard]] std::filesystem::path installed_artifact_path(std::size_t n) const;

private:
    PatchLifecycle(std::filesystem::path state_root,
                   std::filesystem::path download_root,
                   ReleasePointers pointers);

    [[nodiscard]] std::filesystem::path patches_root() const;
    [[nodiscard]] std::filesystem::path patch_dir(std::size_t n) const;
    [[nodiscard]] std::filesystem::path state_path(std::size_t n) const;
    [[nodiscard]] std::filesystem::path pointers_path() const;

    void delete_artifact_files(std::size_t n);
    void forget_dir(std::size_t n);
    void cleanup_older_than(std::size_t n);
    void cleanup_orphan_downloads();
    void validate_installed_patch(std::size_t n,
                                  const std::optional<std::string>& public_key,
                                  yaml::PatchVerificationMode mode) const;

    std::filesystem::path state_root_;
    std::filesystem::path download_root_;
    ReleasePointers       pointers_{};
};

// JSON (de)serialisation for the variant — declared here so unit tests
// can round-trip without depending on private headers.
namespace json {
nlohmann::json patch_state_to_json(const PatchState& s);
PatchState patch_state_from_json(const nlohmann::json& j);
nlohmann::json pointers_to_json(const ReleasePointers& p);
ReleasePointers pointers_from_json(const nlohmann::json& j);
}  // namespace json

}  // namespace dashpod::cache
