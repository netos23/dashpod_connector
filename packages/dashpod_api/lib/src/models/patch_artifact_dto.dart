import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/patch_artifact_dto_platform.dart';
import 'package:meta/meta.dart';

@immutable
class PatchArtifactDto {
  PatchArtifactDto({
    this.id,
    this.patchId,
    this.arch,
    this.platform,
    this.hash,
    this.size,
    this.createdAt,
  });

  /// Converts a `Map<String, dynamic>` to a [PatchArtifactDto].
  factory PatchArtifactDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PatchArtifactDto',
      json,
      () => PatchArtifactDto(
        id: (json['id'] as int?),
        patchId: (json['patchId'] as int?),
        arch: json['arch'] as String?,
        platform: PatchArtifactDtoPlatform.maybeFromJson(
          json['platform'] as String?,
        ),
        hash: json['hash'] as String?,
        size: (json['size'] as int?),
        createdAt: maybeParseDateTime(json['createdAt'] as String?),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PatchArtifactDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PatchArtifactDto.fromJson(json);
  }

  final int? id;
  final int? patchId;
  final String? arch;
  final PatchArtifactDtoPlatform? platform;
  final String? hash;
  final int? size;
  final DateTime? createdAt;

  /// Converts a [PatchArtifactDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patchId': patchId,
      'arch': arch,
      'platform': platform?.toJson(),
      'hash': hash,
      'size': size,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([id, patchId, arch, platform, hash, size, createdAt]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PatchArtifactDto &&
        id == other.id &&
        patchId == other.patchId &&
        arch == other.arch &&
        platform == other.platform &&
        hash == other.hash &&
        size == other.size &&
        createdAt == other.createdAt;
  }
}
