#include "cache/signing.h"

#include <array>
#include <cstdint>
#include <cstring>
#include <fstream>

#include "core/error.h"
#include "util/logging.h"

namespace dashpod::signing {

namespace {

// ---------------------------------------------------------------
// SHA-256 reference implementation.
//
// Used because we want zero external crypto dependencies for the
// bootstrap. When we link OpenSSL / BoringSSL we can swap this for
// EVP_Digest and delete this code.
// ---------------------------------------------------------------

struct Sha256 {
    std::uint32_t h[8] {
        0x6a09e667u, 0xbb67ae85u, 0x3c6ef372u, 0xa54ff53au,
        0x510e527fu, 0x9b05688cu, 0x1f83d9abu, 0x5be0cd19u
    };
    std::array<std::uint8_t, 64> buffer{};
    std::size_t buffer_len = 0;
    std::uint64_t bits = 0;

    static constexpr std::uint32_t K[64] = {
        0x428a2f98u,0x71374491u,0xb5c0fbcfu,0xe9b5dba5u,
        0x3956c25bu,0x59f111f1u,0x923f82a4u,0xab1c5ed5u,
        0xd807aa98u,0x12835b01u,0x243185beu,0x550c7dc3u,
        0x72be5d74u,0x80deb1feu,0x9bdc06a7u,0xc19bf174u,
        0xe49b69c1u,0xefbe4786u,0x0fc19dc6u,0x240ca1ccu,
        0x2de92c6fu,0x4a7484aau,0x5cb0a9dcu,0x76f988dau,
        0x983e5152u,0xa831c66du,0xb00327c8u,0xbf597fc7u,
        0xc6e00bf3u,0xd5a79147u,0x06ca6351u,0x14292967u,
        0x27b70a85u,0x2e1b2138u,0x4d2c6dfcu,0x53380d13u,
        0x650a7354u,0x766a0abbu,0x81c2c92eu,0x92722c85u,
        0xa2bfe8a1u,0xa81a664bu,0xc24b8b70u,0xc76c51a3u,
        0xd192e819u,0xd6990624u,0xf40e3585u,0x106aa070u,
        0x19a4c116u,0x1e376c08u,0x2748774cu,0x34b0bcb5u,
        0x391c0cb3u,0x4ed8aa4au,0x5b9cca4fu,0x682e6ff3u,
        0x748f82eeu,0x78a5636fu,0x84c87814u,0x8cc70208u,
        0x90befffau,0xa4506cebu,0xbef9a3f7u,0xc67178f2u
    };

    static std::uint32_t rotr(std::uint32_t x, unsigned n) {
        return (x >> n) | (x << (32 - n));
    }

    void compress(const std::uint8_t* block) {
        std::uint32_t w[64];
        for (int i = 0; i < 16; ++i) {
            w[i] = (std::uint32_t(block[i*4    ]) << 24) |
                   (std::uint32_t(block[i*4 + 1]) << 16) |
                   (std::uint32_t(block[i*4 + 2]) <<  8) |
                   (std::uint32_t(block[i*4 + 3]));
        }
        for (int i = 16; i < 64; ++i) {
            std::uint32_t s0 = rotr(w[i-15], 7) ^ rotr(w[i-15], 18) ^ (w[i-15] >>  3);
            std::uint32_t s1 = rotr(w[i-2], 17) ^ rotr(w[i-2],  19) ^ (w[i-2]  >> 10);
            w[i] = w[i-16] + s0 + w[i-7] + s1;
        }

        std::uint32_t a=h[0],b=h[1],c=h[2],d=h[3],e=h[4],f=h[5],g=h[6],hh=h[7];
        for (int i = 0; i < 64; ++i) {
            std::uint32_t S1 = rotr(e,6) ^ rotr(e,11) ^ rotr(e,25);
            std::uint32_t ch = (e & f) ^ (~e & g);
            std::uint32_t t1 = hh + S1 + ch + K[i] + w[i];
            std::uint32_t S0 = rotr(a,2) ^ rotr(a,13) ^ rotr(a,22);
            std::uint32_t mj = (a & b) ^ (a & c) ^ (b & c);
            std::uint32_t t2 = S0 + mj;
            hh = g; g = f; f = e; e = d + t1;
            d  = c; c = b; b = a; a = t1 + t2;
        }
        h[0]+=a; h[1]+=b; h[2]+=c; h[3]+=d;
        h[4]+=e; h[5]+=f; h[6]+=g; h[7]+=hh;
    }

    void update(const std::uint8_t* data, std::size_t len) {
        bits += static_cast<std::uint64_t>(len) * 8;
        while (len > 0) {
            std::size_t take = std::min<std::size_t>(64 - buffer_len, len);
            std::memcpy(buffer.data() + buffer_len, data, take);
            buffer_len += take;
            data += take;
            len  -= take;
            if (buffer_len == 64) {
                compress(buffer.data());
                buffer_len = 0;
            }
        }
    }

    std::array<std::uint8_t, 32> finish() {
        buffer[buffer_len++] = 0x80;
        if (buffer_len > 56) {
            while (buffer_len < 64) buffer[buffer_len++] = 0;
            compress(buffer.data());
            buffer_len = 0;
        }
        while (buffer_len < 56) buffer[buffer_len++] = 0;
        for (int i = 7; i >= 0; --i) {
            buffer[buffer_len++] = static_cast<std::uint8_t>(bits >> (i*8));
        }
        compress(buffer.data());

        std::array<std::uint8_t, 32> out{};
        for (int i = 0; i < 8; ++i) {
            out[i*4    ] = static_cast<std::uint8_t>(h[i] >> 24);
            out[i*4 + 1] = static_cast<std::uint8_t>(h[i] >> 16);
            out[i*4 + 2] = static_cast<std::uint8_t>(h[i] >>  8);
            out[i*4 + 3] = static_cast<std::uint8_t>(h[i]);
        }
        return out;
    }
};

std::string to_hex(const std::array<std::uint8_t, 32>& bytes) {
    static const char* digits = "0123456789abcdef";
    std::string out(64, '0');
    for (std::size_t i = 0; i < 32; ++i) {
        out[i*2    ] = digits[(bytes[i] >> 4) & 0xF];
        out[i*2 + 1] = digits[bytes[i] & 0xF];
    }
    return out;
}

}  // namespace

std::string hash_file(const std::filesystem::path& path) {
    std::ifstream in(path, std::ios::binary);
    if (!in) {
        throw UpdaterError(UpdaterError::Kind::Io,
            "Failed to open " + path.string());
    }
    Sha256 h;
    std::array<char, 8192> buf{};
    while (in.good()) {
        in.read(buf.data(), buf.size());
        const auto got = static_cast<std::size_t>(in.gcount());
        if (got == 0) break;
        h.update(reinterpret_cast<const std::uint8_t*>(buf.data()), got);
    }
    return to_hex(h.finish());
}

std::string hash_bytes(const void* data, std::size_t size) {
    Sha256 h;
    h.update(static_cast<const std::uint8_t*>(data), size);
    return to_hex(h.finish());
}

bool check_signature(const std::string& message,
                     const std::string& signature_b64,
                     const std::string& public_key_b64) {
    // TODO: implement using OpenSSL EVP_PKEY_verify (RSA-PKCS1-v1.5,
    // SHA-256). For now we fail closed when verification is requested,
    // which preserves the security posture: an unverifiable patch is
    // treated as bad rather than silently accepted.
    (void)message;
    (void)signature_b64;
    (void)public_key_b64;
    DASHPOD_WARN("check_signature: RSA verification is not yet implemented");
    return false;
}

}  // namespace dashpod::signing
