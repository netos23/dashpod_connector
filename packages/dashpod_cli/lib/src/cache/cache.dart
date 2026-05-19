import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../env/dashpod_env.dart';
import '../logger/logger.dart';
import 'cache_artifact.dart';

/// CLI-managed download cache for vendored tools.
///
/// Modelled on the cache described in
/// `private_docs/CLIENT_ARCHITECTURE.MD §4.3`. Bin layout:
///
/// ```
/// <cacheRoot>/
/// └── artifacts/
///     ├── patch              # bsdiff packager (later tier)
///     ├── aot_tools          # iOS AOT linker / dump_blobs (later tier)
///     └── bundletool.jar     # Android APK split tool (later tier)
/// ```
///
/// Concrete artefacts are *registered by the consumers that need them*
/// (release / patch / preview commands). The scaffold here ships with no
/// artefacts; `cache clean` still works.
class Cache {
  Cache({
    required this.env,
    required this.logger,
    List<CachedArtifact> artifacts = const [],
    HttpClient? httpClient,
  })  : _artifacts = List.unmodifiable(artifacts),
        _httpClient = httpClient ?? HttpClient();

  final DashpodEnv env;
  final Logger logger;
  final List<CachedArtifact> _artifacts;
  final HttpClient _httpClient;

  List<CachedArtifact> get artifacts => _artifacts;

  /// Root cache directory. Defaults to `<configDirectory>/cache/`. Made
  /// lazy because most CLI invocations don't touch the cache.
  Directory get root => Directory(p.join(env.cacheDirectory.path));

  /// Subdirectory containing artefact files.
  Directory get artifactDirectory =>
      Directory(p.join(root.path, 'artifacts'));

  /// Returns true when [artifact] is present on disk and its hash matches
  /// [CachedArtifact.expectedSha256] (or no hash was pinned).
  Future<bool> isInstalled(CachedArtifact artifact) async {
    final file = artifact.installedFile(env, artifactDirectory);
    if (!file.existsSync()) return false;
    final expected = artifact.expectedSha256;
    if (expected == null) return true;
    return await _hash(file) == expected;
  }

  /// Downloads any missing or stale artefacts. Idempotent — safe to call
  /// at the top of every command that needs vendored tools.
  Future<void> updateAll() async {
    for (final artifact in _artifacts) {
      if (await isInstalled(artifact)) {
        logger.detail('cache: ${artifact.name} up to date');
        continue;
      }
      await _download(artifact);
    }
  }

  /// Removes the entire on-disk cache. Mirrors `dashpod cache clean`.
  void clean() {
    if (root.existsSync()) {
      logger.detail('cache: removing ${root.path}');
      root.deleteSync(recursive: true);
    }
  }

  Future<void> _download(CachedArtifact artifact) async {
    artifactDirectory.createSync(recursive: true);
    final dest = artifact.installedFile(env, artifactDirectory);
    final tmp = File('${dest.path}.tmp');
    if (tmp.existsSync()) tmp.deleteSync();

    logger.info('Downloading ${artifact.name} from ${artifact.downloadUrl}');
    final request = await _httpClient.getUrl(artifact.downloadUrl);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Failed to download ${artifact.name}: HTTP ${response.statusCode}',
        uri: artifact.downloadUrl,
      );
    }
    await response.pipe(tmp.openWrite());

    final expected = artifact.expectedSha256;
    if (expected != null) {
      final actual = await _hash(tmp);
      if (actual != expected) {
        tmp.deleteSync();
        throw StateError(
          'Hash mismatch for ${artifact.name}: expected $expected, got $actual',
        );
      }
    }

    tmp.renameSync(dest.path);
    if (artifact.markExecutable && !Platform.isWindows) {
      await Process.run('chmod', ['+x', dest.path]);
    }
    logger.detail('cache: installed ${artifact.name} → ${dest.path}');
  }

  Future<String> _hash(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  void close() => _httpClient.close(force: true);
}

// Surface the crypto import so the analyzer doesn't complain when the
// hash code path is unreachable in a given build.
// ignore: unused_element
final _keepCrypto = utf8.encoder;
