#include <catch2/catch_test_macros.hpp>

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

#include "platform/android.h"

// ---------------------------------------------------------------------------
// ZIP builder — produces minimal but structurally valid ZIP files.
//
// Layout written:
//   [local file header + data]  ×  entries
//   [central directory entries] ×  entries
//   [end of central directory]
//
// Compression is always STORED (method 0).  CRC-32 is set to 0 (our reader
// does not verify it, nor does inflate_patch — the hash check after inflate
// is the integrity gate in production).
// ---------------------------------------------------------------------------
namespace {

struct ZipEntry {
    std::string          name;
    std::vector<uint8_t> data;
    uint32_t             local_offset = 0; // filled in by write_zip
};

static void w16(std::vector<uint8_t>& out, uint16_t v) {
    out.push_back(static_cast<uint8_t>(v));
    out.push_back(static_cast<uint8_t>(v >> 8));
}
static void w32(std::vector<uint8_t>& out, uint32_t v) {
    out.push_back(static_cast<uint8_t>(v));
    out.push_back(static_cast<uint8_t>(v >> 8));
    out.push_back(static_cast<uint8_t>(v >> 16));
    out.push_back(static_cast<uint8_t>(v >> 24));
}
static void wbytes(std::vector<uint8_t>& out, const void* p, size_t n) {
    const auto* b = static_cast<const uint8_t*>(p);
    out.insert(out.end(), b, b + n);
}

// Builds a STORED ZIP containing all entries and returns the raw bytes.
std::vector<uint8_t> build_zip(std::vector<ZipEntry>& entries) {
    std::vector<uint8_t> buf;

    // Local file headers + data
    for (auto& e : entries) {
        e.local_offset = static_cast<uint32_t>(buf.size());
        w32(buf, 0x04034B50u);                             // local sig
        w16(buf, 20);                                       // version needed
        w16(buf, 0);                                        // flags
        w16(buf, 0);                                        // method: STORED
        w16(buf, 0); w16(buf, 0);                           // mod time, mod date
        w32(buf, 0);                                        // CRC-32 (not verified)
        w32(buf, static_cast<uint32_t>(e.data.size()));    // compressed size
        w32(buf, static_cast<uint32_t>(e.data.size()));    // uncompressed size
        w16(buf, static_cast<uint16_t>(e.name.size()));    // fname len
        w16(buf, 0);                                        // extra len
        wbytes(buf, e.name.data(), e.name.size());
        wbytes(buf, e.data.data(), e.data.size());
    }

    uint32_t cd_offset = static_cast<uint32_t>(buf.size());

    // Central directory entries
    for (const auto& e : entries) {
        w32(buf, 0x02014B50u);                             // central sig
        w16(buf, 20); w16(buf, 20);                         // version made, needed
        w16(buf, 0);                                        // flags
        w16(buf, 0);                                        // method: STORED
        w16(buf, 0); w16(buf, 0);                           // mod time, mod date
        w32(buf, 0);                                        // CRC-32
        w32(buf, static_cast<uint32_t>(e.data.size()));    // compressed size
        w32(buf, static_cast<uint32_t>(e.data.size()));    // uncompressed size
        w16(buf, static_cast<uint16_t>(e.name.size()));    // fname len
        w16(buf, 0); w16(buf, 0);                           // extra, comment len
        w16(buf, 0); w16(buf, 0);                           // disk start, int attrs
        w32(buf, 0);                                        // ext attrs
        w32(buf, e.local_offset);                           // local header offset
        wbytes(buf, e.name.data(), e.name.size());
    }

    uint32_t cd_size = static_cast<uint32_t>(buf.size()) - cd_offset;

    // End of central directory
    w32(buf, 0x06054B50u);                                  // EOCD sig
    w16(buf, 0); w16(buf, 0);                               // disk #, start disk
    w16(buf, static_cast<uint16_t>(entries.size()));        // entries on disk
    w16(buf, static_cast<uint16_t>(entries.size()));        // total entries
    w32(buf, cd_size);                                      // CD size
    w32(buf, cd_offset);                                    // CD offset
    w16(buf, 0);                                            // comment length

    return buf;
}

void write_file(const std::filesystem::path& p, const std::vector<uint8_t>& bytes) {
    std::ofstream f(p, std::ios::binary | std::ios::trunc);
    REQUIRE(f.good());
    f.write(reinterpret_cast<const char*>(bytes.data()),
            static_cast<std::streamsize>(bytes.size()));
}

struct TmpDir {
    std::filesystem::path path;
    explicit TmpDir(const std::string& tag) {
        path = std::filesystem::temp_directory_path()
             / ("dashpod_android_test_" + tag);
        std::filesystem::create_directories(path);
    }
    ~TmpDir() {
        std::error_code ec;
        std::filesystem::remove_all(path, ec);
    }
    std::filesystem::path file(const std::string& name) const { return path / name; }
};

// Read all bytes from an IReadSeek back to position 0.
std::vector<uint8_t> drain(dashpod::IReadSeek& rs) {
    rs.seek(0, dashpod::SeekWhence::Set);
    std::vector<uint8_t> out;
    uint8_t buf[4096];
    while (true) {
        auto n = rs.read(buf, sizeof(buf));
        if (n == 0) break;
        out.insert(out.end(), buf, buf + n);
    }
    return out;
}

} // namespace

