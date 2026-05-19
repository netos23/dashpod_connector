import 'dart:async';
import 'dart:io';

import 'package:dashpod_api/dashpod_api.dart';
import 'package:path/path.dart' as p;

import '../../artifact_builder/artifact_builder.dart';
import '../../artifact_manager/artifact_manager.dart';
import 'releaser.dart';

/// Android release pipeline.
///
/// Outputs (per `private_docs/CLIENT_ARCHITECTURE.MD §3.5.2`):
///   * one `libapp.so` per requested arch (`canSideload: false`);
///   * the `.aab` itself, `arch == "aab"`, `canSideload: true`;
///   * an `android_supplement.zip` when the build produced an
///     obfuscation map (`canSideload: false`).
class AndroidReleaser extends Releaser {
  AndroidReleaser(
    super.context, {
    required this.builder,
    required this.archs,
    this.obfuscate = false,
    this.buildName,
    this.buildNumber,
    this.extraBuildArgs = const [],
  });

  final ArtifactBuilder builder;
  final List<AndroidArch> archs;
  final bool obfuscate;
  final String? buildName;
  final String? buildNumber;
  final List<String> extraBuildArgs;

  AndroidAppBundleBuild? _build;

  @override
  String get platform => 'android';

  @override
  String get artifactDisplayName => 'Android App Bundle';

  @override
  String get postReleaseInstructions =>
      'Next step: ship the .aab through your store, then run\n'
      '  dashpod patch android --release-version=<version>\n'
      'to publish OTA patches against this release.';

  @override
  Future<void> assertArgsAreValid() async {
    if (archs.isEmpty) {
      throw const FormatException(
        'At least one --target-platform value is required.',
      );
    }
  }

  @override
  Future<File> buildReleaseArtifacts() async {
    final build = await builder.buildAndroidAppBundle(
      projectRoot: context.projectRoot,
      archs: archs,
      flavor: context.flavor,
      buildName: buildName,
      buildNumber: buildNumber,
      obfuscate: obfuscate,
      extraArgs: extraBuildArgs,
    );
    _build = build;
    return build.aab;
  }

  @override
  Future<ReleaseVersion> extractReleaseVersion(File primaryArtifact) {
    return context.artifacts.extractAabVersion(primaryArtifact);
  }

  @override
  Future<List<UploadedArtifact>> uploadReleaseArtifacts({
    required int releaseId,
    required File primaryArtifact,
  }) async {
    final build = _build;
    if (build == null) {
      throw StateError(
        'uploadReleaseArtifacts called before buildReleaseArtifacts.',
      );
    }

    final uploaded = <UploadedArtifact>[];

    for (final entry in build.libapps.entries) {
      uploaded.add(await _uploadOne(
        releaseId: releaseId,
        file: entry.value,
        arch: entry.key.wire,
        canSideload: false,
      ));
    }

    uploaded.add(await _uploadOne(
      releaseId: releaseId,
      file: primaryArtifact,
      arch: 'aab',
      canSideload: true,
    ));

    final supplementDir = await _assembleSupplementDirectory(build);
    if (supplementDir != null) {
      final zipPath = p.join(
        context.projectRoot.path,
        'build',
        'android',
        'dashpod',
        'android_supplement.zip',
      );
      final zip = await context.artifacts.zipDirectory(
        supplementDir,
        File(zipPath)..parent.createSync(recursive: true),
      );
      uploaded.add(await _uploadOne(
        releaseId: releaseId,
        file: zip,
        arch: 'android_supplement',
        canSideload: false,
      ));
    }

    return uploaded;
  }

  Future<UploadedArtifact> _uploadOne({
    required int releaseId,
    required File file,
    required String arch,
    required bool canSideload,
  }) async {
    final digest = await context.artifacts.digest(file);
    final filename = p.basename(file.path);
    context.logger.info(
      'Uploading $arch ($filename, ${digest.size} bytes)…',
    );
    final response = await context.api.releases.createArtifact(
      context.appId,
      releaseId,
      CreateReleaseArtifactRequestDto(
        arch: arch,
        platform: CreateReleaseArtifactRequestDtoPlatform.android,
        hash: digest.sha256,
        size: digest.size,
        filename: filename,
        canSideload: canSideload,
      ),
    );
    final url = response.url;
    if (url == null || url.isEmpty) {
      throw StateError(
        'Server did not return a signed upload URL for $arch.',
      );
    }
    await context.artifacts.uploadToSignedUrl(file, url);
    return UploadedArtifact(
      arch: arch,
      platform: platform,
      filename: filename,
      size: digest.size,
      hash: digest.sha256,
      canSideload: canSideload,
    );
  }

  /// Stages the obfuscation map (and any future per-platform extras)
  /// into `build/android/dashpod/` so the supplement zip has a clean
  /// known layout. Returns null when there is nothing to ship.
  Future<Directory?> _assembleSupplementDirectory(
    AndroidAppBundleBuild build,
  ) async {
    final map = build.obfuscationMap;
    if (map == null || !map.existsSync()) return null;
    final target = Directory(p.join(
      context.projectRoot.path,
      'build',
      'android',
      'dashpod',
      'supplement',
    ));
    if (target.existsSync()) target.deleteSync(recursive: true);
    target.createSync(recursive: true);
    final dest = File(p.join(target.path, p.basename(map.path)));
    await map.copy(dest.path);
    return target;
  }
}
