import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class AppMetadataDto {
  const AppMetadataDto({
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
        appId: json['appId'] as String?,
        displayName: json['displayName'] as String?,
        createdAt: maybeParseDateTime(json['createdAt'] as String?),
        updatedAt: maybeParseDateTime(json['updatedAt'] as String?),
        latestReleaseVersion: json['latestReleaseVersion'] as String?,
        latestPatchNumber: json['latestPatchNumber'] as int?,
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
      'appId': appId,
      'displayName': displayName,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'latestReleaseVersion': latestReleaseVersion,
      'latestPatchNumber': latestPatchNumber,
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