// ---------------------------------------------------------------------------
// open_entry_from_zip tests
// ---------------------------------------------------------------------------

TEST_CASE("open_entry_from_zip finds a STORED entry and reads it back", "[android]") {
    TmpDir tmp("stored");
    const std::vector<uint8_t> payload = {0x48, 0x65, 0x6C, 0x6C, 0x6F}; // "Hello"

    std::vector<ZipEntry> entries;
    entries.push_back({"lib/arm64-v8a/libapp.so", payload});
    auto zip_bytes = build_zip(entries);
    write_file(tmp.file("base.apk"), zip_bytes);

    auto reader = dashpod::platform::open_entry_from_zip(
        tmp.file("base.apk"), "lib/arm64-v8a/libapp.so");
    REQUIRE(reader != nullptr);
    REQUIRE(drain(*reader) == payload);
}

TEST_CASE("open_entry_from_zip returns nullptr for missing entry", "[android]") {
    TmpDir tmp("missing_entry");
    std::vector<ZipEntry> entries;
    entries.push_back({"assets/foo.bin", {0x01, 0x02}});
    write_file(tmp.file("base.apk"), build_zip(entries));

    auto reader = dashpod::platform::open_entry_from_zip(
        tmp.file("base.apk"), "lib/arm64-v8a/libapp.so");
    REQUIRE(reader == nullptr);
}

TEST_CASE("open_entry_from_zip returns nullptr for non-existent file", "[android]") {
    TmpDir tmp("no_file");
    auto reader = dashpod::platform::open_entry_from_zip(
        tmp.file("does_not_exist.apk"), "lib/arm64-v8a/libapp.so");
    REQUIRE(reader == nullptr);
}

TEST_CASE("open_entry_from_zip with multiple entries selects the correct one", "[android]") {
    TmpDir tmp("multi_entry");
    const std::vector<uint8_t> libapp  = {0xAA, 0xBB, 0xCC};
    const std::vector<uint8_t> another = {0x11, 0x22, 0x33};

    std::vector<ZipEntry> entries;
    entries.push_back({"assets/flutter_assets/kernel_blob.bin", another});
    entries.push_back({"lib/arm64-v8a/libapp.so",               libapp});
    entries.push_back({"lib/arm64-v8a/libflutter.so",            another});
    write_file(tmp.file("base.apk"), build_zip(entries));

    auto reader = dashpod::platform::open_entry_from_zip(
        tmp.file("base.apk"), "lib/arm64-v8a/libapp.so");
    REQUIRE(reader != nullptr);
    REQUIRE(drain(*reader) == libapp);
}

TEST_CASE("open_entry_from_zip STORED seek works correctly", "[android]") {
    TmpDir tmp("seek");
    // 16 bytes of sequential data so we can verify seeking.
    const std::vector<uint8_t> payload = {
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15};

    std::vector<ZipEntry> entries;
    entries.push_back({"lib/x86_64/libapp.so", payload});
    write_file(tmp.file("base.apk"), build_zip(entries));

    auto reader = dashpod::platform::open_entry_from_zip(
        tmp.file("base.apk"), "lib/x86_64/libapp.so");
    REQUIRE(reader != nullptr);

    // Seek to middle and read 4 bytes.
    auto pos = reader->seek(4, dashpod::SeekWhence::Set);
    REQUIRE(pos == 4);
    uint8_t buf[4] = {};
    REQUIRE(reader->read(buf, 4) == 4);
    REQUIRE(buf[0] == 4);
    REQUIRE(buf[3] == 7);

    // Seek from current position.
    reader->seek(2, dashpod::SeekWhence::Cur);  // skip 2 more (was at 8)
    REQUIRE(reader->read(buf, 1) == 1);
    REQUIRE(buf[0] == 10);

    // Seek from end.
    reader->seek(-1, dashpod::SeekWhence::End);
    REQUIRE(reader->read(buf, 1) == 1);
    REQUIRE(buf[0] == 15);

    // Past-end read should return 0.
    reader->seek(0, dashpod::SeekWhence::End);
    REQUIRE(reader->read(buf, 1) == 0);
}

// ---------------------------------------------------------------------------
// open_libapp_from_apk_splits tests
// ---------------------------------------------------------------------------

