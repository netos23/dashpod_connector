#include "cache/updater_state.h"

#include <array>
#include <random>
#include <sstream>
#include <system_error>

#include "cache/disk_io.h"
#include "core/config.h"
#include "core/error.h"
#include "util/logging.h"

namespace fs = std::filesystem;

namespace dashpod::cache {

namespace {

constexpr const char* STATE_FILE_NAME = "state.json";

// Paths that belong to dashpod under `cache_dir`. Wiped on release-
// version change. state.json is *intentionally absent* — it's rewritten
// in place with the preserved client_id.
constexpr std::array<const char*, 2> OWNED_PATHS = {
    "patches",
    "pointers.json",
};

std::string generate_client_id() {
    // UUIDv4. Hand-rolled to avoid pulling in a UUID library for this
    // one call site.
    std::random_device rd;
    std::mt19937_64    rng(rd());
    std::uniform_int_distribution<std::uint64_t> dist;
    std::uint64_t a = dist(rng);
    std::uint64_t b = dist(rng);

    auto* a_bytes = reinterpret_cast<std::uint8_t*>(&a);
    auto* b_bytes = reinterpret_cast<std::uint8_t*>(&b);

    a_bytes[6] = static_cast<std::uint8_t>((a_bytes[6] & 0x0F) | 0x40);  // version 4
    b_bytes[0] = static_cast<std::uint8_t>((b_bytes[0] & 0x3F) | 0x80);  // variant 1

    static const char* digits = "0123456789abcdef";
    auto hex_pair = [&](std::uint8_t v, std::ostringstream& os) {
        os << digits[(v >> 4) & 0xF] << digits[v & 0xF];
    };
    std::ostringstream os;
    for (int i = 0; i < 4; ++i) hex_pair(a_bytes[i], os);
    os << '-';
    for (int i = 4; i < 6; ++i) hex_pair(a_bytes[i], os);
    os << '-';
    for (int i = 6; i < 8; ++i) hex_pair(a_bytes[i], os);
    os << '-';
    for (int i = 0; i < 2; ++i) hex_pair(b_bytes[i], os);
    os << '-';
    for (int i = 2; i < 8; ++i) hex_pair(b_bytes[i], os);
    return os.str();
}

}  // namespace

UpdaterState::UpdaterState(fs::path cache_dir,
                            PatchLifecycle lifecycle,
                            std::string client_id,
                            std::string release_version,
                            std::optional<std::string> patch_public_key,
                            yaml::PatchVerificationMode verification_mode)
    : cache_dir_(std::move(cache_dir)),
      lifecycle_(std::move(lifecycle)),
      patch_public_key_(std::move(patch_public_key)),
      verification_mode_(verification_mode),
      client_id_(std::move(client_id)),
      release_version_(std::move(release_version)) {}

UpdaterState UpdaterState::load_or_new_on_error(
    const fs::path& cache_dir,
    const fs::path& download_dir,
    const std::string& release_version,
    const std::optional<std::string>& patch_public_key,
    yaml::PatchVerificationMode verification_mode) {

    auto state_path = cache_dir / STATE_FILE_NAME;

    auto build_fresh = [&](const std::string& client_id) {
        // Wipe dashpod-owned files in cache_dir (but not state.json
        // itself — we'll rewrite it).
        for (const auto* rel : OWNED_PATHS) {
            auto p = cache_dir / rel;
            std::error_code ec;
            if (fs::is_directory(p, ec)) fs::remove_all(p, ec);
            else if (fs::exists(p, ec))   fs::remove   (p, ec);
        }
        // download_dir is fully ours — wipe wholesale.
        std::error_code ec;
        if (fs::exists(download_dir, ec)) fs::remove_all(download_dir, ec);

        auto lc = PatchLifecycle::load_or_default(cache_dir, download_dir);
        UpdaterState s(cache_dir, std::move(lc), client_id, release_version,
                       patch_public_key, verification_mode);
        try {
            s.save();
        } catch (const std::exception& e) {
            DASHPOD_WARN("Failed to save fresh state: ", e.what());
        }
        return s;
    };

    if (!disk_io::file_exists(state_path)) {
        return build_fresh(generate_client_id());
    }

    try {
        auto j = disk_io::read_json(state_path);
        const std::string on_disk_release = j.at("release_version").get<std::string>();
        const std::string on_disk_client  = j.at("client_id").get<std::string>();
        if (on_disk_release != release_version) {
            DASHPOD_INFO("release_version changed ", on_disk_release, " -> ",
                         release_version, ", creating new state");
            return build_fresh(on_disk_client);
        }
        auto lc = PatchLifecycle::load_or_default(cache_dir, download_dir);
        UpdaterState s(cache_dir, std::move(lc), on_disk_client,
                       release_version, patch_public_key, verification_mode);
        if (j.contains("queued_events") && j.at("queued_events").is_array()) {
            for (const auto& ev_j : j.at("queued_events")) {
                try {
                    s.queued_events_.push_back(net::patch_event_from_json(ev_j));
                } catch (const std::exception& e) {
                    DASHPOD_WARN("Skipping malformed queued event: ", e.what());
                }
            }
        }
        return s;
    } catch (const std::exception& e) {
        DASHPOD_INFO("State file unreadable (", e.what(), "), creating fresh");
        return build_fresh(generate_client_id());
    }
}

void UpdaterState::save() {
    nlohmann::json j;
    j["client_id"]       = client_id_;
    j["release_version"] = release_version_;
    nlohmann::json arr = nlohmann::json::array();
    for (const auto& ev : queued_events_) {
        arr.push_back(net::patch_event_to_json(ev));
    }
    j["queued_events"] = std::move(arr);
    disk_io::write_json(j, cache_dir_ / STATE_FILE_NAME);
}

PatchInfo UpdaterState::patch_info(std::size_t n) const {
    return PatchInfo{ lifecycle_.installed_artifact_path(n), n };
}

std::optional<PatchInfo> UpdaterState::currently_booting_patch() const {
    if (!lifecycle_.pointers().currently_booting_patch.has_value()) return std::nullopt;
    return patch_info(*lifecycle_.pointers().currently_booting_patch);
}

std::optional<PatchInfo> UpdaterState::last_successfully_booted_patch() const {
    if (!lifecycle_.pointers().last_booted_patch.has_value()) return std::nullopt;
    return patch_info(*lifecycle_.pointers().last_booted_patch);
}

std::optional<PatchInfo> UpdaterState::next_boot_patch() {
    if (!lifecycle_.pointers().next_boot_patch.has_value()) return std::nullopt;
    return patch_info(*lifecycle_.pointers().next_boot_patch);
}

std::optional<PatchInfo> UpdaterState::running_patch() const {
    auto n = core::running_patch_number();
    if (!n.has_value()) return std::nullopt;
    return patch_info(*n);
}

void UpdaterState::set_running_patch(std::optional<std::size_t> number) {
    core::set_running_patch_number(number);
}

std::optional<std::uint64_t> UpdaterState::boot_started_at() const {
    return lifecycle_.pointers().boot_started_at;
}

void UpdaterState::record_boot_start_for_patch(std::size_t n) {
    lifecycle_.record_boot_start(n);
}

void UpdaterState::record_boot_success() {
    lifecycle_.record_boot_success();
}

void UpdaterState::record_boot_failure_for_patch(std::size_t n) {
    lifecycle_.record_boot_failure(n);
}

bool UpdaterState::is_known_bad_patch(std::size_t n) const {
    auto state = lifecycle_.read_state(n);
    return state.has_value() && std::holds_alternative<StateBad>(*state);
}

void UpdaterState::uninstall_patch(std::size_t n) {
    lifecycle_.cleanup(n);
    lifecycle_.recompute_next_boot();
}

void UpdaterState::validate_next_boot_patch() {
    lifecycle_.validate_next_boot_patch(patch_public_key_, verification_mode_);
}

void UpdaterState::queue_event(const net::PatchEvent& event) {
    queued_events_.push_back(event);
    save();
}

std::vector<net::PatchEvent> UpdaterState::copy_events(std::size_t limit) const {
    std::vector<net::PatchEvent> out;
    const std::size_t n = std::min(limit, queued_events_.size());
    out.reserve(n);
    for (std::size_t i = 0; i < n; ++i) out.push_back(queued_events_[i]);
    return out;
}

void UpdaterState::clear_events() {
    queued_events_.clear();
    save();
}

}  // namespace dashpod::cache
