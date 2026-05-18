#include "cache/signing.h"

#include <array>
#include <cstdint>
#include <fstream>
#include <memory>

#include <openssl/decoder.h>
#include <openssl/evp.h>

#include "core/error.h"
#include "util/logging.h"

namespace dashpod::signing {

namespace {

// ---------------------------------------------------------------
// SHA-256 via OpenSSL EVP (authoritative, no home-baked risk).
// ---------------------------------------------------------------

std::string digest_to_hex(const unsigned char* d) {
    static const char digits[] = "0123456789abcdef";
    std::string out(64, '0');
    for (int i = 0; i < 32; ++i) {
        out[i*2    ] = digits[(d[i] >> 4) & 0xF];
        out[i*2 + 1] = digits[d[i] & 0xF];
    }
    return out;
}

// ---------------------------------------------------------------
// Base64 decoder — handles standard (+/) and URL-safe (-_) variants.
// Skips whitespace; stops at '='.
// Throws UpdaterError on invalid characters.
// ---------------------------------------------------------------

static int b64_val(unsigned char c) {
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= 'a' && c <= 'z') return c - 'a' + 26;
    if (c >= '0' && c <= '9') return c - '0' + 52;
    if (c == '+' || c == '-') return 62;
    if (c == '/' || c == '_') return 63;
    return -1;
}

std::vector<std::uint8_t> b64_decode(const std::string& s) {
    std::vector<std::uint8_t> out;
    out.reserve(s.size() * 3 / 4);
    std::uint32_t acc = 0;
    int bits = 0;
    for (unsigned char c : s) {
        if (c == '=' || c == '\n' || c == '\r' || c == ' ') continue;
        int v = b64_val(c);
        if (v < 0) {
            throw UpdaterError(UpdaterError::Kind::BadServerResponse,
                std::string("Invalid base64 character: ") + char(c));
        }
        acc = (acc << 6) | std::uint32_t(v);
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            out.push_back(std::uint8_t(acc >> bits));
        }
    }
    return out;
}

// RAII wrappers for OpenSSL objects.
struct EVPPKEYDeleter { void operator()(EVP_PKEY* p) const { EVP_PKEY_free(p); } };
struct EVPMDCTXDeleter { void operator()(EVP_MD_CTX* p) const { EVP_MD_CTX_free(p); } };
struct OSSLDecoderCTXDeleter {
    void operator()(OSSL_DECODER_CTX* p) const { OSSL_DECODER_CTX_free(p); }
};

}  // namespace

// ---------------------------------------------------------------
// Public API
// ---------------------------------------------------------------

std::string hash_file(const std::filesystem::path& path) {
    std::ifstream in(path, std::ios::binary);
    if (!in) {
        throw UpdaterError(UpdaterError::Kind::Io,
            "Failed to open " + path.string());
    }
    std::unique_ptr<EVP_MD_CTX, EVPMDCTXDeleter> ctx(EVP_MD_CTX_new());
    if (!ctx || EVP_DigestInit_ex(ctx.get(), EVP_sha256(), nullptr) != 1) {
        throw UpdaterError(UpdaterError::Kind::Io, "EVP_DigestInit_ex failed");
    }
    std::array<char, 8192> buf{};
    while (in.good()) {
        in.read(buf.data(), buf.size());
        const auto got = static_cast<std::size_t>(in.gcount());
        if (got == 0) break;
        EVP_DigestUpdate(ctx.get(), buf.data(), got);
    }
    unsigned char digest[32];
    unsigned int dlen = 32;
    EVP_DigestFinal_ex(ctx.get(), digest, &dlen);
    return digest_to_hex(digest);
}

std::string hash_bytes(const void* data, std::size_t size) {
    std::unique_ptr<EVP_MD_CTX, EVPMDCTXDeleter> ctx(EVP_MD_CTX_new());
    if (!ctx || EVP_DigestInit_ex(ctx.get(), EVP_sha256(), nullptr) != 1) {
        throw UpdaterError(UpdaterError::Kind::Io, "EVP_DigestInit_ex failed");
    }
    if (size > 0) EVP_DigestUpdate(ctx.get(), data, size);
    unsigned char digest[32];
    unsigned int dlen = 32;
    EVP_DigestFinal_ex(ctx.get(), digest, &dlen);
    return digest_to_hex(digest);
}

bool check_signature(const std::string& message,
                     const std::string& signature_b64,
                     const std::string& public_key_b64) {
    // Decode inputs.
    auto key_der = b64_decode(public_key_b64);
    auto sig_bytes = b64_decode(signature_b64);

    // Decode PKCS#1 DER RSA public key via the OpenSSL 3.x decoder API.
    // "RSAPublicKey" is the OSSL structure name for PKCS#1 SEQUENCE{n,e}.
    EVP_PKEY* raw_pkey = nullptr;
    std::unique_ptr<OSSL_DECODER_CTX, OSSLDecoderCTXDeleter> dctx(
        OSSL_DECODER_CTX_new_for_pkey(
            &raw_pkey, "DER", "RSAPublicKey", "RSA",
            OSSL_KEYMGMT_SELECT_PUBLIC_KEY, nullptr, nullptr));
    if (!dctx) {
        throw UpdaterError(UpdaterError::Kind::BadServerResponse,
            "check_signature: failed to create decoder context");
    }
    const unsigned char* p = key_der.data();
    std::size_t remaining = key_der.size();
    if (!OSSL_DECODER_from_data(dctx.get(), &p, &remaining)) {
        throw UpdaterError(UpdaterError::Kind::BadServerResponse,
            "check_signature: failed to decode RSA public key (expected PKCS#1 DER)");
    }
    std::unique_ptr<EVP_PKEY, EVPPKEYDeleter> pkey(raw_pkey);

    // Verify RSA-PKCS1-v1.5 SHA-256.
    // The signed payload is the bytes of the hex-encoded hash string, not
    // the raw 32-byte digest — this matches the Rust reference's ring::verify call.
    std::unique_ptr<EVP_MD_CTX, EVPMDCTXDeleter> mctx(EVP_MD_CTX_new());
    if (!mctx) {
        throw UpdaterError(UpdaterError::Kind::BadServerResponse,
            "check_signature: EVP_MD_CTX_new failed");
    }
    if (EVP_DigestVerifyInit(mctx.get(), nullptr, EVP_sha256(),
                              nullptr, pkey.get()) != 1) {
        return false;
    }
    if (EVP_DigestVerifyUpdate(mctx.get(), message.data(), message.size()) != 1) {
        return false;
    }
    int rc = EVP_DigestVerifyFinal(
        mctx.get(),
        reinterpret_cast<const unsigned char*>(sig_bytes.data()),
        sig_bytes.size());
    // rc == 1: valid; rc == 0: bad sig; rc == -1: format error
    return rc == 1;
}

}  // namespace dashpod::signing