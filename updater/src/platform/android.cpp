#include "platform/android.h"

// Full implementation requires minizip-ng (or libzip) to locate the
// libapp.so entry inside the APK ZIP archive and either extract or mmap it.
//
// On Android (TARGET_OS_ANDROID / __ANDROID__), the APK is a ZIP whose
// entries live at filesystem-accessible offsets, so we can open the
// containing file and seek directly into the entry — no decompression
// needed for STORED entries.
//
// On all other platforms (iOS, macOS, Linux, Windows) the embedder passes a
// direct filesystem path in original_libapp_paths[0], so open_libapp_from_apk_splits
// is never called; returning nullptr causes the caller to fall through to the
// default std::ifstream provider.

namespace dashpod::platform {

ReadSeekPtr open_libapp_from_apk_splits(
    [[maybe_unused]] const std::vector<std::filesystem::path>& apk_paths,
    [[maybe_unused]] const std::string& arch) {
#if defined(__ANDROID__)
    // TODO: implement via minizip-ng.
    //   1. For each path in apk_paths, open as a ZIP (mz_zip_reader_open_file).
    //   2. Search for entry "lib/{arch}/libapp.so".
    //   3. If STORED (compression_method == MZ_COMPRESS_METHOD_STORE):
    //      open the underlying file, seek to the entry data offset, wrap
    //      in a ReadSeek view capped at entry_size bytes.
    //   4. If DEFLATE: extract to a temp file, wrap in a FileReadSeek.
    //   5. Return the first successful match.
    return nullptr;
#else
    return nullptr;
#endif
}

}  // namespace dashpod::platform