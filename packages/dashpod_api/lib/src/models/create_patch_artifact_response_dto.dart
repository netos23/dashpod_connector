import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/create_patch_artifact_response_dto_platform.dart';
import 'package:meta/meta.dart';

@immutable
class CreatePatchArtifactResponseDto {
  const CreatePatchArtifactResponseDto({
    this.id,
    this.patchId,
    this.arch,
    this.platform,
    this.hash,
    this.size,
    this.url,
  });

  /// Converts a `Map<String, dynamic>` to a [CreatePatchArtifactResponseDto].
  factory CreatePatchArtifactResponseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreatePatchArtifactResponseDto',
      json,
      () => CreatePatchArtifactResponseDto(
        id: json['id'] as int?,
        patchId: json['patchId'] as int?,
        arch: json['arch'] as String?,
        platform: CreatePatchArtifactResponseDtoPlatform.maybeFromJson(
          json['platform'] as String?,
        ),
        hash: json['hash'] as String?,
        size: json['size'] as int?,
        url: json['url'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreatePatchArtifactResponseDto? maybeFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return CreatePatchArtifactResponseDto.fromJson(json);
  }

  final int? id;
  final int? patchId;
  final String? arch;
  final CreatePatchArtifactResponseDtoPlatform? platform;
  final String? hash;
  final int? size;
  final String? url;

  /// Converts a [CreatePatchArtifactResponseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patchId': patchId,
      'arch': arch,
      'platform': platform?.toJson(),
      'hash': hash,
      'size': size,
      'url': url,
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([id, patchId, arch, platform, hash, size, url]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreatePatchArtifactResponseDto &&
        id == other.id &&
        patchId == other.patchId &&
        arch == other.arch &&
        platform == other.platform &&
        hash == other.hash &&
        size == other.size &&
        url == other.url;
  }
}
