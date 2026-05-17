import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/patches/create_patch_artifact_request_dto_platform.dart';
import 'package:meta/meta.dart';

@immutable
class CreatePatchArtifactRequestDto {
  CreatePatchArtifactRequestDto({
    this.arch,
    this.platform,
    this.hash,
    this.size,
    this.hashSignature,
    this.podfileLockHash,
  });

  /// Converts a `Map<String, dynamic>` to a [CreatePatchArtifactRequestDto].
  factory CreatePatchArtifactRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreatePatchArtifactRequestDto',
      json,
      () => CreatePatchArtifactRequestDto(
        arch: json['arch'] as String?,
        platform: CreatePatchArtifactRequestDtoPlatform.maybeFromJson(
          json['platform'] as String?,
        ),
        hash: json['hash'] as String?,
        size: (json['size'] as int?),
        hashSignature: json['hashSignature'] as String?,
        podfileLockHash: json['podfileLockHash'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreatePatchArtifactRequestDto? maybeFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return CreatePatchArtifactRequestDto.fromJson(json);
  }

  final String? arch;
  final CreatePatchArtifactRequestDtoPlatform? platform;
  final String? hash;
  final int? size;
  final String? hashSignature;
  final String? podfileLockHash;

  /// Converts a [CreatePatchArtifactRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'arch': arch,
      'platform': platform?.toJson(),
      'hash': hash,
      'size': size,
      'hashSignature': hashSignature,
      'podfileLockHash': podfileLockHash,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    arch,
    platform,
    hash,
    size,
    hashSignature,
    podfileLockHash,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreatePatchArtifactRequestDto &&
        arch == other.arch &&
        platform == other.platform &&
        hash == other.hash &&
        size == other.size &&
        hashSignature == other.hashSignature &&
        podfileLockHash == other.podfileLockHash;
  }
}
