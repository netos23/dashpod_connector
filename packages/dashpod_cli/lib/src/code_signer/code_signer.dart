import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:pointycastle/export.dart' as pc;

/// Errors surfaced from PEM decoding, signing, or verification round-trip.
class CodeSignerException implements Exception {
  CodeSignerException(this.message);
  final String message;
  @override
  String toString() => 'CodeSignerException: $message';
}

/// Signs a UTF-8 message (the hex hash of an artifact) with SHA-256 / RSA-PKCS1
/// and returns the base64-encoded raw signature bytes, OR pipes the hex hash
/// to an external command and reads back the base64 signature.
///
/// See `private_docs/CLIENT_ARCHITECTURE.MD §3.7`. Key handling:
///   * PKCS#1 (`-----BEGIN RSA PRIVATE KEY-----`) and PKCS#8
///     (`-----BEGIN PRIVATE KEY-----`) PEM inputs are both accepted.
///   * The public-key form embedded into the release is *not* the
///     SubjectPublicKeyInfo header — it's the inner
///     `SEQUENCE { INTEGER modulus, INTEGER exponent }` re-DER-encoded
///     and then base64'd. The on-device updater performs the inverse
///     during signature verification (see ARCHITECTURE.MD §7.3).
abstract class CodeSigner {
  Future<String> sign(String messageHex);

  /// The base64 DER blob embedded into the release (`DASHPOD_PUBLIC_KEY`
  /// env var) so the on-device updater can verify.
  String base64PublicKey();
}

class PemCodeSigner implements CodeSigner {
  PemCodeSigner({
    required pc.RSAPrivateKey privateKey,
    required pc.RSAPublicKey publicKey,
  })  : _private = privateKey,
        _public = publicKey;

  /// Loads a private key from a PEM string. The matching public key is
  /// derived from the private key.
  factory PemCodeSigner.fromPrivateKeyPem(String pem) {
    final priv = decodePrivateKey(pem);
    final pub = pc.RSAPublicKey(priv.modulus!, priv.publicExponent!);
    return PemCodeSigner(privateKey: priv, publicKey: pub);
  }

  /// Same as [fromPrivateKeyPem] but reads the PEM from disk.
  factory PemCodeSigner.fromPrivateKeyFile(File file) =>
      PemCodeSigner.fromPrivateKeyPem(file.readAsStringSync());

  final pc.RSAPrivateKey _private;
  final pc.RSAPublicKey _public;

  @override
  Future<String> sign(String messageHex) async {
    final signer = pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201')
      ..init(
        true,
        pc.PrivateKeyParameter<pc.RSAPrivateKey>(_private),
      );
    final sig = signer.generateSignature(
      Uint8List.fromList(utf8.encode(messageHex)),
    );
    final encoded = base64Encode(sig.bytes);
    _assertRoundTrip(messageHex, encoded);
    return encoded;
  }

  @override
  String base64PublicKey() => encodePublicKeyAsModulusExponentDer(_public);

  void _assertRoundTrip(String messageHex, String base64Signature) {
    if (!verifySignature(
      publicKey: _public,
      messageHex: messageHex,
      base64Signature: base64Signature,
    )) {
      throw CodeSignerException(
        'Signature failed self-verification — refusing to ship a patch '
        'nobody can verify.',
      );
    }
  }
}

/// Pipes the hex hash to `sh -c "<cmd>"`'s stdin and reads the base64
/// signature from stdout. Mirrors the `--sign-cmd` flag described in
/// §3.7. The output is round-trip verified against [publicKey] before
/// being returned.
class ExternalCommandCodeSigner implements CodeSigner {
  ExternalCommandCodeSigner({
    required this.command,
    required pc.RSAPublicKey publicKey,
  }) : _public = publicKey;

  final String command;
  final pc.RSAPublicKey _public;

  @override
  Future<String> sign(String messageHex) async {
    final shell = Platform.isWindows ? 'cmd' : 'sh';
    final shellArgs =
        Platform.isWindows ? const ['/c'] : const ['-c'];
    final process = await Process.start(shell, [...shellArgs, command]);
    process.stdin.writeln(messageHex);
    await process.stdin.close();
    final outBytes = await process.stdout.transform(utf8.decoder).join();
    final errBytes = await process.stderr.transform(utf8.decoder).join();
    final exit = await process.exitCode;
    if (exit != 0) {
      throw CodeSignerException(
        '--sign-cmd exited $exit: ${errBytes.trim()}',
      );
    }
    final base64Signature = outBytes.trim();
    if (!verifySignature(
      publicKey: _public,
      messageHex: messageHex,
      base64Signature: base64Signature,
    )) {
      throw CodeSignerException(
        '--sign-cmd output failed verification against the configured public key.',
      );
    }
    return base64Signature;
  }

  @override
  String base64PublicKey() => encodePublicKeyAsModulusExponentDer(_public);
}

bool verifySignature({
  required pc.RSAPublicKey publicKey,
  required String messageHex,
  required String base64Signature,
}) {
  try {
    final verifier =
        pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201')
          ..init(
            false,
            pc.PublicKeyParameter<pc.RSAPublicKey>(publicKey),
          );
    final sigBytes = base64Decode(base64Signature);
    return verifier.verifySignature(
      Uint8List.fromList(utf8.encode(messageHex)),
      pc.RSASignature(Uint8List.fromList(sigBytes)),
    );
  } catch (_) {
    return false;
  }
}

