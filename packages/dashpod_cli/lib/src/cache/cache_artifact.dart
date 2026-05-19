import 'dart:io';

import '../env/dashpod_env.dart';

/// A single artefact the CLI vendors (e.g. the `patch` bsdiff binary,
/// `aot_tools`, `bundletool.jar`). See `private_docs/CLIENT_ARCHITECTURE.MD
/// §4.3`.
///
/// Implementations declare *what* they are; downloading, hashing and
/// install-path resolution is delegated back to [Cache] so the per-artefact
/// surface stays tiny.
abstract class CachedArtifact {
  const CachedArtifact();

  /// Human label used in progress messages (`Downloading <name>…`).
  String get name;

  /// File name on disk. Combined with [Cache.artifactDirectory] to form
  /// the absolute install path.
  String get fileName;

  /// Where the bytes are fetched from.
  Uri get downloadUrl;

  /// Hex-encoded SHA-256 of the artefact. Optional during early
  /// development; once pinned, the cache verifies on every update.
  String? get expectedSha256 => null;

  /// Whether the file should be made executable after download (Unix
  /// only; ignored on Windows).
  bool get markExecutable => false;

  File installedFile(DashpodEnv env, Directory artifactDirectory) =>
      File('${artifactDirectory.path}/$fileName');
}
