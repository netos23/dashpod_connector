import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/release_dto_platform_statuses.dart';
import 'package:meta/meta.dart';

@immutable
class ReleaseDto {
  ReleaseDto({
    this.id,
    this.appId,
    this.version,
    this.flutterRevision,
    this.platformStatuses,
    this.createdAt,
    this.updatedAt,
    this.flutterVersion,
    this.displayName,
    this.notes,
  });

  /// Converts a `Map<String, dynamic>` to a [ReleaseDto].
  factory ReleaseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'ReleaseDto',
      json,
      () => ReleaseDto(
        id: (json['id'] as int?),
        appId: json['appId'] as String?,
        version: json['version'] as String?,
        flutterRevision: json['flutterRevision'] as String?,
        platformStatuses: (json['platformStatuses'] as Map<String, dynamic>?)
            ?.map(
              (key, value) => MapEntry(
                key,
                ReleaseDtoPlatformStatuses.fromJson(value as String),
              ),
            ),
        createdAt: maybeParseDateTime(json['createdAt'] as String?),
        updatedAt: maybeParseDateTime(json['updatedAt'] as String?),
        flutterVersion: json['flutterVersion'] as String?,
        displayName: json['displayName'] as String?,
        notes: json['notes'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static ReleaseDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ReleaseDto.fromJson(json);
  }

  final int? id;
  final String? appId;
  final String? version;
  final String? flutterRevision;
  final Map<String, ReleaseDtoPlatformStatuses>? platformStatuses;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? flutterVersion;
  final String? displayName;
  final String? notes;

  /// Converts a [ReleaseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appId': appId,
      'version': version,
      'flutterRevision': flutterRevision,
      'platformStatuses': platformStatuses?.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'flutterVersion': flutterVersion,
      'displayName': displayName,
      'notes': notes,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    appId,
    version,
    flutterRevision,
    mapHash(platformStatuses),
    createdAt,
    updatedAt,
    flutterVersion,
    displayName,
    notes,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReleaseDto &&
        id == other.id &&
        appId == other.appId &&
        version == other.version &&
        flutterRevision == other.flutterRevision &&
        mapsEqual(platformStatuses, other.platformStatuses) &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        flutterVersion == other.flutterVersion &&
        displayName == other.displayName &&
        notes == other.notes;
  }
}
