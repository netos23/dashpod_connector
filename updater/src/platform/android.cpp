// Upstream reference: library/src/android.rs
//
// On Android, libapp.so is not extracted to the filesystem — it lives inside
// a split APK zip as a STORED (uncompressed) entry.  The engine passes the
// virtual path `<pkg_dir>/lib/<abi>/libapp.so` in original_libapp_paths;
// we walk up 3 levels to find the package directory, enumerate *.apk files,
// and search each one's central directory for `lib/<abi>/libapp.so`.
//
// The implementation is a self-contained minimal ZIP reader that handles
// STORED entries (reads in-place from the raw file) and DEFLATE entries
// (inflates into memory using zlib when DASHPOD_HAVE_ZLIB is defined).
// ZIP64 is not supported because APKs targeting Android 5+ are always
// 32-bit ZIP.

#include "platform/android.h"

#include <cstring>
#include <fstream>
#include <system_error>
#include <vector>

#ifdef DASHPOD_HAVE_ZLIB
#include <zlib.h>
#endif

#include "util/logging.h"

namespace dashpod::platform {

namespace {

// ---- Architecture name mapping ----------------------------------------
// Wire arch name → ABI subdirectory inside the APK zip entry path.
const char* arch_to_abi(const std::string& arch) {
    if (arch == "aarch64") return "arm64-v8a";
    if (arch == "arm")     return "armeabi-v7a";
    if (arch == "x86")     return "x86";
    if (arch == "x86_64")  return "x86_64";
    return nullptr;
}

// ---- Little-endian read helpers ----------------------------------------

static uint16_t le_u16(const uint8_t* p) {
    return static_cast<uint16_t>(p[0]) | (static_cast<uint16_t>(p[1]) << 8);
}
static uint32_t le_u32(const uint8_t* p) {
    return static_cast<uint32_t>(p[0])
         | (static_cast<uint32_t>(p[1]) << 8)
         | (static_cast<uint32_t>(p[2]) << 16)
         | (static_cast<uint32_t>(p[3]) << 24);
}

static bool read_u16(std::istream& in, uint16_t& out) {
    uint8_t b[2];
    if (!in.read(reinterpret_cast<char*>(b), 2)) return false;
    out = le_u16(b);
    return true;
}
static bool read_u32(std::istream& in, uint32_t& out) {
    uint8_t b[4];
    if (!in.read(reinterpret_cast<char*>(b), 4)) return false;
    out = le_u32(b);
    return true;
}
static bool skip(std::istream& in, std::streamoff n) {
    in.seekg(n, std::ios::cur);
    return in.good();
}

// ---- ZIP format constants ----------------------------------------------

constexpr uint32_t kSigCentral = 0x02014B50;
constexpr uint32_t kSigEOCD    = 0x06054B50;

constexpr uint16_t kMethodStored  = 0;
constexpr uint16_t kMethodDeflate = 8;

// Subset of central directory entry fields we care about.
struct ZipEntry {
    uint16_t compression;
    uint32_t compressed_size;
    uint32_t uncompressed_size;
    uint32_t local_header_offset;
};

// ---- EOCD + central directory scan -------------------------------------

// Searches the ZIP central directory of `in` for `entry_name`.
// Returns std::nullopt if not found or on any parse error.
std::optional<ZipEntry> find_central_dir_entry(std::istream& in,
                                                const std::string& entry_name) {
    // Step 1: Locate End of Central Directory by scanning backwards from EOF.
    in.seekg(0, std::ios::end);
    auto file_size = static_cast<int64_t>(in.tellg());
    if (file_size < 22) return std::nullopt;

    // EOCD is at most 22 + 65535 bytes before the end of the file.
    auto search_size = std::min(file_size, static_cast<int64_t>(22 + 65535));
    std::vector<uint8_t> tail(static_cast<size_t>(search_size));
    in.seekg(file_size - search_size);
    if (!in.read(reinterpret_cast<char*>(tail.data()), search_size)) return std::nullopt;

    int eocd_off = -1;
    for (int i = static_cast<int>(tail.size()) - 22; i >= 0; --i) {
        if (le_u32(tail.data() + i) == kSigEOCD) {
            eocd_off = i;
            break;
        }
    }
    if (eocd_off < 0) return std::nullopt;

    // EOCD field layout (bytes relative to the record start):
    //   0   4   Signature
    //   4   2   Disk number
    //   6   2   Disk with start of CD
    //   8   2   Entries on this disk
    //  10   2   Total entries        ← le_u16(e + 10)
    //  12   4   Size of CD
    //  16   4   Offset of CD         ← le_u32(e + 16)
    //  20   2   Comment length
    const uint8_t* e = tail.data() + eocd_off;
    uint16_t total_entries = le_u16(e + 10);
    uint32_t cd_offset     = le_u32(e + 16);

    // ZIP64 signals both fields with 0xFFFF / 0xFFFFFFFF.
    if (total_entries == 0xFFFF || cd_offset == 0xFFFFFFFF) {
        DASHPOD_ERROR("android: ZIP64 not supported");
        return std::nullopt;
    }

    // Step 2: Scan central directory entries.
    // Central directory entry layout (bytes relative to entry start):
    //   0   4   Signature (0x02014B50)
    //   4   2   Version made by
    //   6   2   Version needed
    //   8   2   General purpose bit flag
    //  10   2   Compression method
    //  12   2   Mod time
    //  14   2   Mod date
    //  16   4   CRC-32
    //  20   4   Compressed size
    //  24   4   Uncompressed size
    //  28   2   File name length
    //  30   2   Extra field length
    //  32   2   File comment length
    //  34   2   Disk number start
    //  36   2   Internal file attributes
    //  38   4   External file attributes
    //  42   4   Relative offset of local header  ← at byte 42
    //  46   n   File name
    in.seekg(cd_offset);
    for (uint16_t i = 0; i < total_entries; ++i) {
        uint32_t sig;
        if (!read_u32(in, sig) || sig != kSigCentral) return std::nullopt;

        if (!skip(in, 4)) return std::nullopt; // version made by + version needed
        uint16_t flags;
        if (!read_u16(in, flags)) return std::nullopt;
        uint16_t compression;
        if (!read_u16(in, compression)) return std::nullopt;
        if (!skip(in, 4)) return std::nullopt; // mod time + mod date
        if (!skip(in, 4)) return std::nullopt; // crc32
        uint32_t compressed_size;
        if (!read_u32(in, compressed_size)) return std::nullopt;
        uint32_t uncompressed_size;
        if (!read_u32(in, uncompressed_size)) return std::nullopt;
        uint16_t fname_len, extra_len, comment_len;
        if (!read_u16(in, fname_len))   return std::nullopt;
        if (!read_u16(in, extra_len))   return std::nullopt;
        if (!read_u16(in, comment_len)) return std::nullopt;
        if (!skip(in, 8)) return std::nullopt; // disk start + int attrs + ext attrs
        uint32_t local_offset;
        if (!read_u32(in, local_offset)) return std::nullopt;

        std::string fname(fname_len, '\0');
        if (!in.read(fname.data(), fname_len)) return std::nullopt;
        if (!skip(in, static_cast<std::streamoff>(extra_len) + comment_len)) {
            return std::nullopt;
        }

        if (fname == entry_name) {
            return ZipEntry{compression, compressed_size, uncompressed_size, local_offset};
        }
    }
    return std::nullopt;
}

// Reads the local file header at `local_offset` and returns the absolute file
// offset where the entry's data bytes begin.
//
// Local file header layout (bytes relative to header start):
//   0   4   Signature (0x04034B50)
//   4   2   Version needed
//   6   2   Flags
//   8   2   Compression method
//  10   2   Mod time
//  12   2   Mod date
//  14   4   CRC-32
//  18   4   Compressed size
//  22   4   Uncompressed size
//  26   2   File name length   ← seek here
//  28   2   Extra field length
//  30   n   File name
//  30+n m   Extra field
//  30+n+m   File data          ← returned value
std::optional<uint64_t> local_data_start(std::istream& in, uint32_t local_offset) {
    in.seekg(static_cast<std::streamoff>(local_offset) + 26);
    uint16_t fname_len, extra_len;
    if (!read_u16(in, fname_len) || !read_u16(in, extra_len)) return std::nullopt;
    return static_cast<uint64_t>(local_offset) + 30 + fname_len + extra_len;
}

// ---- IReadSeek implementations -----------------------------------------

// Reads a bounded slice [base, base+size) of a file without decompression.
// Each SlicedFileReadSeek owns its own file handle for thread safety.
class SlicedFileReadSeek final : public IReadSeek {
    std::ifstream file_;
    uint64_t      base_;
    uint64_t      size_;
    uint64_t      pos_ = 0;
    bool          ok_;

public:
    SlicedFileReadSeek(const std::filesystem::path& path,
                       uint64_t base_offset,
                       uint64_t size)
        : file_(path, std::ios::binary),
          base_(base_offset),
          size_(size),
          ok_(file_.good()) {}

