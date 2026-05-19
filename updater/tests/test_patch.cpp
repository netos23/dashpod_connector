// Round-trip test for dashpod::patch::make_patch.
//
// Strategy: generate a patch with make_patch, write it to a temp file,
// feed it back through dashpod::core::inflate_patch (the updater's
// production apply path), and assert that the reconstructed bytes equal
// `newer` byte-for-byte. This is the strongest possible compatibility
// guarantee — anything inflate_patch accepts is, by definition, a valid
// dashpod patch.

#include <catch2/catch_test_macros.hpp>

#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <random>
#include <string>
#include <vector>

#include "core/inflate.h"
#include "io/read_seek.h"

#include "dashpod_patch/patch.h"

namespace {

class MemReadSeek final : public dashpod::IReadSeek {
    std::vector<std::uint8_t> data_;
    std::size_t pos_ = 0;
public:
    explicit MemReadSeek(std::vector<std::uint8_t> d) : data_(std::move(d)) {}

    std::size_t read(std::uint8_t* buf, std::size_t count) override {
        std::size_t avail = data_.size() - pos_;
        std::size_t n = std::min(count, avail);
        if (n > 0) { std::memcpy(buf, data_.data() + pos_, n); pos_ += n; }
        return n;
    }
    std::int64_t seek(std::int64_t offset, dashpod::SeekWhence whence) override {
        std::int64_t np;
        switch (whence) {
            case dashpod::SeekWhence::Set: np = offset; break;
            case dashpod::SeekWhence::Cur: np = std::int64_t(pos_) + offset; break;
            case dashpod::SeekWhence::End: np = std::int64_t(data_.size()) + offset; break;
            default: return -1;
        }
        if (np < 0 || np > std::int64_t(data_.size())) return -1;
        pos_ = std::size_t(np);
        return np;
    }
};

struct TmpDir {
    std::filesystem::path path;
    explicit TmpDir(const std::string& tag) {
        path = std::filesystem::temp_directory_path()
             / ("dashpod_patch_test_" + tag);
        std::filesystem::create_directories(path);
    }
    ~TmpDir() { std::error_code ec; std::filesystem::remove_all(path, ec); }
    std::filesystem::path file(const std::string& name) const {
        return path / name;
    }
};

void write_bytes(const std::filesystem::path& p,
                 const std::vector<std::uint8_t>& bytes) {
    std::ofstream f(p, std::ios::binary | std::ios::trunc);
    REQUIRE(f.good());
    f.write(reinterpret_cast<const char*>(bytes.data()),
            static_cast<std::streamsize>(bytes.size()));
}

std::vector<std::uint8_t> read_bytes(const std::filesystem::path& p) {
    std::ifstream f(p, std::ios::binary);
    REQUIRE(f.good());
    return std::vector<std::uint8_t>(
        std::istreambuf_iterator<char>(f),
        std::istreambuf_iterator<char>());
}

std::vector<std::uint8_t> from_str(const std::string& s) {
    return std::vector<std::uint8_t>(s.begin(), s.end());
}

// Round-trip helper: make a patch from older→newer, apply it, return
// the reconstructed bytes.
std::vector<std::uint8_t> roundtrip(const std::vector<std::uint8_t>& older,
                                    const std::vector<std::uint8_t>& newer,
                                    const std::string& tag) {
    TmpDir tmp(tag);
    const auto patch_bytes = dashpod::patch::make_patch(older, newer);

    // zstd magic sanity-check on every output.
    REQUIRE(patch_bytes.size() >= 4);
    REQUIRE(patch_bytes[0] == 0x28);
    REQUIRE(patch_bytes[1] == 0xB5);
    REQUIRE(patch_bytes[2] == 0x2F);
    REQUIRE(patch_bytes[3] == 0xFD);

    const auto patch_path  = tmp.file("patch.zstd");
    const auto output_path = tmp.file("output.bin");
    write_bytes(patch_path, patch_bytes);

    MemReadSeek base(older);
    REQUIRE(dashpod::core::inflate_patch(patch_path, base, output_path));

    return read_bytes(output_path);
}

}  // namespace

TEST_CASE("make_patch hello-world round-trips through inflate_patch", "[patch]") {
    const auto older = from_str("hello world");
    const auto newer = from_str("hello world!");
    REQUIRE(roundtrip(older, newer, "hello") == newer);
}

TEST_CASE("make_patch foo→bar round-trips", "[patch]") {
    // Same vectors used in upstream README. Patch bytes will differ
    // (different algorithm) but the result must match.
    const auto older = from_str("foo");
    const auto newer = from_str("bar");
    REQUIRE(roundtrip(older, newer, "foobar") == newer);
}

TEST_CASE("make_patch identical inputs round-trip", "[patch]") {
    const auto data = from_str("the quick brown fox jumps over the lazy dog");
    REQUIRE(roundtrip(data, data, "identical") == data);
}

TEST_CASE("make_patch empty older round-trips", "[patch]") {
    const std::vector<std::uint8_t> older;
    const auto newer = from_str("starting from nothing");
    REQUIRE(roundtrip(older, newer, "empty_older") == newer);
}

TEST_CASE("make_patch empty newer round-trips", "[patch]") {
    const auto older = from_str("anything");
    const std::vector<std::uint8_t> newer;
    REQUIRE(roundtrip(older, newer, "empty_newer") == newer);
}

TEST_CASE("make_patch both empty round-trip", "[patch]") {
    const std::vector<std::uint8_t> empty;
    REQUIRE(roundtrip(empty, empty, "both_empty") == empty);
}

TEST_CASE("make_patch newer shorter than older", "[patch]") {
    const auto older = from_str("a much longer string that gets truncated");
    const auto newer = from_str("a much longer");
    REQUIRE(roundtrip(older, newer, "shorter") == newer);
}

TEST_CASE("make_patch large random binary with localised change", "[patch]") {
    // Simulates the typical update case: a binary mostly identical to
    // its predecessor with a small diff. The patch should reconstruct
    // perfectly regardless of compression ratio.
    std::mt19937 rng(0xDA5780D);
    std::uniform_int_distribution<int> byte_dist(0, 255);

    std::vector<std::uint8_t> older(64 * 1024);
    for (auto& b : older) b = static_cast<std::uint8_t>(byte_dist(rng));

    auto newer = older;
    // Mutate a 256-byte window in the middle.
    for (std::size_t i = 30 * 1024; i < 30 * 1024 + 256; ++i) {
        newer[i] = static_cast<std::uint8_t>(byte_dist(rng));
    }
    // Append 128 fresh bytes.
    for (int i = 0; i < 128; ++i) {
        newer.push_back(static_cast<std::uint8_t>(byte_dist(rng)));
    }

    REQUIRE(roundtrip(older, newer, "rand64k") == newer);
}

TEST_CASE("make_patch handles structural insertion", "[patch]") {
    // Inserts a 32-byte block in the middle — exercises bsdiff's seek
    // emission (the back half of `older` aligns to a shifted position
    // in `newer`).
    std::string a = "AAAAAAAAAAAAAAAA";
    std::string b = "BBBBBBBBBBBBBBBB";
    std::string c = "CCCCCCCCCCCCCCCC";
    std::string ins = "[INSERTED-CHUNK-32BYTES-LONG-XX]";  // 32 bytes

    const auto older = from_str(a + b + c);
    const auto newer = from_str(a + ins + b + c);

    REQUIRE(roundtrip(older, newer, "insertion") == newer);
}
