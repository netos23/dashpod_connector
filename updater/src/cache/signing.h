#pragma once

#include <filesystem>
#include <string>

namespace dashpod::signing {

// SHA-256 of the file at `path`, hex-encoded lowercase.
// Throws UpdaterError on I/O failure.
std::string hash_file(const std::filesystem::path& path);

// SHA-256 of an in-memory buffer, hex-encoded lowercase.
std::string hash_bytes(const void* data, std::size_t size);

// Verifies that `signature` is an RSA-PKCS1-v1.5 SHA-256 signature of
// `message`, produced by the private half of the base64-DER-encoded
// RSA public key `public_key`.
//
// The signed payload is the *bytes of the hex-encoded hash string*,
// not the raw 32-byte digest. This matches the Rust reference's
// `check_signature(message, signature, public_key)` call where
// `message` is the hex string from `hash_file`.
//
// Returns true on a valid signature, false otherwise. Throws
// UpdaterError only when the inputs themselves are malformed
// (un-decodable base64, etc.) — a clean "signature didn't match"
// returns false.
//
// NOTE: This is currently a stub. Implementing it requires a crypto
// library (OpenSSL libcrypto, BoringSSL, or libsodium for ed25519 if
// we switch algorithms). Once chosen, fill this in.
bool check_signature(const std::string& message,
                     const std::string& signature_b64,
                     const std::string& public_key_b64);

}  // namespace dashpod::signing
