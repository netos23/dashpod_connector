#include "core/inflate.h"

#include <cstring>
#include <fstream>
#include <system_error>
#include <vector>

#include <zstd.h>

#include "util/logging.h"

namespace dashpod::core {

namespace {

// ---------------------------------------------------------------
// BipatchReader — push-based state machine that consumes decompressed
// bipatch bytes (fed in arbitrary chunk sizes) and writes the patched
// output to `out_`.
//
// Format handled (bipatch-1.0.0 / integer-encoding zigzag):
//   8-byte header: u32-LE(0xB1DF) u32-LE(0x1000)
//   Loop:
//     unsigned varint  add_len
//     add_len bytes    [diff: out[i] = base[i].wrapping_add(diff[i])]
//     unsigned varint  copy_len
//     copy_len bytes   [verbatim from patch stream → out]
//     signed varint    seek offset (zigzag; applied to base from current pos)
//   EOF while reading add_len varint = normal termination.
// ---------------------------------------------------------------
class BipatchReader {
    enum class Stage {
        ReadHeader,
        ReadVarint,   // all three varint fields share this stage
        DoAdd,
        DoCopy,
        Done,
        Error,
    };
    enum class VarintTarget { AddLen, CopyLen, Seek };

    IReadSeek&    base_;
    std::ofstream& out_;
    Stage         stage_        = Stage::ReadHeader;
    VarintTarget  vtarget_      = VarintTarget::AddLen;
    bool          had_error_    = false;

    uint8_t  hdr_[8]{};
    int      hdr_pos_  = 0;

    uint64_t varint_acc_   = 0;
    int      varint_shift_ = 0;

    uint64_t remaining_ = 0;

    // ---- helpers ----

    bool write_byte(uint8_t b) {
        out_.write(reinterpret_cast<char*>(&b), 1);
        if (!out_) { had_error_ = true; return false; }
        return true;
    }

    bool add_byte(uint8_t diff) {
        uint8_t old_b = 0;
        if (base_.read(&old_b, 1) != 1) {
            DASHPOD_ERROR("inflate: base file too short during add step");
            had_error_ = true;
            return false;
        }
        return write_byte(static_cast<uint8_t>(old_b + diff));
    }

    // Called when a varint is fully decoded.
    bool on_varint(uint64_t val) {
        varint_acc_   = 0;
        varint_shift_ = 0;
        switch (vtarget_) {
            case VarintTarget::AddLen:
                if (val == 0) {
                    vtarget_ = VarintTarget::CopyLen;
                    // stay in ReadVarint
                } else {
                    remaining_ = val;
                    stage_ = Stage::DoAdd;
                }
                break;
            case VarintTarget::CopyLen:
                if (val == 0) {
                    vtarget_ = VarintTarget::Seek;
                    // stay in ReadVarint
                } else {
                    remaining_ = val;
                    stage_ = Stage::DoCopy;
                }
                break;
            case VarintTarget::Seek: {
                // Zigzag decode: encode(n) = (n<<1)^(n>>63); decode(u) = (u>>1)^-(u&1)
                int64_t offset = static_cast<int64_t>(val >> 1) ^ -static_cast<int64_t>(val & 1);
                if (base_.seek(offset, SeekWhence::Cur) < 0) {
                    DASHPOD_ERROR("inflate: base file seek failed (offset=", offset, ")");
                    had_error_ = true;
                    return false;
                }
                vtarget_ = VarintTarget::AddLen;
                // back to ReadVarint for next add_len
                break;
            }
        }
        return true;
    }

public:
    BipatchReader(IReadSeek& base, std::ofstream& out)
        : base_(base), out_(out) {}

    // Feed a chunk of decompressed bipatch data.  Returns false on error.
    bool feed(const uint8_t* data, size_t len) {
        for (size_t i = 0; i < len && !had_error_; ++i) {
            const uint8_t b = data[i];
            switch (stage_) {
                case Stage::ReadHeader:
                    hdr_[hdr_pos_++] = b;
                    if (hdr_pos_ == 8) {
                        // Little-endian reads, host-endian agnostic
                        uint32_t magic = uint32_t(hdr_[0]) | (uint32_t(hdr_[1]) << 8)
                                       | (uint32_t(hdr_[2]) << 16) | (uint32_t(hdr_[3]) << 24);
                        uint32_t ver   = uint32_t(hdr_[4]) | (uint32_t(hdr_[5]) << 8)
                                       | (uint32_t(hdr_[6]) << 16) | (uint32_t(hdr_[7]) << 24);
                        if (magic != 0x0000B1DFu || ver != 0x00001000u) {
                            DASHPOD_ERROR("inflate: bad bipatch header "
                                          "(magic=0x", std::hex, magic,
                                          " ver=0x", ver, ")");
                            had_error_ = true;
                            return false;
                        }
                        stage_   = Stage::ReadVarint;
                        vtarget_ = VarintTarget::AddLen;
                    }
                    break;

                case Stage::ReadVarint:
                    varint_acc_ |= (uint64_t(b & 0x7F) << varint_shift_);
                    varint_shift_ += 7;
                    if (!(b & 0x80)) {
                        uint64_t val = varint_acc_;
                        if (!on_varint(val)) return false;
                    }
                    break;

                case Stage::DoAdd:
                    if (!add_byte(b)) return false;
                    if (--remaining_ == 0) {
                        stage_   = Stage::ReadVarint;
                        vtarget_ = VarintTarget::CopyLen;
                    }
                    break;

                case Stage::DoCopy:
                    if (!write_byte(b)) return false;
                    if (--remaining_ == 0) {
                        stage_   = Stage::ReadVarint;
                        vtarget_ = VarintTarget::Seek;
                    }
                    break;

                case Stage::Done:
                case Stage::Error:
                    break;
            }
        }
        return !had_error_;
    }

