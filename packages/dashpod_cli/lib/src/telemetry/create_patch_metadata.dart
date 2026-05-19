import 'package:meta/meta.dart';

import 'update_release_metadata.dart';

/// Privacy-safe telemetry blob uploaded alongside each patch as the
/// `metadata` field of the `POST /apps/{}/patches` request.
///
/// See `private_docs/CLIENT_ARCHITECTURE.MD §3.4`. Server treats this
/// as opaque JSON and must tolerate unknown keys. Keep the field set
/// strictly additive across CLI versions.
@immutable
class CreatePatchMetadata {
  const CreatePatchMetadata({
    required this.releasePlatform,
    required this.hasAssetChanges,
    required this.hasNativeChanges,
    required this.inferredReleaseVersion,
    this.linkPercentage,
    this.environment,
    this.cliVersion,
  });

  final String releasePlatform;
  final bool hasAssetChanges;
  final bool hasNativeChanges;

  /// True iff the release version was extracted from the built patch
  /// artifact rather than supplied by the user via `--release-version`.
  final bool inferredReleaseVersion;

  /// iOS-only: linker coverage percentage (0–100). Captured by the
  /// AOT-snapshot link step; null for platforms that don't run a linker.
  final double? linkPercentage;

  final UpdateReleaseMetadataEnvironment? environment;
  final String? cliVersion;

  Map<String, Object?> toJson() {
    final out = <String, Object?>{
      'release_platform': releasePlatform,
      'has_asset_changes': hasAssetChanges,
      'has_native_changes': hasNativeChanges,
      'inferred_release_version': inferredReleaseVersion,
    };
    if (linkPercentage != null) out['link_percentage'] = linkPercentage;
    if (environment != null) out['environment'] = environment!.toJson();
    if (cliVersion != null) out['cli_version'] = cliVersion;
    return out;
  }
}