    bool ok() const { return ok_; }

    std::size_t read(uint8_t* buf, std::size_t count) override {
        if (!ok_ || pos_ >= size_) return 0;
        count = std::min(count, static_cast<std::size_t>(size_ - pos_));
        file_.seekg(static_cast<std::streamoff>(base_ + pos_));
        file_.read(reinterpret_cast<char*>(buf), static_cast<std::streamsize>(count));
        auto n = static_cast<std::size_t>(file_.gcount());
        pos_ += n;
        return n;
    }

    std::int64_t seek(std::int64_t offset, SeekWhence whence) override {
        if (!ok_) return -1;
        int64_t new_pos;
        switch (whence) {
            case SeekWhence::Set: new_pos = offset;                               break;
            case SeekWhence::Cur: new_pos = static_cast<int64_t>(pos_) + offset;  break;
            case SeekWhence::End: new_pos = static_cast<int64_t>(size_) + offset; break;
            default: return -1;
        }
        if (new_pos < 0 || static_cast<uint64_t>(new_pos) > size_) return -1;
        pos_ = static_cast<uint64_t>(new_pos);
        return new_pos;
    }
};

// Wraps an in-memory buffer produced by DEFLATE extraction.
class MemReadSeek final : public IReadSeek {
    std::vector<uint8_t> data_;
    std::size_t          pos_ = 0;

public:
    explicit MemReadSeek(std::vector<uint8_t> data) : data_(std::move(data)) {}

