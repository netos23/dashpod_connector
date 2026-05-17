import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/releases/create_release_artifact_response_dto_platform.dart';
import 'package:meta/meta.dart';

@immutable
class CreateReleaseArtifactResponseDto {
  CreateReleaseArtifactResponseDto({
    this.id,
    this.releaseId,
    this.arch,
    this.platform,
    this.hash,
    this.size,
    this.url,
  });

  /// Converts a `Map<String, dynamic>` to a [CreateReleaseArtifactResponseDto].
  factory CreateReleaseArtifactResponseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreateReleaseArtifactResponseDto',
      json,
      () => CreateReleaseArtifactResponseDto(
        id: (json['id'] as int?),
        releaseId: (json['releaseId'] as int?),
        arch: json['arch'] as String?,
        platform: CreateReleaseArtifactResponseDtoPlatform.maybeFromJson(
          json['platform'] as String?,
        ),
        hash: json['hash'] as String?,
        size: (json['size'] as int?),
        url: json['url'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreateReleaseArtifactResponseDto? maybeFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return CreateReleaseArtifactResponseDto.fromJson(json);
  }

  final int? id;
  final int? releaseId;
  final String? arch;
  final CreateReleaseArtifactResponseDtoPlatform? platform;
  final String? hash;
  final int? size;
  final String? url;

  /// Converts a [CreateReleaseArtifactResponseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'releaseId': releaseId,
      'arch': arch,
      'platform': platform?.toJson(),
      'hash': hash,
      'size': size,
      'url': url,
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([id, releaseId, arch, platform, hash, size, url]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateReleaseArtifactResponseDto &&
        id == other.id &&
        releaseId == other.releaseId &&
        arch == other.arch &&
        platform == other.platform &&
        hash == other.hash &&
        size == other.size &&
        url == other.url;
  }
}
