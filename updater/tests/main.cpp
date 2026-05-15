// Smoke test executable. Exercises the C ABI just enough to verify the
// library links and the no-op paths run without crashing.
//
// This is *not* a unit test suite — it's the equivalent of an
// integration-test smoke check that the binary builds and runs.

#include <iostream>

#include "dashpod/dart.h"
#include "dashpod/engine.h"

namespace {

void* fake_open()                            { return nullptr; }
size_t fake_read(void*, uint8_t*, size_t)    { return 0; }
int64_t fake_seek(void*, int64_t, int32_t)   { return -1; }
void  fake_close(void*)                       {}

}  // namespace

int main() {
    std::cout << "dashpod_updater smoke test\n";

    // Pre-init: every accessor should return the zero/null values
    // without crashing.
    std::cout << "current_boot_patch_number (pre-init): "
              << dashpod_current_boot_patch_number() << "\n";
    std::cout << "next_boot_patch_number    (pre-init): "
              << dashpod_next_boot_patch_number() << "\n";

    DashpodFileCallbacks cb{ fake_open, fake_read, fake_seek, fake_close };
    const char* libapp_paths[] = { "./libapp.so" };
    DashpodAppParameters params{
        .release_version            = "0.0.1",
        .original_libapp_paths      = libapp_paths,
        .original_libapp_paths_size = 1,
        .app_storage_dir            = "./_dashpod_storage",
        .code_cache_dir             = "./_dashpod_cache",
    };

    const bool ok = dashpod_init(&params, cb, "app_id: smoke-test\n");
    std::cout << "dashpod_init: " << (ok ? "ok" : "fail") << "\n";

    if (ok) {
        std::cout << "should_auto_update: "
                  << (dashpod_should_auto_update() ? "true" : "false") << "\n";
    }

    return 0;
}
