import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../env/dashpod_env.dart';
import '../logger/logger.dart';
import '../process/dashpod_process.dart';

/// Build target the on-device updater needs to identify.
enum AndroidArch {
  arm64('arm64-v8a'),
  arm32('armeabi-v7a'),
  x86_64('x86_64');

  const AndroidArch(this.wire);

  /// Wire-format `arch` value (matches the table in
  /// `private_docs/CLIENT_ARCHITECTURE.MD §3.5.2`).
  final String wire;

  /// Sub-directory under `out/lib/<abi>/libapp.so` for this arch in the
  /// Flutter intermediates layout.
  String get abi => wire;

  static AndroidArch? fromWire(String wire) {
    for (final a in AndroidArch.values) {
      if (a.wire == wire) return a;
    }
    return null;
  }
}

/// Result of [ArtifactBuilder.buildAndroidAppBundle].
class AndroidAppBundleBuild {
  AndroidAppBundleBuild({
    required this.aab,
    required this.libapps,
    this.obfuscationMap,
  });

  /// Path to the produced `.aab` (the canonical release artifact).
  final File aab;

  /// Per-arch `libapp.so` snapshots captured from the stripped
  /// intermediates layout. Each entry is the AOT snapshot the on-device
  /// updater patches against — content-hashed and uploaded as a release
  /// artifact in its own right.
  final Map<AndroidArch, File> libapps;

  /// `build/dashpod/obfuscation_map.json` when `--obfuscate` was
  /// requested; otherwise null. Currently a placeholder — Tier 5's
  /// patcher will wire this through.
  final File? obfuscationMap;
}

/// Thrown when the host `flutter` invocation exits non-zero or the
/// expected outputs don't appear on disk.
class ArtifactBuildException implements Exception {
  ArtifactBuildException(this.message);

  final String message;

  @override
  String toString() => 'ArtifactBuildException: $message';
}

/// Wrapper around `flutter build appbundle`.
///
/// Mirrors `private_docs/CLIENT_ARCHITECTURE.MD §3.5.2 / §7.5`:
///   * runs through [DashpodProcess] so the vendored Flutter SDK (when
///     present) is honoured;
///   * pipes the public-key-for-signing through the
///     `DASHPOD_PUBLIC_KEY` environment variable so older Flutter forks
///     that don't know `--shorebird-public-key` silently ignore it;
///   * after every build, re-runs `flutter pub get` with the *system*
///     `flutter` to restore the user's IDE's `package_config.json`;
///   * locates the produced AAB and each requested arch's `libapp.so`
///     in the standard Flutter intermediates layout.
///
/// This builder deliberately knows nothing about the server side — it's
/// the input to a [Releaser].
class ArtifactBuilder {
  ArtifactBuilder({
    required this.env,
    required this.process,
    required this.logger,
  });

  final DashpodEnv env;
  final DashpodProcess process;
  final Logger logger;

  /// Runs `flutter build appbundle` for [archs] (default: all three
  /// supported architectures) and returns paths to the AAB + per-arch
  /// `libapp.so` snapshots.
  ///
  /// - [projectRoot] is the dir containing `pubspec.yaml`.
  /// - [flavor] is the Flutter flavor (`null` means no flavor).
  /// - [publicKey] is the base64 DER blob from `code_signer` (Tier 5);
  ///   forwarded via env var when present.
  Future<AndroidAppBundleBuild> buildAndroidAppBundle({
    required Directory projectRoot,
    List<AndroidArch> archs = AndroidArch.values,
    String? flavor,
    String? buildName,
    String? buildNumber,
    bool obfuscate = false,
    String? publicKey,
    List<String> extraArgs = const [],
  }) async {
    if (archs.isEmpty) {
      throw ArgumentError('At least one Android arch is required.');
    }

    final args = <String>['build', 'appbundle', '--release'];
    args.add('--target-platform=${[for (final a in archs) 'android-${_targetPlatformSuffix(a)}'].join(',')}');
    if (flavor != null) args.add('--flavor=$flavor');
    if (buildName != null) args.add('--build-name=$buildName');
    if (buildNumber != null) args.add('--build-number=$buildNumber');
    if (obfuscate) {
      args
        ..add('--obfuscate')
        ..add('--split-debug-info=${p.join(projectRoot.path, 'build', 'dashpod', 'symbols')}');
    }
    args.addAll(extraArgs);

    final flutterEnv = <String, String>{};
    if (publicKey != null && publicKey.isNotEmpty) {
      flutterEnv['DASHPOD_PUBLIC_KEY'] = publicKey;
    }

    logger.info('Running `flutter ${args.join(' ')}` …');
    final exitCode = await process.stream(
      'flutter',
      args,
      workingDirectory: projectRoot.path,
      environment: flutterEnv,
    );
    if (exitCode != 0) {
      throw ArtifactBuildException(
        'flutter build appbundle exited with $exitCode.',
      );
    }

    await _restoreIdePackageConfig(projectRoot);

    final aab = _locateAab(projectRoot, flavor);
    if (aab == null) {
      throw ArtifactBuildException(
        'Could not find the produced .aab under '
        '${p.join(projectRoot.path, 'build', 'app', 'outputs', 'bundle')}.',
      );
    }

    final libapps = <AndroidArch, File>{};
    for (final arch in archs) {
      final file = _locateLibapp(projectRoot, flavor, arch);
      if (file == null) {
        throw ArtifactBuildException(
          'Could not find libapp.so for ${arch.wire} under build/app/intermediates.',
        );
      }
      libapps[arch] = file;
    }

    final obfuscationMap = obfuscate
        ? File(p.join(projectRoot.path, 'build', 'dashpod', 'obfuscation_map.json'))
        : null;

    return AndroidAppBundleBuild(
      aab: aab,
      libapps: libapps,
      obfuscationMap:
          (obfuscationMap?.existsSync() ?? false) ? obfuscationMap : null,
    );
  }