// Builds the directory structure the function expects:
//   <root>/
//     <name>.apk            ← contains lib/<abi>/libapp.so
//     lib/<abi>/libapp.so   ← virtual path (may not exist on disk)
//
// Returns the virtual path to pass as apk_paths[0].
static std::filesystem::path setup_apk_dir(
    const TmpDir& tmp,
    const std::string& apk_name,
    const std::string& abi,
    const std::vector<uint8_t>& libapp_data) {
    std::string entry = "lib/" + abi + "/libapp.so";
    std::vector<ZipEntry> entries;
    entries.push_back({entry, libapp_data});
    write_file(tmp.path / apk_name, build_zip(entries));

    // The virtual path: <root>/lib/<abi>/libapp.so
    auto virtual_path = tmp.path / "lib" / abi / "libapp.so";
    std::filesystem::create_directories(virtual_path.parent_path());
    return virtual_path;
}

TEST_CASE("open_libapp_from_apk_splits finds entry via directory walk", "[android]") {
    TmpDir tmp("walk_aarch64");
    const std::vector<uint8_t> libapp = {0xDE, 0xAD, 0xBE, 0xEF};
    auto virtual_path = setup_apk_dir(tmp, "base.apk", "arm64-v8a", libapp);

    auto reader = dashpod::platform::open_libapp_from_apk_splits(
        {virtual_path}, "aarch64");
    REQUIRE(reader != nullptr);
    REQUIRE(drain(*reader) == libapp);
}

TEST_CASE("open_libapp_from_apk_splits handles x86_64 arch correctly", "[android]") {
    TmpDir tmp("walk_x86_64");
    const std::vector<uint8_t> libapp = {0x11, 0x22};
    auto virtual_path = setup_apk_dir(tmp, "split_config.x86_64.apk", "x86_64", libapp);

    auto reader = dashpod::platform::open_libapp_from_apk_splits(
        {virtual_path}, "x86_64");
    REQUIRE(reader != nullptr);
    REQUIRE(drain(*reader) == libapp);
}

TEST_CASE("open_libapp_from_apk_splits returns nullptr when wrong arch requested", "[android]") {
    TmpDir tmp("wrong_arch");
    // APK contains arm64-v8a but we request x86_64.
    auto virtual_path = setup_apk_dir(tmp, "base.apk", "arm64-v8a", {0xAA});

    auto reader = dashpod::platform::open_libapp_from_apk_splits(
        {virtual_path}, "x86_64");
    REQUIRE(reader == nullptr);
}

TEST_CASE("open_libapp_from_apk_splits searches multiple APKs", "[android]") {
    TmpDir tmp("multi_apk");
    const std::vector<uint8_t> libapp = {0xCA, 0xFE};

    // Put the entry only in the second APK.
    std::vector<ZipEntry> decoy_entries;
    decoy_entries.push_back({"assets/flutter_assets/kernel_blob.bin", {0x00}});
    write_file(tmp.path / "base.apk", build_zip(decoy_entries));

    std::vector<ZipEntry> payload_entries;
    payload_entries.push_back({"lib/arm64-v8a/libapp.so", libapp});
    write_file(tmp.path / "split_config.arm64_v8a.apk", build_zip(payload_entries));

    auto virtual_path = tmp.path / "lib" / "arm64-v8a" / "libapp.so";
    std::filesystem::create_directories(virtual_path.parent_path());

    auto reader = dashpod::platform::open_libapp_from_apk_splits(
        {virtual_path}, "aarch64");
    REQUIRE(reader != nullptr);
    REQUIRE(drain(*reader) == libapp);
}

TEST_CASE("open_libapp_from_apk_splits returns nullptr for empty paths", "[android]") {
    auto reader = dashpod::platform::open_libapp_from_apk_splits({}, "aarch64");
    REQUIRE(reader == nullptr);
}

TEST_CASE("open_libapp_from_apk_splits returns nullptr for unknown arch", "[android]") {
    TmpDir tmp("bad_arch");
    auto virtual_path = tmp.path / "lib" / "arm64-v8a" / "libapp.so";
    std::filesystem::create_directories(virtual_path.parent_path());

    auto reader = dashpod::platform::open_libapp_from_apk_splits(
        {virtual_path}, "mips64");
    REQUIRE(reader == nullptr);
}

TEST_CASE("open_libapp_from_apk_splits returns nullptr when directory has no APKs", "[android]") {
    TmpDir tmp("no_apks");
    // Write a non-APK file to make the directory non-empty.
    write_file(tmp.path / "random.bin", {0x00});
    auto virtual_path = tmp.path / "lib" / "arm64-v8a" / "libapp.so";
    std::filesystem::create_directories(virtual_path.parent_path());

    auto reader = dashpod::platform::open_libapp_from_apk_splits(
        {virtual_path}, "aarch64");
    REQUIRE(reader == nullptr);
}
