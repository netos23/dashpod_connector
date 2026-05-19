import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

/// SHA-256 + size pair, as referenced by the wire protocol and by
/// on-device verification (`private_docs/ARCHITECTURE.MD §7.2`).
@immutable
class ArtifactDigest {
  const ArtifactDigest({required this.sha256, required this.size});

  /// Lowercase hex SHA-256 of the (uncompressed) artifact bytes.
  final String sha256;
  final int size;
}

/// Version extracted from a built artifact. Encodes Android's split of
/// `versionName` + `versionCode` into the canonical `name+code`
/// representation used by the wire protocol.
@immutable
class ReleaseVersion {
  const ReleaseVersion({required this.name, this.code});

  factory ReleaseVersion.parse(String raw) {
    final i = raw.indexOf('+');
    if (i < 0) return ReleaseVersion(name: raw);
    return ReleaseVersion(name: raw.substring(0, i), code: raw.substring(i + 1));
  }

  final String name;
  final String? code;

  String get wire => code == null ? name : '$name+$code';

  @override
  String toString() => wire;
}

/// Thrown when an artifact can't be located, parsed, or uploaded.
class ArtifactManagerException implements Exception {
  ArtifactManagerException(this.message);
  final String message;
  @override
  String toString() => 'ArtifactManagerException: $message';
}

/// Find / inspect / upload Flutter build outputs.
///
/// Mirrors `private_docs/CLIENT_ARCHITECTURE.MD §7.6`. Kept platform-
/// agnostic where possible; per-platform extraction lives in the methods
/// named after each artifact type.
class ArtifactManager {
  ArtifactManager({Dio? uploadClient}) : _upload = uploadClient ?? Dio();

  final Dio _upload;

  /// Hashes [file] (sha256) and returns it along with the on-disk size.
  Future<ArtifactDigest> digest(File file) async {
    final size = await file.length();
    final hash = await _sha256OfFile(file);
    return ArtifactDigest(sha256: hash, size: size);
  }

  /// Convenience for byte buffers — useful for synthesized supplements.
  ArtifactDigest digestBytes(List<int> bytes) {
    final hash = sha256.convert(bytes).toString();
    return ArtifactDigest(sha256: hash, size: bytes.length);
  }

  /// Extracts the version from an Android App Bundle by reading
  /// `base/manifest/AndroidManifest.xml` and pulling
  /// `versionName` + `versionCode`. Unlike APKs, the AAB stores the
  /// manifest as plain XML rather than the binary AXML format.
  Future<ReleaseVersion> extractAabVersion(File aab) async {
    final input = InputFileStream(aab.path);
    try {
      final zip = ZipDecoder().decodeStream(input);
      ArchiveFile? manifest;
      for (final entry in zip) {
        if (entry.isFile && entry.name == 'base/manifest/AndroidManifest.xml') {
          manifest = entry;
          break;
        }
      }
      if (manifest == null) {
        throw ArtifactManagerException(
          'AAB ${p.basename(aab.path)} did not contain base/manifest/AndroidManifest.xml.',
        );
      }
      final xml = utf8.decode(manifest.readBytes()!);
      final versionName = _matchAttribute(xml, 'versionName');
      final versionCode = _matchAttribute(xml, 'versionCode');
      if (versionName == null) {
        throw ArtifactManagerException(
          'Manifest in ${p.basename(aab.path)} did not declare versionName.',
        );
      }
      return ReleaseVersion(name: versionName, code: versionCode);
    } finally {
      await input.close();
    }
  }

  /// Zips [directory] into [output], preserving relative paths. Returns
  /// the resulting file. Used to bundle the per-platform supplement
  /// (obfuscation map, etc.) into a single uploadable artifact.
  Future<File> zipDirectory(Directory directory, File output) async {
    final encoder = ZipFileEncoder()..create(output.path);
    try {
      await encoder.addDirectory(directory, includeDirName: false);
    } finally {
      await encoder.close();
    }
    return output;
  }

  /// Uploads the raw bytes of [file] to the signed URL [target].
  ///
  /// This is phase two of the two-phase artifact upload (phase one — the
  /// metadata POST that returns the URL — happens via the
  /// `dashpod_api` Retrofit client). The signed URL is typically a
  /// GCS/S3 PUT, so the body is the raw payload, not multipart.
  Future<void> uploadToSignedUrl(File file, String target) async {
    final size = await file.length();
    Stream<List<int>> body() => file.openRead();
    try {
      final response = await _upload.put<void>(
        target,
        data: body(),
        options: Options(
          headers: {
            HttpHeaders.contentLengthHeader: size,
            HttpHeaders.contentTypeHeader: 'application/octet-stream',
          },
          // Don't let Dio buffer the whole file in memory.
          requestEncoder: null,
        ),
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw ArtifactManagerException(
          'Upload to signed URL returned status $code.',
        );
      }
    } on DioException catch (e) {
      throw ArtifactManagerException(
        'Upload to signed URL failed: ${e.message}',
      );
    }
  }

  Future<String> _sha256OfFile(File file) async {
    final digest = AccumulatorSink<Digest>();
    final input = sha256.startChunkedConversion(digest);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    return digest.events.single.toString();
  }

  String? _matchAttribute(String xml, String attribute) {
    final pattern = RegExp('$attribute="([^"]*)"');
    final m = pattern.firstMatch(xml);
    return m?.group(1);
  }
}
