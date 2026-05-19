import 'dart:async';
import 'dart:io';

import '../../api/api_client.dart';
import '../../artifact_manager/artifact_manager.dart';
import '../../config/dashpod_yaml.dart';
import '../../env/dashpod_env.dart';
import '../../logger/logger.dart';
import '../../telemetry/update_release_metadata.dart';

/// Outcome of a Releaser run, fed back into the command for the JSON
/// envelope and human-facing summary.
class ReleaseResult {
  ReleaseResult({
    required this.releaseId,
    required this.appId,
    required this.version,
    required this.platform,
    required this.uploadedArtifacts,
  });

  final int releaseId;
  final String appId;
  final ReleaseVersion version;
  final String platform;
  final List<UploadedArtifact> uploadedArtifacts;

  Map<String, Object?> toJson() => {
        'release_id': releaseId,
        'app_id': appId,
        'version': version.wire,
        'platform': platform,
        'artifacts': [for (final a in uploadedArtifacts) a.toJson()],
      };
}

/// Single artifact uploaded as part of a release. The arch/platform
/// pair is part of the wire contract (see `private_docs/CLIENT_ARCHITECTURE.MD §3.5.2`).
class UploadedArtifact {
  UploadedArtifact({
    required this.arch,
    required this.platform,
    required this.filename,
    required this.size,
    required this.hash,
    required this.canSideload,
  });

  final String arch;
  final String platform;
  final String filename;
  final int size;
  final String hash;
  final bool canSideload;

  Map<String, Object?> toJson() => {
        'arch': arch,
        'platform': platform,
        'filename': filename,
        'size': size,
        'hash': hash,
        'can_sideload': canSideload,
      };
}

/// Common context handed to every [Releaser]. Lets the per-platform
/// implementations stay constructor-light.
class ReleaseContext {
  ReleaseContext({
    required this.env,
    required this.logger,
    required this.api,
    required this.artifacts,
    required this.dashpodYaml,
    required this.projectRoot,
    required this.flavor,
    required this.notes,
    required this.displayName,
    required this.flutterRevision,
    required this.flutterVersion,
  });

  final DashpodEnv env;
  final Logger logger;
  final DashpodApiClient api;
  final ArtifactManager artifacts;
  final DashpodYaml dashpodYaml;
  final Directory projectRoot;
  final String? flavor;
  final String? notes;
  final String? displayName;
  final String flutterRevision;
  final String? flutterVersion;

  String get appId => dashpodYaml.idForFlavor(flavor);
}

/// Abstract per-platform release pipeline. Mirrors the contract in
/// `private_docs/CLIENT_ARCHITECTURE.MD §3.5.1` — assert preconditions,
/// build, extract the version from the produced artifact, then upload.
///
/// The CLI [ReleaseCommand] is responsible for the surrounding
/// orchestration (fetch-or-create the `Release` row, PATCH it to
/// `draft`, call [uploadReleaseArtifacts], PATCH to `active`).
abstract class Releaser {
  Releaser(this.context);

  final ReleaseContext context;

  /// Wire-format platform name (`android`, `ios`, …).
  String get platform;

  /// Human-friendly name for the primary release artifact
  /// (e.g. `Android App Bundle`).
  String get artifactDisplayName;

  /// Optional friendly instructions printed after a successful release
  /// (e.g. "now run `dashpod patch android`"). Empty by default.
  String get postReleaseInstructions => '';

  /// Cheap checks: dashpod.yaml exists, host tools available, etc.
  /// Throw to abort with a useful message.
  Future<void> assertPreconditions() async {}

  /// Argument validation that depends on values resolved from the
  /// pubspec (display name, flavor, …). Throw [FormatException] to
  /// surface a usage-style error to the user.
  Future<void> assertArgsAreValid() async {}

  /// Build all release artifacts and return the primary one (the AAB on
  /// Android, the .xcarchive on iOS, …).
  Future<File> buildReleaseArtifacts();

  /// Inspect [primaryArtifact] and return the release version. Each
  /// platform extracts this differently — Android reads the AAB
  /// manifest, iOS parses Info.plist, etc.
  Future<ReleaseVersion> extractReleaseVersion(File primaryArtifact);

  /// Uploads every release artifact. Implementations call
  /// `api.releases.createArtifact` to obtain a signed URL, then PUT the
  /// bytes via [ArtifactManager.uploadToSignedUrl]. Returns the records
  /// the command surfaces in its JSON envelope.
  Future<List<UploadedArtifact>> uploadReleaseArtifacts({
    required int releaseId,
    required File primaryArtifact,
  });

  /// Final telemetry blob `PATCH`ed onto the release when it transitions
  /// from `draft` → `active`.
  Future<UpdateReleaseMetadata> updatedReleaseMetadata(
    UpdateReleaseMetadata base,
  ) async =>
      base;
}