    std::size_t read(uint8_t* buf, std::size_t count) override {
        if (pos_ >= data_.size()) return 0;
        count = std::min(count, data_.size() - pos_);
        std::memcpy(buf, data_.data() + pos_, count);
        pos_ += count;
        return count;
    }

    std::int64_t seek(std::int64_t offset, SeekWhence whence) override {
        int64_t new_pos;
        switch (whence) {
            case SeekWhence::Set: new_pos = offset;                                    break;
            case SeekWhence::Cur: new_pos = static_cast<int64_t>(pos_) + offset;       break;
            case SeekWhence::End: new_pos = static_cast<int64_t>(data_.size()) + offset; break;
            default: return -1;
        }
        if (new_pos < 0 || static_cast<std::size_t>(new_pos) > data_.size()) return -1;
        pos_ = static_cast<std::size_t>(new_pos);
        return new_pos;
    }
};

}  // namespace

// ---- Public API --------------------------------------------------------

ReadSeekPtr open_entry_from_zip(const std::filesystem::path& zip_path,
                                 const std::string& entry_name) {
    std::ifstream in(zip_path, std::ios::binary);
    if (!in) {
        DASHPOD_ERROR("android: cannot open ", zip_path.string());
        return nullptr;
    }

    auto entry_opt = find_central_dir_entry(in, entry_name);
    if (!entry_opt.has_value()) return nullptr;
    const auto& entry = *entry_opt;

    auto data_start = local_data_start(in, entry.local_header_offset);
    if (!data_start.has_value()) {
        DASHPOD_ERROR("android: bad local header in ", zip_path.string());
        return nullptr;
    }

    if (entry.compression == kMethodStored) {
        auto reader = std::make_unique<SlicedFileReadSeek>(
            zip_path, *data_start, entry.uncompressed_size);
        if (!reader->ok()) {
            DASHPOD_ERROR("android: cannot re-open ", zip_path.string());
            return nullptr;
        }
        return reader;
    }

    if (entry.compression == kMethodDeflate) {
#ifdef DASHPOD_HAVE_ZLIB
        // ZIP uses raw DEFLATE (no zlib header), so windowBits = -15.
        in.seekg(static_cast<std::streamoff>(*data_start));
        std::vector<uint8_t> compressed(entry.compressed_size);
        if (!in.read(reinterpret_cast<char*>(compressed.data()),
                      static_cast<std::streamsize>(entry.compressed_size))) {
            DASHPOD_ERROR("android: short read of compressed entry");
            return nullptr;
        }
        std::vector<uint8_t> inflated(entry.uncompressed_size);
        z_stream zs{};
        zs.next_in   = compressed.data();
        zs.avail_in  = static_cast<uInt>(compressed.size());
        zs.next_out  = inflated.data();
        zs.avail_out = static_cast<uInt>(inflated.size());
        if (inflateInit2(&zs, -15) != Z_OK) {
            DASHPOD_ERROR("android: inflateInit2 failed");
            return nullptr;
        }
        int rc = inflate(&zs, Z_FINISH);
        inflateEnd(&zs);
        if (rc != Z_STREAM_END) {
            DASHPOD_ERROR("android: inflate failed (rc=", rc, ")");
            return nullptr;
        }
        inflated.resize(zs.total_out);
        return std::make_unique<MemReadSeek>(std::move(inflated));
#else
        DASHPOD_ERROR("android: DEFLATE entry '", entry_name,
                      "' requires zlib (build with DASHPOD_HAVE_ZLIB)");
        return nullptr;
#endif
    }

    DASHPOD_ERROR("android: unsupported compression method ", entry.compression,
                  " in '", entry_name, "'");
    return nullptr;
}

ReadSeekPtr open_libapp_from_apk_splits(
    const std::vector<std::filesystem::path>& apk_paths,
    const std::string& arch) {
    if (apk_paths.empty()) return nullptr;

    const char* abi = arch_to_abi(arch);
    if (abi == nullptr) {
        DASHPOD_ERROR("android: unknown arch '", arch, "'");
        return nullptr;
    }
    const std::string entry_name = std::string("lib/") + abi + "/libapp.so";

    // Walk 3 parent directories from the virtual libapp path to reach the
    // package directory that holds *.apk split files.
    // Example: /data/app/com.example/lib/arm64-v8a/libapp.so
    //   → parent × 1 = /data/app/com.example/lib/arm64-v8a
    //   → parent × 2 = /data/app/com.example/lib
    //   → parent × 3 = /data/app/com.example        ← enumerate *.apk here
    std::filesystem::path apk_dir = apk_paths[0];
    for (int i = 0; i < 3; ++i) apk_dir = apk_dir.parent_path();

    std::error_code ec;
    if (!std::filesystem::is_directory(apk_dir, ec)) {
        DASHPOD_ERROR("android: APK directory not found: ", apk_dir.string());
        return nullptr;
    }

    for (const auto& dir_entry :
         std::filesystem::directory_iterator(apk_dir, ec)) {
        if (dir_entry.path().extension() != ".apk") continue;
        auto reader = open_entry_from_zip(dir_entry.path(), entry_name);
        if (reader) return reader;
    }
    return nullptr;
}

}  // namespace dashpod::platform
