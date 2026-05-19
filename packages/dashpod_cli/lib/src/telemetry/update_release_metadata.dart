import 'dart:io';

import 'package:meta/meta.dart';

/// Privacy-safe telemetry blob uploaded alongside each release as the
/// `metadata` field of the `PATCH /apps/{}/releases/{}` request.
///
/// See `private_docs/CLIENT_ARCHITECTURE.MD §3.4` for the on-wire shape.
/// The server treats this as opaque JSON and must tolerate unknown keys
/// — keep the field set strictly additive across CLI versions.
@immutable
class UpdateReleaseMetadata {
  const UpdateReleaseMetadata({
    required this.releasePlatform,
    required this.flutterRevision,
    this.flutterVersion,
    this.generatedApks,
    this.environment,
    this.cliVersion,
    this.buildTraceSummary,
  });

  final String releasePlatform;
  final String flutterRevision;
  final String? flutterVersion;

  /// Android-only: true when the release was produced with
  /// `--artifact=apk` rather than the default `.aab`.
  final bool? generatedApks;

  /// Coarse OS bucket (e.g. `macos-arm64`). Populated by
  /// [UpdateReleaseMetadataEnvironment.detect].
  final UpdateReleaseMetadataEnvironment? environment;

  /// `dashpod` CLI version that produced the release.
  final String? cliVersion;

  /// Optional Perfetto-compatible build-trace summary. Reserved for the
  /// `--shorebird-trace` follow-up — currently unused.
  final Map<String, Object?>? buildTraceSummary;

  Map<String, Object?> toJson() {
    final out = <String, Object?>{
      'release_platform': releasePlatform,
      'flutter_revision': flutterRevision,
    };
    if (flutterVersion != null) out['flutter_version'] = flutterVersion;
    if (generatedApks != null) out['generated_apks'] = generatedApks;
    if (environment != null) out['environment'] = environment!.toJson();
    if (cliVersion != null) out['cli_version'] = cliVersion;
    if (buildTraceSummary != null) {
      out['build_trace_summary'] = buildTraceSummary;
    }
    return out;
  }
}

/// Host environment fingerprint embedded into [UpdateReleaseMetadata].
@immutable
class UpdateReleaseMetadataEnvironment {
  const UpdateReleaseMetadataEnvironment({
    required this.operatingSystem,
    required this.operatingSystemVersion,
    required this.locale,
  });

  factory UpdateReleaseMetadataEnvironment.detect() {
    return UpdateReleaseMetadataEnvironment(
      operatingSystem: Platform.operatingSystem,
      operatingSystemVersion: Platform.operatingSystemVersion,
      locale: Platform.localeName,
    );
  }

  final String operatingSystem;
  final String operatingSystemVersion;
  final String locale;

  Map<String, Object?> toJson() => {
        'operating_system': operatingSystem,
        'operating_system_version': operatingSystemVersion,
        'locale': locale,
      };
}
