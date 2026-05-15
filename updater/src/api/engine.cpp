// Engine-internal C ABI implementation. See include/dashpod/engine.h.
//
// Every extern "C" entry point must be exception-safe. Use
// log_on_error to funnel everything through the same boundary handler.

#define DASHPOD_BUILDING

#include "dashpod/engine.h"

#include <memory>
#include <string>
#include <vector>

#include "api/common.h"
#include "core/config.h"
#include "core/error.h"
#include "core/updater.h"
#include "io/c_file.h"
#include "util/logging.h"

using dashpod::api::allocate_c_string;
using dashpod::api::free_c_string;
using dashpod::api::log_on_error;
using dashpod::api::to_rust;

namespace {

dashpod::core::AppConfig app_config_from_c(const DashpodAppParameters* params) {
    if (params == nullptr) {
        throw dashpod::UpdaterError(
            dashpod::UpdaterError::Kind::InvalidArgument,
            "Null parameters passed to dashpod_init");
    }
    dashpod::core::AppConfig cfg;
    cfg.app_storage_dir = to_rust(params->app_storage_dir);
    cfg.code_cache_dir  = to_rust(params->code_cache_dir);
    cfg.release_version = to_rust(params->release_version);
    if (params->original_libapp_paths == nullptr ||
        params->original_libapp_paths_size <= 0) {
        throw dashpod::UpdaterError(
            dashpod::UpdaterError::Kind::InvalidArgument,
            "original_libapp_paths must be non-empty");
    }
    for (int i = 0; i < params->original_libapp_paths_size; ++i) {
        cfg.original_libapp_paths.push_back(to_rust(params->original_libapp_paths[i]));
    }
    return cfg;
}

}  // namespace

extern "C" {

DASHPOD_EXPORT void dashpod_free_string(const char* c_string) {
    free_c_string(c_string);
}

DASHPOD_EXPORT bool dashpod_init(const DashpodAppParameters* params,
                                  DashpodFileCallbacks         callbacks,
                                  const char*                  yaml) {
    return log_on_error([&]() {
        auto cfg          = app_config_from_c(params);
        auto file_provider = std::make_shared<dashpod::io::CFileProvider>(callbacks);
        const std::string yaml_str = to_rust(yaml);
        dashpod::core::init(cfg, std::move(file_provider), yaml_str);
        return true;
    }, "initializing updater", false);
}

DASHPOD_EXPORT bool dashpod_should_auto_update(void) {
    return log_on_error([&]() {
        return dashpod::core::should_auto_update();
    }, "fetching update behavior", true);
}

DASHPOD_EXPORT void dashpod_validate_next_boot_patch(void) {
    log_on_error([&]() {
        dashpod::core::validate_next_boot_patch();
        return 0;
    }, "validating next_boot_patch", 0);
}

DASHPOD_EXPORT char* dashpod_next_boot_patch_path(void) {
    return log_on_error([&]() -> char* {
        auto nbp = dashpod::core::next_boot_patch();
        if (!nbp.has_value()) return nullptr;
        return allocate_c_string(nbp->path.string());
    }, "fetching next_boot_patch_path", static_cast<char*>(nullptr));
}

DASHPOD_EXPORT void dashpod_start_update_thread(void) {
    log_on_error([&]() {
        dashpod::core::start_update_thread();
        return 0;
    }, "starting update thread", 0);
}

DASHPOD_EXPORT void dashpod_report_launch_start(void) {
    log_on_error([&]() {
        dashpod::core::report_launch_start();
        return 0;
    }, "reporting launch start", 0);
}

DASHPOD_EXPORT void dashpod_report_launch_failure(void) {
    log_on_error([&]() {
        dashpod::core::report_launch_failure();
        return 0;
    }, "reporting launch failure", 0);
}

DASHPOD_EXPORT void dashpod_report_launch_success(void) {
    log_on_error([&]() {
        dashpod::core::report_launch_success();
        return 0;
    }, "reporting launch success", 0);
}

}  // extern "C"
