// String-based patch CLI. Mirrors upstream patch/src/bin/string_patch.rs.
//
//   string_patch <base> <new>
//
// Takes two strings, prints the resulting patch bytes and the SHA-256
// hash of `new` — used to generate test expectations for the updater.

#include <cstdint>
#include <cstdio>
#include <iostream>
#include <string>
#include <vector>

#include <openssl/evp.h>
#include <openssl/sha.h>

#include "dashpod_patch/patch.h"

namespace {

std::string hex_encode(const std::uint8_t* data, std::size_t len) {
    static const char kHex[] = "0123456789abcdef";
    std::string s;
    s.resize(len * 2);
    for (std::size_t i = 0; i < len; ++i) {
        s[2 * i]     = kHex[(data[i] >> 4) & 0xF];
        s[2 * i + 1] = kHex[data[i] & 0xF];
    }
    return s;
}

std::string sha256_hex(const std::uint8_t* data, std::size_t len) {
    std::uint8_t digest[SHA256_DIGEST_LENGTH]{};
    unsigned int dlen = SHA256_DIGEST_LENGTH;
    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_sha256(), nullptr);
    EVP_DigestUpdate(ctx, data, len);
    EVP_DigestFinal_ex(ctx, digest, &dlen);
    EVP_MD_CTX_free(ctx);
    return hex_encode(digest, dlen);
}

}  // namespace

int main(int argc, char** argv) {
    if (argc < 3) {
        std::cerr << "Usage: " << (argc > 0 ? argv[0] : "string_patch")
                  << " <base> <new>\n";
        return 1;
    }

    const std::string older(argv[1]);
    const std::string newer(argv[2]);

    const auto older_bytes = std::vector<std::uint8_t>(older.begin(), older.end());
    const auto newer_bytes = std::vector<std::uint8_t>(newer.begin(), newer.end());

    const auto patch = dashpod::patch::make_patch(older_bytes, newer_bytes);

    std::cout << "Base: " << older << "\n";
    std::cout << "New: "  << newer << "\n";

    std::cout << "Patch: [";
    for (std::size_t i = 0; i < patch.size(); ++i) {
        if (i) std::cout << ", ";
        std::cout << static_cast<int>(patch[i]);
    }
    std::cout << "]\n";

    std::cout << "Hash (new): "
              << sha256_hex(newer_bytes.data(), newer_bytes.size()) << "\n";
    return 0;
}
