import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';

import '../../api/api_client.dart';
import '../../artifact_manager/artifact_manager.dart';
import '../../code_signer/code_signer.dart';
import '../../config/dashpod_yaml.dart';
import '../../env/dashpod_env.dart';
import '../../logger/logger.dart';
import '../../patch_diff_checker/patch_diff_checker.dart';
import '../../telemetry/create_patch_metadata.dart';

/// Wire-shape bundle for a single architecture's patch artifact.
///
/// Mirrors `private_docs/CLIENT_ARCHITECTURE.MD §3.6.1` —
/// crucially, `hash` is the SHA-256 of the *uncompressed* AOT snapshot
/// bytes, NOT the bsdiff-encoded delta. The on-device updater rehashes
/// the decompressed result of applying the diff and compares against
/// this value.
@immutable
class PatchArtifactBundle {
  const PatchArtifactBundle({
    required this.arch,
    required this.path,
    required this.hash,
    required this.size,
    this.hashSignature,
    this.podfileLockHash,
  });

  /// Wire arch string (`aarch64`, `arm`, `x86_64`, …).
  final String arch;

  /// On-disk path of the diff payload that will be uploaded.
  final File path;

  /// SHA-256 (hex) of the *uncompressed* snapshot bytes.
  final String hash;

  /// Size of the *diff payload* (i.e. on-disk size of [path]).
  final int size;

  /// Base64 RSA-PKCS1-SHA256 signature over the hex string of [hash].
  /// Null when no signer is configured (verification disabled).
  final String? hashSignature;

  /// iOS/macOS-only: SHA-256 of `Podfile.lock`. Ignored on Android.
  final String? podfileLockHash;
}

/// Per-platform shared context handed to every [Patcher].
class PatchContext {
  PatchContext({
    required this.env,
    required this.logger,
    required this.api,
    required this.artifacts,
    required this.dashpodYaml,
    required this.projectRoot,
    required this.flavor,
    required this.releaseVersionOverride,
    required this.allowAssetChanges,
    required this.allowNativeChanges,
    required this.track,
    this.signer,
    this.diffChecker,
  });

  final DashpodEnv env;
  final Logger logger;
  final DashpodApiClient api;
  final ArtifactManager artifacts;
  final DashpodYaml dashpodYaml;
  final Directory projectRoot;
  final String? flavor;
  final String? releaseVersionOverride;
  final bool allowAssetChanges;
  final bool allowNativeChanges;
  final String track;
  final CodeSigner? signer;
  final PatchDiffChecker? diffChecker;

  String get appId => dashpodYaml.idForFlavor(flavor);
}

/// Abstract per-platform patch pipeline. Mirrors §3.6.1 in the
/// reference architecture doc. Per-platform subclasses implement
/// build/extract/diff/upload; the [PatchCommand] is responsible for
/// the surrounding orchestration (channel creation, telemetry,
/// progress reporting).
abstract class Patcher {
  Patcher(this.context);

  final PatchContext context;

  /// Wire-format platform name (`android`, `ios`, …).
  String get platform;

  /// `arch` value of the primary release artifact (`aab`, `xcarchive`,
  /// `app`, `bundle`, `exe`). Used by [PatchCommand] to download the
  /// release archive for diffing.
  String get primaryReleaseArtifactArch;

  /// `arch` value of the supplement release artifact, if any
  /// (`android_supplement`, `ios_supplement`, `macos_supplement`).
  String? get supplementaryReleaseArtifactArch;

  /// iOS-specific link coverage. Null on every other platform.
  double? get linkPercentage => null;

  /// Cheap host-side preconditions (`patch` binary in cache,
  /// `flutter` on PATH, …).
  Future<void> assertPreconditions() async {}

  /// Builds the patch artifact (Android: a fresh patch AAB). May be
  /// called *before* the release version is known — see §3.6.1's
  /// "no `--release-version`" interactive path.
  Future<File> buildPatchArtifact({String? releaseVersion});

  /// Extracts the release version from the *patch* artifact when the
  /// user did not pass `--release-version`. Each platform reads this
  /// differently; the shared [ArtifactManager] handles AAB.
  Future<String> extractReleaseVersionFromArtifact(File artifact);

  /// Computes per-arch patch bundles ready for upload.
  Future<Map<String, PatchArtifactBundle>> createPatchArtifacts({
    required String appId,
    required int releaseId,
    required File patchArtifact,
    File? supplementDirectory,
  });

  /// Uploads each entry of [artifacts] via the two-phase
  /// `createArtifact` flow.
  Future<void> uploadPatchArtifacts({
    required String appId,
    required int patchId,
    required Map<String, PatchArtifactBundle> artifacts,
  });

  /// Last hook before the patch is published; gives the patcher a
  /// chance to attach platform-specific fields to the telemetry blob.
  Future<CreatePatchMetadata> updatedCreatePatchMetadata(
    CreatePatchMetadata base,
  ) async =>
      base;

  /// Convenience used by Android / Linux. iOS overrides with the
  /// linker-aware variant.
  Future<String?> signHash(String hex) async {
    final signer = context.signer;
    if (signer == null) return null;
    return signer.sign(hex);
  }
}