  String _targetPlatformSuffix(AndroidArch a) => switch (a) {
        AndroidArch.arm64 => 'arm64',
        AndroidArch.arm32 => 'arm',
        AndroidArch.x86_64 => 'x64',
      };

  File? _locateAab(Directory projectRoot, String? flavor) {
    final bundleDir = Directory(
      p.join(projectRoot.path, 'build', 'app', 'outputs', 'bundle'),
    );
    if (!bundleDir.existsSync()) return null;
    final flavorSegment = flavor == null ? 'release' : '${flavor}Release';
    final candidate = Directory(p.join(bundleDir.path, flavorSegment));
    if (candidate.existsSync()) {
      final aabs = candidate
          .listSync(recursive: false)
          .whereType<File>()
          .where((f) => p.extension(f.path) == '.aab')
          .toList();
      if (aabs.isNotEmpty) return aabs.first;
    }
    final aabs = bundleDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => p.extension(f.path) == '.aab')
        .toList();
    return aabs.isEmpty ? null : aabs.first;
  }

  File? _locateLibapp(Directory projectRoot, String? flavor, AndroidArch arch) {
    final intermediates = Directory(p.join(
      projectRoot.path,
      'build',
      'app',
      'intermediates',
      'stripped_native_libs',
    ));
    if (!intermediates.existsSync()) return null;
    final matches = intermediates
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) {
          final pathSegments = p.split(f.path);
          if (p.basename(f.path) != 'libapp.so') return false;
          if (!pathSegments.contains(arch.abi)) return false;
          if (flavor != null) {
            final lower = flavor.toLowerCase();
            return pathSegments.any((s) => s.toLowerCase().contains(lower));
          }
          return true;
        })
        .toList();
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _restoreIdePackageConfig(Directory projectRoot) async {
    final systemFlutter = _systemFlutterPath();
    if (systemFlutter == null) {
      logger.detail('No system flutter on PATH; skipping IDE pub-get restore.');
      return;
    }
    logger.detail('Restoring IDE package_config.json via system flutter…');
    final result = await process.run(
      systemFlutter,
      const ['pub', 'get'],
      workingDirectory: projectRoot.path,
      useVendedFlutter: false,
    );
    if (result.exitCode != 0) {
      logger.warn(
        'system `flutter pub get` exited ${result.exitCode}; '
        'your IDE may need a manual pub-get.',
      );
    }
  }

  String? _systemFlutterPath() {
    final pathEntries =
        (env.environment['PATH'] ?? '').split(Platform.isWindows ? ';' : ':');
    final filename = Platform.isWindows ? 'flutter.bat' : 'flutter';
    final vendedBin = env.vendedFlutterBinDir?.path;
    for (final dir in pathEntries) {
      if (dir.isEmpty) continue;
      if (vendedBin != null && p.equals(dir, vendedBin)) continue;
      final candidate = File(p.join(dir, filename));
      if (candidate.existsSync()) return candidate.path;
    }
    return null;
  }
}
