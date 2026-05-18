import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class AppMetadataDto {
  AppMetadataDto({
    this.appId,
    this.displayName,
    this.createdAt,
    this.updatedAt,
    this.latestReleaseVersion,
    this.latestPatchNumber,
  });

  /// Converts a `Map<String, dynamic>` to an [AppMetadataDto].
  factory AppMetadataDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'AppMetadataDto',
      json,
      () => AppMetadataDto(
        appId: json['app_id'] as String?,
        displayName: json['display_name'] as String?,
        createdAt: maybeParseDateTime(json['created_at'] as String?),
        updatedAt: maybeParseDateTime(json['updated_at'] as String?),
        latestReleaseVersion: json['latest_release_version'] as String?,
        latestPatchNumber: (json['latest_patch_number'] as int?),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static AppMetadataDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return AppMetadataDto.fromJson(json);
  }

  final String? appId;
  final String? displayName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? latestReleaseVersion;
  final int? latestPatchNumber;

  /// Converts an [AppMetadataDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'app_id': appId,
      'display_name': displayName,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'latest_release_version': latestReleaseVersion,
      'latest_patch_number': latestPatchNumber,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    appId,
    displayName,
    createdAt,
    updatedAt,
    latestReleaseVersion,
    latestPatchNumber,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppMetadataDto &&
        appId == other.appId &&
        displayName == other.displayName &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        latestReleaseVersion == other.latestReleaseVersion &&
        latestPatchNumber == other.latestPatchNumber;
  }
}
