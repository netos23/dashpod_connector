import 'dart:io';

import 'package:path/path.dart' as p;

import '../env/dashpod_env.dart';
import 'cache.dart';
import 'cache_artifact.dart';

/// Vendored bsdiff-style `patch` executable used by Tier 5 to compute
/// per-arch snapshot diffs.
///
/// The on-disk binary mirrors what `private_docs/CLIENT_ARCHITECTURE.MD §3.6.2`
/// calls "Shorebird's vendored patch binary": given a release artifact and
/// a patch artifact, it emits a compressed delta the on-device updater
/// reconstructs against.
class PatchBinaryArtifact extends CachedArtifact {
  const PatchBinaryArtifact();

  @override
  String get name => 'patch';

  @override
  String get fileName => Platform.isWindows ? 'patch.exe' : 'patch';

  @override
  Uri get downloadUrl => Uri.parse(_downloadUrlForHost());

  @override
  bool get markExecutable => true;

  static String _downloadUrlForHost() {
    // TODO(dashpod): swap these for real published URLs once the patch
    // binary is in the artifact bucket.
    final base =
        Platform.environment['DASHPOD_PATCH_BINARY_BASE_URL'] ??
            'https://storage.googleapis.com/download.dashpod.dev/patch';
    final triple = switch (Platform.operatingSystem) {
      'macos' =>
        'darwin-${Platform.version.contains('arm64') ? 'arm64' : 'x64'}',
      'linux' => 'linux-x64',
      'windows' => 'windows-x64',
      _ => Platform.operatingSystem,
    };
    final suffix = Platform.isWindows ? '.exe' : '';
    return '$base/$triple/patch$suffix';
  }
}

/// Locator/runner for the vendored `patch` executable. Resolves the
/// on-disk path via [Cache] and exposes a thin [run] wrapper.
class PatchBinary {
  PatchBinary({required this.cache, this.artifact = const PatchBinaryArtifact()});

  final Cache cache;
  final CachedArtifact artifact;

  /// Absolute path the binary is installed at. Not guaranteed to exist
  /// until [Cache.updateAll] has run.
  File installedFile(DashpodEnv env) =>
      artifact.installedFile(env, cache.artifactDirectory);

  /// Runs `patch <release> <patch> <out>`. Throws on non-zero exit.
  Future<void> run({
    required DashpodEnv env,
    required File releaseFile,
    required File patchFile,
    required File outFile,
  }) async {
    final binary = installedFile(env);
    if (!binary.existsSync()) {
      throw StateError(
        'patch binary not found at ${binary.path}; run `dashpod cache` first.',
      );
    }
    outFile.parent.createSync(recursive: true);
    final result = await Process.run(
      binary.path,
      [releaseFile.path, patchFile.path, outFile.path],
      runInShell: false,
    );
    if (result.exitCode != 0) {
      throw StateError(
        'patch ${p.basename(releaseFile.path)} '
        '${p.basename(patchFile.path)} '
        '${p.basename(outFile.path)} '
        'exited ${result.exitCode}: ${result.stderr}',
      );
    }
  }
}
