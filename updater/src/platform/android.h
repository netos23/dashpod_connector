#pragma once

#include <filesystem>
#include <string>
#include <vector>

#include "io/read_seek.h"

namespace dashpod::platform {

// Opens a read-seek handle to `libapp.so` embedded inside an Android APK or
// APK split set.
//
// `apk_paths` is `original_libapp_paths` from the engine — virtual paths of
// the form `<pkg_dir>/lib/<abi>/libapp.so`.  The function walks 3 parent
// directories from `apk_paths[0]` to reach the package directory, enumerates
// every `*.apk` there, and searches each zip for an entry matching
// `lib/<abi>/libapp.so`.
//
// Returns nullptr when no matching entry is found or when any I/O error
// prevents opening the file.
//
// `arch` must be one of: "aarch64", "arm", "x86", "x86_64".
ReadSeekPtr open_libapp_from_apk_splits(
    const std::vector<std::filesystem::path>& apk_paths,
    const std::string& arch);

// Opens a single named entry from a ZIP file and returns a read-seek handle.
// The entry is read in-place (STORED) or extracted into memory (DEFLATE).
// Exposed for unit testing; production code uses open_libapp_from_apk_splits.
// Returns nullptr if the entry is not found, the compression method is
// unsupported, or any I/O error occurs.
ReadSeekPtr open_entry_from_zip(const std::filesystem::path& zip_path,
                                 const std::string& entry_name);

}  // namespace dashpod::platform