/// Re-DER-encodes [publicKey] as the bare `SEQUENCE { INTEGER modulus,
/// INTEGER exponent }` form expected by the on-device verifier.
String encodePublicKeyAsModulusExponentDer(pc.RSAPublicKey publicKey) {
  final seq = ASN1Sequence()
    ..add(ASN1Integer(publicKey.modulus!))
    ..add(ASN1Integer(publicKey.exponent!));
  return base64Encode(seq.encodedBytes);
}

/// Decodes a PEM-encoded RSA private key. Accepts both PKCS#1
/// (`-----BEGIN RSA PRIVATE KEY-----`) and PKCS#8
/// (`-----BEGIN PRIVATE KEY-----`) wrappers.
pc.RSAPrivateKey decodePrivateKey(String pem) {
  final trimmed = pem.trim();
  if (trimmed.contains('BEGIN RSA PRIVATE KEY')) {
    final bytes = _decodePemBody(
      trimmed,
      'BEGIN RSA PRIVATE KEY',
      'END RSA PRIVATE KEY',
    );
    return _parsePkcs1(bytes);
  }
  if (trimmed.contains('BEGIN PRIVATE KEY')) {
    final bytes = _decodePemBody(
      trimmed,
      'BEGIN PRIVATE KEY',
      'END PRIVATE KEY',
    );
    return _parsePkcs8(bytes);
  }
  throw CodeSignerException(
    'Unsupported PEM header — expected BEGIN RSA PRIVATE KEY (PKCS#1) '
    'or BEGIN PRIVATE KEY (PKCS#8).',
  );
}

/// Decodes the public-key form embedded into a release (the inverse of
/// [encodePublicKeyAsModulusExponentDer]). Useful for `--public-key`
/// flags whose contents are already base64'd into the wire format.
pc.RSAPublicKey decodeModulusExponentBase64(String base64Der) {
  final parser = ASN1Parser(base64Decode(base64Der));
  final seq = parser.nextObject() as ASN1Sequence;
  if (seq.elements.length < 2) {
    throw CodeSignerException(
      'Bare modulus/exponent ASN.1 sequence must have two elements.',
    );
  }
  final modulus = (seq.elements[0] as ASN1Integer).valueAsBigInteger;
  final exponent = (seq.elements[1] as ASN1Integer).valueAsBigInteger;
  return pc.RSAPublicKey(modulus, exponent);
}

/// Decodes a standard SubjectPublicKeyInfo (PKCS#8) PEM-wrapped RSA public key.
pc.RSAPublicKey decodePublicKeyPem(String pem) {
  final trimmed = pem.trim();
  if (!trimmed.contains('BEGIN PUBLIC KEY')) {
    throw CodeSignerException(
      'Unsupported public key PEM header — expected BEGIN PUBLIC KEY.',
    );
  }
  final bytes = _decodePemBody(trimmed, 'BEGIN PUBLIC KEY', 'END PUBLIC KEY');
  final spki = ASN1Parser(bytes).nextObject() as ASN1Sequence;
  // spki = SEQUENCE { AlgorithmIdentifier, BIT STRING wrapping RSAPublicKey }
  final bitString = spki.elements[1] as ASN1BitString;
  final rsa =
      ASN1Parser(Uint8List.fromList(bitString.stringValue)).nextObject()
          as ASN1Sequence;
  return pc.RSAPublicKey(
    (rsa.elements[0] as ASN1Integer).valueAsBigInteger,
    (rsa.elements[1] as ASN1Integer).valueAsBigInteger,
  );
}

Uint8List _decodePemBody(String pem, String beginToken, String endToken) {
  final lines = pem.split('\n');
  final body = StringBuffer();
  var inBody = false;
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.contains(beginToken)) {
      inBody = true;
      continue;
    }
    if (trimmed.contains(endToken)) {
      inBody = false;
      continue;
    }
    if (inBody) body.write(trimmed);
  }
  return Uint8List.fromList(base64Decode(body.toString()));
}

pc.RSAPrivateKey _parsePkcs1(Uint8List der) {
  final seq = ASN1Parser(der).nextObject() as ASN1Sequence;
  // PKCS#1 RSAPrivateKey ::= SEQUENCE {
  //   version, n, e, d, p, q, dp, dq, qinv, …
  // }
  final modulus = (seq.elements[1] as ASN1Integer).valueAsBigInteger;
  final privateExponent = (seq.elements[3] as ASN1Integer).valueAsBigInteger;
  final p = (seq.elements[4] as ASN1Integer).valueAsBigInteger;
  final q = (seq.elements[5] as ASN1Integer).valueAsBigInteger;
  return pc.RSAPrivateKey(modulus, privateExponent, p, q);
}

pc.RSAPrivateKey _parsePkcs8(Uint8List der) {
  final outer = ASN1Parser(der).nextObject() as ASN1Sequence;
  // PrivateKeyInfo ::= SEQUENCE {
  //   version, AlgorithmIdentifier, privateKey OCTET STRING wrapping the inner key
  // }
  final wrapped = outer.elements[2] as ASN1OctetString;
  final inner = Uint8List.fromList(wrapped.octets);
  return _parsePkcs1(inner);
}
