#include <catch2/catch_test_macros.hpp>

#include <cstring>
#include <filesystem>
#include <fstream>
#include <memory>
#include <string>
#include <vector>

#include <openssl/bio.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/rsa.h>

// Suppress deprecation warnings from the OpenSSL 1.x-compatible RSA APIs
// (EVP_PKEY_get1_RSA, i2d_RSAPublicKey) used only in test helpers to produce
// PKCS#1 DER for round-trip testing of check_signature.
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

#include "cache/signing.h"

// ---------------------------------------------------------------------------
// Helpers used only in this test file.
// ---------------------------------------------------------------------------

namespace {

// Simple base64 encoder (standard alphabet, no line breaks).
std::string b64_encode(const uint8_t* data, size_t len) {
    BIO* b64 = BIO_new(BIO_f_base64());
    BIO* mem = BIO_new(BIO_s_mem());
    BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
    BIO_push(b64, mem);
    BIO_write(b64, data, static_cast<int>(len));
    BIO_flush(b64);
    char* ptr = nullptr;
    long sz = BIO_get_mem_data(mem, &ptr);
    std::string result(ptr, static_cast<size_t>(sz));
    BIO_free_all(b64);
    return result;
}

struct TestKeyPair {
    std::string pub_b64;   // PKCS#1 DER, base64
    std::string priv_pem;  // for signing in tests (not used directly)
    EVP_PKEY*   pkey = nullptr;

    ~TestKeyPair() { if (pkey) EVP_PKEY_free(pkey); }
};

// Generate a 2048-bit RSA keypair and return the PKCS#1 DER public key as b64.
TestKeyPair make_test_keypair() {
    TestKeyPair kp;
    EVP_PKEY_CTX* ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, nullptr);
    REQUIRE(ctx != nullptr);
    REQUIRE(EVP_PKEY_keygen_init(ctx) == 1);
    REQUIRE(EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, 2048) > 0);
    REQUIRE(EVP_PKEY_keygen(ctx, &kp.pkey) == 1);
    EVP_PKEY_CTX_free(ctx);

    // Encode public key as PKCS#1 RSAPublicKey DER, then base64.
    // i2d_RSAPublicKey is the reliable way to get PKCS#1 DER (not SPKI).
    RSA* rsa = EVP_PKEY_get1_RSA(kp.pkey);
    REQUIRE(rsa != nullptr);
    unsigned char* der = nullptr;
    int der_len_int = i2d_RSAPublicKey(rsa, &der);
    RSA_free(rsa);
    REQUIRE(der_len_int > 0);
    kp.pub_b64 = b64_encode(der, static_cast<size_t>(der_len_int));
    OPENSSL_free(der);
    return kp;
}

// Sign `message` with `pkey` using RSA-PKCS1-v1.5 SHA-256.
std::string sign_message(EVP_PKEY* pkey, const std::string& message) {
    EVP_MD_CTX* mctx = EVP_MD_CTX_new();
    REQUIRE(mctx != nullptr);
    REQUIRE(EVP_DigestSignInit(mctx, nullptr, EVP_sha256(), nullptr, pkey) == 1);
    REQUIRE(EVP_DigestSignUpdate(mctx, message.data(), message.size()) == 1);
    size_t siglen = 0;
    REQUIRE(EVP_DigestSignFinal(mctx, nullptr, &siglen) == 1);
    std::vector<uint8_t> sig(siglen);
    REQUIRE(EVP_DigestSignFinal(mctx, sig.data(), &siglen) == 1);
    sig.resize(siglen);
    EVP_MD_CTX_free(mctx);
    return b64_encode(sig.data(), siglen);
}

}  // namespace

#pragma GCC diagnostic pop  // -Wdeprecated-declarations

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

TEST_CASE("hash_bytes produces correct SHA-256", "[signing]") {
    // SHA-256("abc") verified against Python hashlib, OpenSSL, Node.js, sha256sum.
    const std::string abc = "abc";
    auto h = dashpod::signing::hash_bytes(abc.data(), abc.size());
    REQUIRE(h == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
}

TEST_CASE("hash_bytes empty input", "[signing]") {
    // SHA-256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
    auto h = dashpod::signing::hash_bytes(nullptr, 0);
    REQUIRE(h == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
}

TEST_CASE("hash_file matches hash_bytes", "[signing]") {
    // Write known content to a temp file, hash both ways, compare.
    auto tmp = std::filesystem::temp_directory_path() / "dashpod_hash_test.bin";
    {
        std::ofstream f(tmp, std::ios::binary);
        REQUIRE(f.good());
        const std::string data = "hello dashpod";
        f.write(data.data(), static_cast<std::streamsize>(data.size()));
    }
    auto from_file  = dashpod::signing::hash_file(tmp);
    auto from_bytes = dashpod::signing::hash_bytes("hello dashpod", 13);
    std::filesystem::remove(tmp);
    REQUIRE(from_file == from_bytes);
}

TEST_CASE("check_signature round-trip", "[signing]") {
    auto kp = make_test_keypair();
    const std::string message = "bb8f1d041a5cdc259055afe9617136799543e0a7a86f86db82f8c1fadbd8cc45";
    auto sig_b64 = sign_message(kp.pkey, message);

    REQUIRE(dashpod::signing::check_signature(message, sig_b64, kp.pub_b64) == true);
}

TEST_CASE("check_signature rejects wrong message", "[signing]") {
    auto kp = make_test_keypair();
    const std::string message = "bb8f1d041a5cdc259055afe9617136799543e0a7a86f86db82f8c1fadbd8cc45";
    auto sig_b64 = sign_message(kp.pkey, message);

    // Same sig, different message → must fail.
    REQUIRE(dashpod::signing::check_signature("wrong_hash", sig_b64, kp.pub_b64) == false);
}

TEST_CASE("check_signature rejects tampered signature", "[signing]") {
    auto kp = make_test_keypair();
    const std::string message = "aabbcc";
    auto sig_b64 = sign_message(kp.pkey, message);

    // Corrupt the base64 string by flipping one character.
    auto bad_sig = sig_b64;
    bad_sig[4] = (bad_sig[4] == 'A') ? 'B' : 'A';
    REQUIRE(dashpod::signing::check_signature(message, bad_sig, kp.pub_b64) == false);
}

TEST_CASE("check_signature rejects wrong key", "[signing]") {
    auto kp1 = make_test_keypair();
    auto kp2 = make_test_keypair();
    const std::string message = "some_hash";
    auto sig_b64 = sign_message(kp1.pkey, message);

    // Signature is valid for kp1 but not kp2.
    REQUIRE(dashpod::signing::check_signature(message, sig_b64, kp2.pub_b64) == false);
}
