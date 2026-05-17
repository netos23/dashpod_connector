import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/create_release_artifact_request_dto_platform.dart';
import 'package:meta/meta.dart';

@immutable
class CreateReleaseArtifactRequestDto {
  CreateReleaseArtifactRequestDto({
    this.arch,
    this.platform,
    this.hash,
    this.filename,
    this.size,
    this.canSideload,
    this.podfileLockHash,
  });

  /// Converts a `Map<String, dynamic>` to a [CreateReleaseArtifactRequestDto].
  factory CreateReleaseArtifactRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreateReleaseArtifactRequestDto',
      json,
      () => CreateReleaseArtifactRequestDto(
        arch: json['arch'] as String?,
        platform: CreateReleaseArtifactRequestDtoPlatform.maybeFromJson(
          json['platform'] as String?,
        ),
        hash: json['hash'] as String?,
        filename: json['filename'] as String?,
        size: (json['size'] as int?),
        canSideload: json['canSideload'] as bool?,
        podfileLockHash: json['podfileLockHash'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreateReleaseArtifactRequestDto? maybeFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return CreateReleaseArtifactRequestDto.fromJson(json);
  }

  final String? arch;
  final CreateReleaseArtifactRequestDtoPlatform? platform;
  final String? hash;
  final String? filename;
  final int? size;
  final bool? canSideload;
  final String? podfileLockHash;

  /// Converts a [CreateReleaseArtifactRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'arch': arch,
      'platform': platform?.toJson(),
      'hash': hash,
      'filename': filename,
      'size': size,
      'canSideload': canSideload,
      'podfileLockHash': podfileLockHash,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    arch,
    platform,
    hash,
    filename,
    size,
    canSideload,
    podfileLockHash,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateReleaseArtifactRequestDto &&
        arch == other.arch &&
        platform == other.platform &&
        hash == other.hash &&
        filename == other.filename &&
        size == other.size &&
        canSideload == other.canSideload &&
        podfileLockHash == other.podfileLockHash;
  }
}