    // Call after all input has been fed.
    // Normal EOF: we are in ReadVarint stage reading add_len (start of loop),
    // including when we've read partial varint bytes — matches upstream behaviour.
    bool finalize() const {
        if (had_error_) return false;
        return (stage_ == Stage::ReadVarint && vtarget_ == VarintTarget::AddLen);
    }
};

}  // namespace

bool inflate_patch(const std::filesystem::path& patch_path,
                   IReadSeek& base,
                   const std::filesystem::path& output_path) {
    // Ensure output directory exists.
    if (output_path.has_parent_path()) {
        std::error_code ec;
        std::filesystem::create_directories(output_path.parent_path(), ec);
        if (ec) {
            DASHPOD_ERROR("inflate_patch: cannot create output dir: ", ec.message());
            return false;
        }
    }

    // Verify zstd magic before allocating the decompression context.
    {
        std::ifstream probe(patch_path, std::ios::binary);
        if (!probe) {
            DASHPOD_ERROR("inflate_patch: cannot open patch file: ", patch_path.string());
            return false;
        }
        uint8_t hdr[4]{};
        probe.read(reinterpret_cast<char*>(hdr), 4);
        if (probe.gcount() < 4
            || hdr[0] != 0x28 || hdr[1] != 0xB5
            || hdr[2] != 0x2F || hdr[3] != 0xFD) {
            DASHPOD_ERROR("inflate_patch: not a zstd frame: ", patch_path.string());
            return false;
        }
    }

    std::ifstream patch_file(patch_path, std::ios::binary);
    if (!patch_file) {
        DASHPOD_ERROR("inflate_patch: cannot re-open patch file: ", patch_path.string());
        return false;
    }
    std::ofstream out_file(output_path, std::ios::binary | std::ios::trunc);
    if (!out_file) {
        DASHPOD_ERROR("inflate_patch: cannot open output file: ", output_path.string());
        return false;
    }

    ZSTD_DStream* dstream = ZSTD_createDStream();
    if (!dstream) {
        DASHPOD_ERROR("inflate_patch: ZSTD_createDStream failed");
        return false;
    }
    ZSTD_initDStream(dstream);

    BipatchReader reader(base, out_file);

    constexpr size_t IN_CHUNK  = 65536;
    constexpr size_t OUT_CHUNK = 131072;
    std::vector<uint8_t> in_buf(IN_CHUNK);
    std::vector<uint8_t> out_buf(OUT_CHUNK);

    bool ok = true;
    while (ok) {
        patch_file.read(reinterpret_cast<char*>(in_buf.data()), IN_CHUNK);
        auto n_read = static_cast<size_t>(patch_file.gcount());
        if (n_read == 0) break;

        ZSTD_inBuffer zin{ in_buf.data(), n_read, 0 };
        while (zin.pos < zin.size) {
            ZSTD_outBuffer zout{ out_buf.data(), OUT_CHUNK, 0 };
            size_t ret = ZSTD_decompressStream(dstream, &zout, &zin);
            if (ZSTD_isError(ret)) {
                DASHPOD_ERROR("inflate_patch: zstd error: ", ZSTD_getErrorName(ret));
                ok = false;
                break;
            }
            if (zout.pos > 0 && !reader.feed(out_buf.data(), zout.pos)) {
                DASHPOD_ERROR("inflate_patch: bipatch error");
                ok = false;
                break;
            }
        }
    }

    ZSTD_freeDStream(dstream);

    if (ok && !reader.finalize()) {
        DASHPOD_ERROR("inflate_patch: bipatch stream ended unexpectedly");
        ok = false;
    }
    return ok;
}

}  // namespace dashpod::core