#include "core/config.h"

#include <mutex>
#include <optional>

#if defined(__APPLE__)
  #include <TargetConditionals.h>
#endif

#include "core/error.h"
#include "net/network.h"
#include "util/logging.h"

namespace dashpod::core {

namespace {

std::mutex& config_mutex() {
    static std::mutex m;
    return m;
}

std::optional<UpdateConfig>& config_slot() {
    static std::optional<UpdateConfig> c;
    return c;
}

std::mutex& running_mutex() {
    static std::mutex m;
    return m;
}

std::optional<std::size_t>& running_slot() {
    static std::optional<std::size_t> n;
    return n;
}

}  // namespace

bool set_config(const AppConfig& app_config,
                std::shared_ptr<IExternalFileProvider> file_provider,
                std::filesystem::path libapp_path,
                const yaml::YamlConfig& yc,
                std::shared_ptr<net::NetworkHooks> hooks) {
    std::lock_guard<std::mutex> lock(config_mutex());
    auto& slot = config_slot();
    if (slot.has_value()) {
        DASHPOD_WARN("Updater already initialized, ignoring second init call.");
        return false;
    }

    UpdateConfig cfg;
    cfg.storage_dir     = app_config.app_storage_dir;
    cfg.download_dir    = std::filesystem::path(app_config.code_cache_dir) / "downloads";
    cfg.libapp_path     = std::move(libapp_path);
    cfg.auto_update     = yc.auto_update.value_or(true);
    cfg.channel         = yc.channel.value_or(kDefaultChannel);
    cfg.app_id          = yc.app_id;
    cfg.release_version = app_config.release_version;
    cfg.base_url        = yc.base_url.value_or(kDefaultBaseUrl);
    cfg.network_hooks   = std::move(hooks);
    cfg.file_provider   = std::move(file_provider);
    cfg.patch_public_key   = yc.patch_public_key;
    cfg.patch_verification = yc.patch_verification.value_or(
        yaml::default_verification_mode());

    slot = std::move(cfg);
    return true;
}

void testing_reset_config() {
    std::lock_guard<std::mutex> lock(config_mutex());
    config_slot().reset();
    std::lock_guard<std::mutex> rlock(running_mutex());
    running_slot().reset();
}

void with_config(const std::function<void(const UpdateConfig&)>& f) {
    std::lock_guard<std::mutex> lock(config_mutex());
    auto& slot = config_slot();
    if (!slot.has_value()) {
        throw UpdaterError(UpdaterError::Kind::ConfigNotInitialized,
                           "Config not initialized");
    }
    f(*slot);
}

UpdateConfig copy_config() {
    std::lock_guard<std::mutex> lock(config_mutex());
    auto& slot = config_slot();
    if (!slot.has_value()) {
        throw UpdaterError(UpdaterError::Kind::ConfigNotInitialized,
                           "Config not initialized");
    }
    return *slot;
}

std::optional<std::size_t> running_patch_number() {
    std::lock_guard<std::mutex> lock(running_mutex());
    return running_slot();
}

void set_running_patch_number(std::optional<std::size_t> n) {
    std::lock_guard<std::mutex> lock(running_mutex());
    running_slot() = n;
}

std::string current_platform() {
#if defined(__ANDROID__)
    return "android";
#elif defined(__APPLE__)
    #if TARGET_OS_IPHONE
    return "ios";
    #else
    return "macos";
    #endif
#elif defined(_WIN32)
    return "windows";
#elif defined(__linux__)
    return "linux";
#else
    return "unknown";
#endif
}

std::string current_arch() {
#if defined(__aarch64__) || defined(_M_ARM64)
    return "aarch64";
#elif defined(__arm__) || defined(_M_ARM)
    return "arm";
#elif defined(__x86_64__) || defined(_M_X64)
    return "x86_64";
#elif defined(__i386__) || defined(_M_IX86)
    return "x86";
#else
    return "unknown";
#endif
}

}  // namespace dashpod::core
