#pragma once

#include <filesystem>
#include <string>
#include <vector>

#include "io/read_seek.h"

namespace dashpod::platform {

// Opens a read-seek handle to `libapp.so` embedded inside an Android APK or
// APK split set.  The function searches each path in `apk_paths` for an
// entry matching `lib/{arch}/libapp.so` and returns a handle that reads from
// that entry (memory-mapped or extracted as needed).
//
// Returns nullptr on non-Android platforms, when no matching entry is found,
// or when any I/O error prevents opening the file.
//
// `arch` must be one of: "aarch64", "arm", "x86", "x86_64".
ReadSeekPtr open_libapp_from_apk_splits(
    const std::vector<std::filesystem::path>& apk_paths,
    const std::string& arch);

}  // namespace dashpod::platform