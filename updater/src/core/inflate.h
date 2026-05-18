#pragma once

#include <filesystem>

#include "io/read_seek.h"

namespace dashpod::core {

// Decompresses a zstd-framed bipatch stream stored at `patch_path` on top of
// `base` (the current libapp.so), writing the inflated artifact to `output_path`.
//
// Wire format (from the spec and upstream bipatch-1.0.0 crate):
//   file = zstd_frame( bipatch_stream )
//   bipatch_stream = HEADER LOOP*
//   HEADER = u32_le(0xB1DF) u32_le(0x1000)
//   LOOP   = varint(add_len) add_bytes[add_len]
//            varint(copy_len) copy_bytes[copy_len]
//            varint_signed(seek)          // zigzag; SeekFrom::Current in base
//   add: out[i] = base[i].wrapping_add(add_bytes[i])
//   EOF while reading add_len varint = normal termination.
//
// Returns true on success.  On any failure (bad magic, decompress error,
// base file read error, I/O error on output) returns false after logging.
bool inflate_patch(const std::filesystem::path& patch_path,
                   IReadSeek& base,
                   const std::filesystem::path& output_path);

}  // namespace dashpod::core