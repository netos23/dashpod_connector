#include "core/updater_lock.h"

#include <mutex>

#include "core/error.h"

namespace dashpod::core {

namespace {

std::mutex& updater_mutex() {
    static std::mutex m;
    return m;
}

}  // namespace

void with_updater_thread_lock(
    const std::function<void(const UpdaterLockState&)>& f) {
    std::unique_lock<std::mutex> lock(updater_mutex(), std::try_to_lock);
    if (!lock.owns_lock()) {
        throw UpdaterError(UpdaterError::Kind::UpdateAlreadyInProgress,
                           "Update already in progress");
    }
    UpdaterLockState state;
    f(state);
}

}  // namespace dashpod::core
