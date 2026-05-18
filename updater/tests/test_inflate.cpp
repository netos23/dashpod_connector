#include <catch2/catch_test_macros.hpp>

#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

#include "core/inflate.h"
#include "io/read_seek.h"

// ---------------------------------------------------------------------------
// In-memory IReadSeek — used as the "base" libapp.so in tests.
// ---------------------------------------------------------------------------
class MemReadSeek final : public dashpod::IReadSeek {
    std::vector<uint8_t> data_;
    size_t pos_ = 0;
public:
    explicit MemReadSeek(std::vector<uint8_t> d) : data_(std::move(d)) {}
    explicit MemReadSeek(const char* s)
        : data_(reinterpret_cast<const uint8_t*>(s),
                reinterpret_cast<const uint8_t*>(s) + std::strlen(s)) {}

    std::size_t read(uint8_t* buf, std::size_t count) override {
        size_t avail = data_.size() - pos_;
        size_t n = std::min(count, avail);
        if (n > 0) { std::memcpy(buf, data_.data() + pos_, n); pos_ += n; }
        return n;
    }

    std::int64_t seek(std::int64_t offset, dashpod::SeekWhence whence) override {
        int64_t new_pos;
        switch (whence) {
            case dashpod::SeekWhence::Set: new_pos = offset;               break;
            case dashpod::SeekWhence::Cur: new_pos = int64_t(pos_) + offset; break;
            case dashpod::SeekWhence::End: new_pos = int64_t(data_.size()) + offset; break;
            default: return -1;
        }
        if (new_pos < 0 || new_pos > int64_t(data_.size())) return -1;
        pos_ = size_t(new_pos);
        return new_pos;
    }
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
namespace {

struct TmpDir {
    std::filesystem::path path;
    explicit TmpDir(const std::string& tag) {
        path = std::filesystem::temp_directory_path()
             / ("dashpod_inflate_test_" + tag);
        std::filesystem::create_directories(path);
    }
    ~TmpDir() { std::error_code ec; std::filesystem::remove_all(path, ec); }
    std::filesystem::path file(const std::string& name) const {
        return path / name;
    }
};

void write_file(const std::filesystem::path& p, const uint8_t* data, size_t len) {
    std::ofstream f(p, std::ios::binary | std::ios::trunc);
    REQUIRE(f.good());
    f.write(reinterpret_cast<const char*>(data), static_cast<std::streamsize>(len));
}

std::string read_file(const std::filesystem::path& p) {
    std::ifstream f(p, std::ios::binary);
    REQUIRE(f.good());
    return std::string(std::istreambuf_iterator<char>(f), {});
}

}  // namespace

// ---------------------------------------------------------------------------
// Test vectors
//
// Generated from the Rust reference (patch/src/lib.rs round-trip test):
//   base   = b"hello world"  (11 bytes)
//   target = b"hello world!" (12 bytes)
//   compressed_patch = [...28 bytes below...]
//   zstd(bipatch(base → target)) == compressed_patch
// ---------------------------------------------------------------------------

// clang-format off
static const uint8_t kHelloWorldPatch[] = {
    40, 181,  47, 253,  // zstd magic
     0, 128, 157,   0,
     0, 104, 223, 177,
     0,   0,   0,  16,
     0,   0,  11,   0,
     1,  33,   0,   1,
     0,  27,  64,   2,
};
// clang-format on
static const char kBase[] = "hello world";
static const char kExpected[] = "hello world!";

TEST_CASE("inflate_patch hello-world round-trip", "[inflate]") {
    TmpDir tmp("hello");
    auto patch_path  = tmp.file("patch.zstd");
    auto output_path = tmp.file("libapp.so");

    write_file(patch_path, kHelloWorldPatch, sizeof(kHelloWorldPatch));

    MemReadSeek base(kBase);
    bool ok = dashpod::core::inflate_patch(patch_path, base, output_path);
    REQUIRE(ok == true);

    auto result = read_file(output_path);
    REQUIRE(result == kExpected);
}

TEST_CASE("inflate_patch rejects non-zstd magic", "[inflate]") {
    TmpDir tmp("badmagic");
    auto patch_path  = tmp.file("bad.bin");
    auto output_path = tmp.file("out.so");

    uint8_t garbage[] = { 0x00, 0x01, 0x02, 0x03, 0xFF, 0xFF };
    write_file(patch_path, garbage, sizeof(garbage));

    MemReadSeek base(kBase);
    bool ok = dashpod::core::inflate_patch(patch_path, base, output_path);
    REQUIRE(ok == false);
}

TEST_CASE("inflate_patch fails gracefully on missing patch file", "[inflate]") {
    TmpDir tmp("missing");
    MemReadSeek base(kBase);
    bool ok = dashpod::core::inflate_patch(
        tmp.file("does_not_exist.zstd"), base, tmp.file("out.so"));
    REQUIRE(ok == false);
}

TEST_CASE("inflate_patch creates parent directories for output", "[inflate]") {
    TmpDir tmp("mkdirs");
    auto patch_path  = tmp.file("patch.zstd");
    auto output_path = tmp.path / "sub" / "dir" / "libapp.so";

    write_file(patch_path, kHelloWorldPatch, sizeof(kHelloWorldPatch));

    MemReadSeek base(kBase);
    bool ok = dashpod::core::inflate_patch(patch_path, base, output_path);
    REQUIRE(ok == true);
    REQUIRE(std::filesystem::exists(output_path));
}
