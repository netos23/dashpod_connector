#pragma once

#include <functional>

namespace dashpod::core {

// Tag passed through to callers that need proof they've taken the
// updater lock. The Rust reference uses an empty struct for the same
// reason: API discipline more than runtime checking.
struct UpdaterLockState {};

// Invokes `f` while holding the updater try-lock. If the lock is
// already held by another thread, throws UpdaterError{UpdateAlreadyInProgress}
// — a benign condition that the caller is expected to translate into
// UPDATE_IN_PROGRESS at the FFI boundary.
void with_updater_thread_lock(
    const std::function<void(const UpdaterLockState&)>& f);

}  // namespace dashpod::core
