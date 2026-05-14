#ifndef DASHPOD_DART_H
#define DASHPOD_DART_H

/* Dart-stable C ABI for the dashpod updater.
 *
 * This is the surface consumed by Dart FFI bindings. ABI-pinned:
 * function names, signatures, and status-code values must not change
 * without bumping the consumer package version. For the engine-internal
 * surface, see engine.h.
 */

#include <stdbool.h>
#include <stdint.h>

#include "dashpod/export.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Status codes for dashpod_update_with_result. */
#define DASHPOD_UPDATE_ERROR        -1
#define DASHPOD_NO_UPDATE            0
#define DASHPOD_UPDATE_INSTALLED     1
#define DASHPOD_UPDATE_HAD_ERROR     2
#define DASHPOD_UPDATE_IS_BAD_PATCH  3
#define DASHPOD_UPDATE_IN_PROGRESS   4

typedef struct DashpodUpdateResult {
    int32_t     status;
    const char* message;
} DashpodUpdateResult;

/* The patch number this process is currently running, or 0 if running
 * the base release. Set after dashpod_report_launch_start. */
DASHPOD_EXPORT uintptr_t dashpod_current_boot_patch_number(void);

/* The patch number that will boot on the next launch, or 0 if the next
 * boot is the base release. */
DASHPOD_EXPORT uintptr_t dashpod_next_boot_patch_number(void);

/* Check (synchronously) whether an update is available for download on
 * the given channel. NULL channel falls back to dashpod.yaml's channel,
 * which falls back to "stable". Returns true if a new patch is
 * available *and* has not yet been downloaded. */
DASHPOD_EXPORT bool dashpod_check_for_downloadable_update(const char* channel);

/* Synchronously download + install an update on the given channel.
 * Returns a heap-allocated result; the caller must free it with
 * dashpod_free_update_result. */
DASHPOD_EXPORT
const DashpodUpdateResult* dashpod_update_with_result(const char* channel);

/* Free a result returned by dashpod_update_with_result. Safe on NULL. */
DASHPOD_EXPORT void dashpod_free_update_result(DashpodUpdateResult* result);

#ifdef __cplusplus
}
#endif

#endif
