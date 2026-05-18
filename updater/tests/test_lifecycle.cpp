#include <catch2/catch_test_macros.hpp>

#include <filesystem>
#include <string>

#include "cache/lifecycle.h"
#include "cache/updater_state.h"
#include "core/yaml.h"

namespace dy = dashpod::yaml;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
namespace {

struct TmpDir {
    std::filesystem::path storage;
    std::filesystem::path downloads;

    explicit TmpDir(const std::string& tag) {
        auto base = std::filesystem::temp_directory_path()
                  / ("dashpod_lifecycle_test_" + tag);
        storage   = base / "storage";
        downloads = base / "downloads";
        std::filesystem::create_directories(storage);
        std::filesystem::create_directories(downloads);
    }
    ~TmpDir() {
        std::error_code ec;
        std::filesystem::remove_all(storage.parent_path(), ec);
    }
};

dashpod::cache::UpdaterState make_state(const TmpDir& dir,
                                         const std::string& release = "1.0.0") {
    return dashpod::cache::UpdaterState::load_or_new_on_error(
        dir.storage, dir.downloads, release,
        std::nullopt,
        dy::PatchVerificationMode::InstallOnly);
}

}  // namespace

// ---------------------------------------------------------------------------
// decide_start: fresh download
// ---------------------------------------------------------------------------

TEST_CASE("decide_start returns DownloadActionFresh for unknown patch", "[lifecycle]") {
    TmpDir tmp("fresh");
    auto state = make_state(tmp);

    auto action = state.lifecycle().decide_start(1, "https://cdn/p/1", "aabbcc");
    REQUIRE(std::holds_alternative<dashpod::cache::DownloadActionFresh>(action));
}

// ---------------------------------------------------------------------------
// decide_start: skip known-bad patch
// ---------------------------------------------------------------------------

TEST_CASE("decide_start returns DownloadActionSkip for bad patch", "[lifecycle]") {
    TmpDir tmp("bad");
    auto state = make_state(tmp);

    // Record download and mark bad.
    state.lifecycle().record_download_started(1, "https://cdn/p/1", "aabbcc", std::nullopt);
    state.lifecycle().mark_bad(1, dashpod::cache::BadReason::InvalidPatchBytes);

    auto action = state.lifecycle().decide_start(1, "https://cdn/p/1", "aabbcc");
    REQUIRE(std::holds_alternative<dashpod::cache::DownloadActionSkip>(action));
    auto& skip = std::get<dashpod::cache::DownloadActionSkip>(action);
    REQUIRE(skip.reason == dashpod::cache::SkipReason::KnownBad);
}

// ---------------------------------------------------------------------------
// State transitions: Downloading → Downloaded → Installed
// ---------------------------------------------------------------------------

TEST_CASE("lifecycle transitions from Downloading to Installed", "[lifecycle]") {
    TmpDir tmp("install");
    auto state = make_state(tmp);

    // 1. Start download
    state.lifecycle().record_download_started(1, "https://cdn/p/1", "aabbcc", std::nullopt);
    {
        auto action = state.lifecycle().decide_start(1, "https://cdn/p/1", "aabbcc");
        // Already downloading, so it should either resume or be considered complete
        // (depends on whether bytes were written; here we haven't written any).
        // We expect it to be resumable from 0.
        bool is_resume_or_fresh =
            std::holds_alternative<dashpod::cache::DownloadActionFresh>(action) ||
            std::holds_alternative<dashpod::cache::DownloadActionResume>(action);
        REQUIRE(is_resume_or_fresh);
    }

    // 2. Download complete
    state.lifecycle().record_download_complete(1, 4096);

    // 3. Install complete (patch is now "Installed", promote to next_boot)
    state.lifecycle().record_install_complete(1, 8192);
    state.lifecycle().promote_to_next_boot(1);

    // Next decide_start for same patch should skip (already installed & promoted)
    auto action = state.lifecycle().decide_start(1, "https://cdn/p/1", "aabbcc");
    REQUIRE(std::holds_alternative<dashpod::cache::DownloadActionSkip>(action));
    // Reason should NOT be KnownBad (it's installed, not bad)
    auto& skip = std::get<dashpod::cache::DownloadActionSkip>(action);
    REQUIRE(skip.reason != dashpod::cache::SkipReason::KnownBad);
}

// ---------------------------------------------------------------------------
// next_boot_patch and running_patch
// ---------------------------------------------------------------------------

TEST_CASE("next_boot_patch is absent on fresh state", "[lifecycle]") {
    TmpDir tmp("noboot");
    auto state = make_state(tmp);
    REQUIRE(!state.next_boot_patch().has_value());
}

TEST_CASE("next_boot_patch is set after promote", "[lifecycle]") {
    TmpDir tmp("promote");
    auto state = make_state(tmp);

    state.lifecycle().record_download_started(2, "https://cdn/p/2", "hash2", std::nullopt);
    state.lifecycle().record_download_complete(2, 1024);
    state.lifecycle().record_install_complete(2, 2048);
    state.lifecycle().promote_to_next_boot(2);

    auto nbp = state.next_boot_patch();
    REQUIRE(nbp.has_value());
    REQUIRE(nbp->number == 2);
}

// ---------------------------------------------------------------------------
// uninstall_patch (server-driven rollback)
// ---------------------------------------------------------------------------

TEST_CASE("uninstall_patch clears next_boot if it matches", "[lifecycle]") {
    TmpDir tmp("rollback");
    auto state = make_state(tmp);

    state.lifecycle().record_download_started(3, "https://cdn/p/3", "hash3", std::nullopt);
    state.lifecycle().record_download_complete(3, 512);
    state.lifecycle().record_install_complete(3, 1024);
    state.lifecycle().promote_to_next_boot(3);
    REQUIRE(state.next_boot_patch().has_value());

    state.uninstall_patch(3);
    REQUIRE(!state.next_boot_patch().has_value());
}

// ---------------------------------------------------------------------------
// client_id stability
// ---------------------------------------------------------------------------

TEST_CASE("client_id is stable across reload", "[lifecycle]") {
    TmpDir tmp("clientid");
    std::string id1, id2;
    {
        auto state = make_state(tmp);
        id1 = state.client_id();
        REQUIRE(!id1.empty());
    }
    {
        auto state = make_state(tmp);
        id2 = state.client_id();
    }
    REQUIRE(id1 == id2);
}
