import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/releases/update_release_request_dto_platform.dart';
import 'package:dashpod_api/src/models/releases/update_release_request_dto_status.dart';
import 'package:meta/meta.dart';

@immutable
class UpdateReleaseRequestDto {
  UpdateReleaseRequestDto({
    this.status,
    this.platform,
    this.notes,
    this.metadata,
  });

  /// Converts a `Map<String, dynamic>` to a [UpdateReleaseRequestDto].
  factory UpdateReleaseRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'UpdateReleaseRequestDto',
      json,
      () => UpdateReleaseRequestDto(
        status: UpdateReleaseRequestDtoStatus.maybeFromJson(
          json['status'] as String?,
        ),
        platform: UpdateReleaseRequestDtoPlatform.maybeFromJson(
          json['platform'] as String?,
        ),
        notes: json['notes'] as String?,
        metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value),
        ),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static UpdateReleaseRequestDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return UpdateReleaseRequestDto.fromJson(json);
  }

  final UpdateReleaseRequestDtoStatus? status;
  final UpdateReleaseRequestDtoPlatform? platform;
  final String? notes;
  final Map<String, dynamic>? metadata;

  /// Converts a [UpdateReleaseRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'status': status?.toJson(),
      'platform': platform?.toJson(),
      'notes': notes,
      'metadata': metadata,
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([status, platform, notes, mapHash(metadata)]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpdateReleaseRequestDto &&
        status == other.status &&
        platform == other.platform &&
        notes == other.notes &&
        mapsEqual(metadata, other.metadata);
  }
}
