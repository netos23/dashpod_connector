// Dart-stable C ABI implementation. See include/dashpod/dart.h.

#define DASHPOD_BUILDING

#include "dashpod/dart.h"

#include <cstdlib>
#include <string>

#include "api/common.h"
#include "core/updater.h"
#include "util/logging.h"

using dashpod::api::allocate_c_string;
using dashpod::api::log_on_error;
using dashpod::api::to_rust_option;

namespace {

DashpodUpdateResult* to_update_result(dashpod::core::UpdateStatus status) {
    auto* result = static_cast<DashpodUpdateResult*>(
        std::malloc(sizeof(DashpodUpdateResult)));
    if (result == nullptr) return nullptr;
    const std::string msg = dashpod::core::to_string(status);
    switch (status) {
        case dashpod::core::UpdateStatus::NoUpdate:
            result->status = DASHPOD_NO_UPDATE; break;
        case dashpod::core::UpdateStatus::UpdateInstalled:
            result->status = DASHPOD_UPDATE_INSTALLED; break;
        case dashpod::core::UpdateStatus::UpdateHadError:
            result->status = DASHPOD_UPDATE_HAD_ERROR; break;
        case dashpod::core::UpdateStatus::UpdateIsBadPatch:
            result->status = DASHPOD_UPDATE_IS_BAD_PATCH; break;
        case dashpod::core::UpdateStatus::UpdateInProgress:
            result->status = DASHPOD_UPDATE_IN_PROGRESS; break;
    }
    result->message = allocate_c_string(msg);
    return result;
}

DashpodUpdateResult* to_error_result(const std::string& msg) {
    auto* result = static_cast<DashpodUpdateResult*>(
        std::malloc(sizeof(DashpodUpdateResult)));
    if (result == nullptr) return nullptr;
    result->status  = DASHPOD_UPDATE_ERROR;
    result->message = allocate_c_string(msg);
    return result;
}

}  // namespace

extern "C" {

DASHPOD_EXPORT uintptr_t dashpod_current_boot_patch_number(void) {
    return log_on_error([&]() -> uintptr_t {
        auto rp = dashpod::core::running_patch();
        return rp.has_value() ? static_cast<uintptr_t>(rp->number) : 0;
    }, "fetching current_boot_patch_number", static_cast<uintptr_t>(0));
}

DASHPOD_EXPORT uintptr_t dashpod_next_boot_patch_number(void) {
    return log_on_error([&]() -> uintptr_t {
        auto nbp = dashpod::core::next_boot_patch();
        return nbp.has_value() ? static_cast<uintptr_t>(nbp->number) : 0;
    }, "fetching next_boot_patch_number", static_cast<uintptr_t>(0));
}

DASHPOD_EXPORT bool dashpod_check_for_downloadable_update(const char* c_channel) {
    return log_on_error([&]() {
        auto channel = to_rust_option(c_channel);
        return dashpod::core::check_for_downloadable_update(channel);
    }, "checking for update", false);
}

DASHPOD_EXPORT
const DashpodUpdateResult* dashpod_update_with_result(const char* c_channel) {
    try {
        auto channel = to_rust_option(c_channel);
        auto status  = dashpod::core::update(channel);
        return to_update_result(status);
    } catch (const std::exception& e) {
        DASHPOD_ERROR("Update failed: ", e.what());
        return to_error_result(e.what());
    } catch (...) {
        DASHPOD_ERROR("Update failed: <unknown>");
        return to_error_result("Unknown error");
    }
}

DASHPOD_EXPORT void dashpod_free_update_result(DashpodUpdateResult* result) {
    if (result == nullptr) return;
    dashpod::api::free_c_string(result->message);
    std::free(result);
}

}  // extern "C"
