import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/release_artifact_dto_platform.dart';
import 'package:meta/meta.dart';

@immutable
class ReleaseArtifactDto {
  ReleaseArtifactDto({
    this.id,
    this.releaseId,
    this.arch,
    this.platform,
    this.hash,
    this.size,
    this.url,
    this.canSideload,
    this.podfileLockHash,
  });

  /// Converts a `Map<String, dynamic>` to a [ReleaseArtifactDto].
  factory ReleaseArtifactDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'ReleaseArtifactDto',
      json,
      () => ReleaseArtifactDto(
        id: (json['id'] as int?),
        releaseId: (json['releaseId'] as int?),
        arch: json['arch'] as String?,
        platform: ReleaseArtifactDtoPlatform.maybeFromJson(
          json['platform'] as String?,
        ),
        hash: json['hash'] as String?,
        size: (json['size'] as int?),
        url: json['url'] as String?,
        canSideload: json['canSideload'] as bool?,
        podfileLockHash: json['podfileLockHash'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static ReleaseArtifactDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ReleaseArtifactDto.fromJson(json);
  }

  final int? id;
  final int? releaseId;
  final String? arch;
  final ReleaseArtifactDtoPlatform? platform;
  final String? hash;
  final int? size;
  final String? url;
  final bool? canSideload;
  final String? podfileLockHash;

  /// Converts a [ReleaseArtifactDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'releaseId': releaseId,
      'arch': arch,
      'platform': platform?.toJson(),
      'hash': hash,
      'size': size,
      'url': url,
      'canSideload': canSideload,
      'podfileLockHash': podfileLockHash,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    releaseId,
    arch,
    platform,
    hash,
    size,
    url,
    canSideload,
    podfileLockHash,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReleaseArtifactDto &&
        id == other.id &&
        releaseId == other.releaseId &&
        arch == other.arch &&
        platform == other.platform &&
        hash == other.hash &&
        size == other.size &&
        url == other.url &&
        canSideload == other.canSideload &&
        podfileLockHash == other.podfileLockHash;
  }
}
