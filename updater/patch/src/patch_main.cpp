// File-based patch CLI. Mirrors upstream patch/src/main.rs.
//
//   patch <base> <new> <output>
//
// Reads `base` and `new` fully into memory, produces a bipatch+zstd
// binary patch, writes it to `output`.

#include <chrono>
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>
#include <vector>

#include "dashpod_patch/patch.h"

namespace {

std::vector<std::uint8_t> read_file(const std::filesystem::path& p) {
    std::ifstream f(p, std::ios::binary);
    if (!f) {
        std::cerr << "patch: cannot open " << p.string() << "\n";
        std::exit(1);
    }
    return std::vector<std::uint8_t>(
        std::istreambuf_iterator<char>(f),
        std::istreambuf_iterator<char>());
}

void write_file(const std::filesystem::path& p,
                const std::vector<std::uint8_t>& bytes) {
    std::ofstream f(p, std::ios::binary | std::ios::trunc);
    if (!f) {
        std::cerr << "patch: cannot create " << p.string() << "\n";
        std::exit(1);
    }
    f.write(reinterpret_cast<const char*>(bytes.data()),
            static_cast<std::streamsize>(bytes.size()));
}

void usage(const char* argv0) {
    auto name = std::filesystem::path(argv0).filename().string();
    std::cerr << "Usage: " << name << " <base> <new> <output>\n"
              << "  base:   Path to the base file\n"
              << "  new:    Path to the new file\n"
              << "  output: Path to the output patch file\n\n"
              << " This is an internal tool for creating binary diffs.\n";
}

}  // namespace

int main(int argc, char** argv) {
    if (argc < 4) {
        usage(argv[0]);
        return 1;
    }

    const std::filesystem::path base_path   = argv[1];
    const std::filesystem::path new_path    = argv[2];
    const std::filesystem::path output_path = argv[3];

    const auto t0 = std::chrono::steady_clock::now();

    const auto older = read_file(base_path);
    const auto newer = read_file(new_path);
    const auto patch = dashpod::patch::make_patch(older, newer);
    write_file(output_path, patch);

    const auto t1 = std::chrono::steady_clock::now();
    const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(t1 - t0).count();
    std::cout << "Completed in " << ms << " ms\n";
    return 0;
}
