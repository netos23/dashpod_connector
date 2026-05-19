#pragma once

#include <cstddef>
#include <cstdint>
#include <span>
#include <vector>

namespace dashpod::patch {

// Produces a binary patch that, when applied to `older`, yields `newer`.
//
// Output format (matches updater/src/core/inflate.cpp):
//   zstd_frame( bipatch_stream )
//   bipatch_stream = HEADER LOOP*
//   HEADER = u32_le(0x0000B1DF) u32_le(0x00001000)
//   LOOP   = uvarint(add_len)  add_len bytes
//            uvarint(copy_len) copy_len bytes
//            svarint_zigzag(seek)
//
// The matching algorithm is bsdiff (Colin Percival, 2003) with the
// canonical suffix-array search and the same fuzzy forward/backward
// extension. Output bytes therefore differ from the upstream Rust
// `bidiff` crate even on identical inputs, but the wire format and
// semantics are byte-equivalent — patches produced here are accepted
// by `dashpod::core::inflate_patch`.
//
// Throws std::runtime_error on internal failure (zstd compression
// error, etc). Pure-data inputs do not throw.
std::vector<std::uint8_t> make_patch(std::span<const std::uint8_t> older,
                                     std::span<const std::uint8_t> newer);

}  // namespace dashpod::patch
