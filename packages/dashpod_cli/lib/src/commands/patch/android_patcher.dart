import 'dart:async';
import 'dart:io';

import 'package:dashpod_api/dashpod_api.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../artifact_builder/artifact_builder.dart';
import '../../cache/patch_binary.dart';
import 'patcher.dart';

/// Android patch pipeline.
///
/// Mirrors `private_docs/CLIENT_ARCHITECTURE.MD §3.6.2` (Android):
///   1. `flutter build appbundle` (same flags as the matching release);
///   2. download each arch's release `libapp.so`;
///   3. for each arch: diff the patch snapshot against the release
///      snapshot via the vendored `patch` binary, hash the
///      *uncompressed* patch snapshot, sign that hash if a signer is
///      configured;
///   4. bundle `{arch, path: diff, hash, size, signature}` for upload.
class AndroidPatcher extends Patcher {
  AndroidPatcher(
    super.context, {
    required this.builder,
    required this.patchBinary,
    required this.archs,
    this.obfuscate = false,
    this.buildName,
    this.buildNumber,
    this.extraBuildArgs = const [],
    Dio? downloadClient,
  }) : _download = downloadClient ?? Dio();

  final ArtifactBuilder builder;
  final PatchBinary patchBinary;
  final List<AndroidArch> archs;
  final bool obfuscate;
  final String? buildName;
  final String? buildNumber;
  final List<String> extraBuildArgs;

  final Dio _download;
  AndroidAppBundleBuild? _build;

  @override
  String get platform => 'android';

  @override
  String get primaryReleaseArtifactArch => 'aab';

  @override
  String? get supplementaryReleaseArtifactArch => 'android_supplement';

  @override
  Future<File> buildPatchArtifact({String? releaseVersion}) async {
    final parts = _splitVersionAndCode(releaseVersion);
    final build = await builder.buildAndroidAppBundle(
      projectRoot: context.projectRoot,
      archs: archs,
      flavor: context.flavor,
      buildName: buildName ?? parts.$1,
      buildNumber: buildNumber ?? parts.$2,
      obfuscate: obfuscate,
      extraArgs: extraBuildArgs,
    );
    _build = build;
    return build.aab;
  }

  @override
  Future<String> extractReleaseVersionFromArtifact(File artifact) async {
    final version = await context.artifacts.extractAabVersion(artifact);
    return version.wire;
  }

  @override
  Future<Map<String, PatchArtifactBundle>> createPatchArtifacts({
    required String appId,
    required int releaseId,
    required File patchArtifact,
    File? supplementDirectory,
  }) async {
    final build = _build;
    if (build == null) {
      throw StateError(
        'createPatchArtifacts called before buildPatchArtifact.',
      );
    }

    final bundles = <String, PatchArtifactBundle>{};
    final workDir = Directory(p.join(
      context.projectRoot.path,
      'build',
      'dashpod',
      'patch_android',
    ));
    if (workDir.existsSync()) workDir.deleteSync(recursive: true);
    workDir.createSync(recursive: true);

    for (final entry in build.libapps.entries) {
      final arch = entry.key;
      final patchSnapshot = entry.value;

      final releaseSnapshot = await _downloadReleaseLibapp(
        appId: appId,
        releaseId: releaseId,
        arch: arch.wire,
        cacheDir: workDir,
      );

      final diffOut = File(p.join(workDir.path, '${arch.wire}.diff'));
      await patchBinary.run(
        env: context.env,
        releaseFile: releaseSnapshot,
        patchFile: patchSnapshot,
        outFile: diffOut,
      );

      final snapshotDigest = await context.artifacts.digest(patchSnapshot);
      final diffSize = await diffOut.length();
      final signature = await signHash(snapshotDigest.sha256);

      bundles[arch.wire] = PatchArtifactBundle(
        arch: arch.wire,
        path: diffOut,
        hash: snapshotDigest.sha256,
        size: diffSize,
        hashSignature: signature,
      );
    }

    return bundles;
  }

  @override
  Future<void> uploadPatchArtifacts({
    required String appId,
    required int patchId,
    required Map<String, PatchArtifactBundle> artifacts,
  }) async {
    for (final bundle in artifacts.values) {
      context.logger.info(
        'Uploading ${bundle.arch} patch (${bundle.size} bytes)…',
      );
      final response = await context.api.patches.createArtifact(
        appId,
        patchId,
        CreatePatchArtifactRequestDto(
          arch: bundle.arch,
          platform: CreatePatchArtifactRequestDtoPlatform.android,
          hash: bundle.hash,
          size: bundle.size,
          hashSignature: bundle.hashSignature,
        ),
      );
      final url = response.url;
      if (url == null || url.isEmpty) {
        throw StateError(
          'Server did not return a signed upload URL for ${bundle.arch}.',
        );
      }
      await context.artifacts.uploadToSignedUrl(bundle.path, url);
    }
  }

  Future<File> _downloadReleaseLibapp({
    required String appId,
    required int releaseId,
    required String arch,
    required Directory cacheDir,
  }) async {
    final response = await context.api.releases.listArtifacts(
      appId,
      releaseId,
      arch,
      ListArtifactsParameter3.android,
    );
    final artifacts = response.artifacts ?? const <ReleaseArtifactDto>[];
    final match = artifacts.firstWhere(
      (a) => a.arch == arch,
      orElse: () => throw StateError(
        'Release #$releaseId is missing the $arch libapp.so artifact.',
      ),
    );
    final url = match.url;
    if (url == null || url.isEmpty) {
      throw StateError(
        'Release artifact for $arch did not include a download URL.',
      );
    }
    final dest = File(p.join(cacheDir.path, 'release-$arch-libapp.so'));
    context.logger.detail('Downloading release $arch libapp.so from $url');
    final res = await _download.download(url, dest.path);
    final code = res.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw StateError(
        'Failed to download release $arch libapp.so: HTTP $code.',
      );
    }
    return dest;
  }

  (String?, String?) _splitVersionAndCode(String? raw) {
    if (raw == null) return (null, null);
    final i = raw.indexOf('+');
    if (i < 0) return (raw, null);
    return (raw.substring(0, i), raw.substring(i + 1));
  }
}
