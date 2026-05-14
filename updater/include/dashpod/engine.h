#ifndef DASHPOD_ENGINE_H
#define DASHPOD_ENGINE_H

/* Engine-internal C ABI for the dashpod updater.
 *
 * Consumed by the host engine / native shell. Unstable: the engine and
 * the updater ship together so this surface can change with the engine.
 * For the Dart-stable surface consumed by FFI bindings, see dart.h.
 */

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "dashpod/export.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Configuration struct passed to dashpod_init. All char* are
 * null-terminated UTF-8 strings owned by the caller — the updater does
 * not free them and does not retain them past the init call. */
typedef struct DashpodAppParameters {
    /* Named release version (e.g. "1.0.0+42"). Required. */
    const char* release_version;

    /* Array of paths to the original AOT library (libapp.so or its
     * platform equivalent). On Android these are the virtual paths
     * into the split APK; the platform shim walks them up to find
     * the APK directory. Required. */
    const char* const* original_libapp_paths;
    int                original_libapp_paths_size;

    /* Persistent app-storage directory. The updater writes
     * state.json, pointers.json, and patches/{N}/. Required. */
    const char* app_storage_dir;

    /* OS-managed cache directory. The updater writes compressed
     * downloads here. Safe to lose under storage pressure. Required. */
    const char* code_cache_dir;
} DashpodAppParameters;

/* iOS-style file callback table. Used when the base snapshot is not a
 * file on the filesystem (e.g. the embedded snapshot in an iOS bundle).
 * All function pointers must be non-null. */
typedef struct DashpodFileCallbacks {
    void*    (*open)(void);
    size_t   (*read)(void* handle, uint8_t* buffer, size_t count);
    int64_t  (*seek)(void* handle, int64_t offset, int32_t whence);
    void     (*close)(void* handle);
} DashpodFileCallbacks;

/* Free a string returned by the updater library. Safe to call with NULL. */
DASHPOD_EXPORT void dashpod_free_string(const char* c_string);

/* Initialise the updater. Returns true on success.
 *
 * params:   non-null DashpodAppParameters describing the running app.
 * callbacks: non-null DashpodFileCallbacks. May be zeroed if not used.
 * yaml:     UTF-8 contents of the bundle's dashpod.yaml.
 *
 * Returns false (and logs) on any failure. Multiple calls to init are
 * benign: the first wins, subsequent calls return false. */
DASHPOD_EXPORT bool dashpod_init(const DashpodAppParameters* params,
                                 DashpodFileCallbacks         callbacks,
                                 const char*                  yaml);

/* True when auto-update was requested in dashpod.yaml (default true). */
DASHPOD_EXPORT bool dashpod_should_auto_update(void);

/* Verify that the patch slated for the next boot is bootable. If it
 * fails (artifact missing, size mismatch, signature broken in Strict
 * mode), the patch is tombstoned Bad{ValidationFailed} and
 * next_boot_patch falls back to last_booted_patch or to the base
 * release. */
DASHPOD_EXPORT void dashpod_validate_next_boot_patch(void);

/* Path to the inflated artifact that will boot on next launch, or NULL
 * if the next boot is the base release. Caller must free with
 * dashpod_free_string. */
DASHPOD_EXPORT char* dashpod_next_boot_patch_path(void);

/* Spawn a background thread to check for and install an update. The
 * thread is fire-and-forget; the caller does not join. */
DASHPOD_EXPORT void dashpod_start_update_thread(void);

/* Boot lifecycle: must be called in order. report_launch_start ⇒
 * "we are about to load the next-boot patch"; report_launch_success ⇒
 * "the patch is running cleanly"; report_launch_failure ⇒ "the patch
 * failed to load." */
DASHPOD_EXPORT void dashpod_report_launch_start(void);
DASHPOD_EXPORT void dashpod_report_launch_success(void);
DASHPOD_EXPORT void dashpod_report_launch_failure(void);

#ifdef __cplusplus
}
#endif

#endif
