import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class ApiKeyDto {
  ApiKeyDto({
    this.id,
    this.name,
    this.prefix,
    this.createdAt,
    this.lastUsedAt,
    this.expiresAt,
    this.revokedAt,
  });

  /// Converts a `Map<String, dynamic>` to an [ApiKeyDto].
  factory ApiKeyDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'ApiKeyDto',
      json,
      () => ApiKeyDto(
        id: (json['id'] as int?),
        name: json['name'] as String?,
        prefix: json['prefix'] as String?,
        createdAt: maybeParseDateTime(json['createdAt'] as String?),
        lastUsedAt: maybeParseDateTime(json['lastUsedAt'] as String?),
        expiresAt: maybeParseDateTime(json['expiresAt'] as String?),
        revokedAt: maybeParseDateTime(json['revokedAt'] as String?),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static ApiKeyDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ApiKeyDto.fromJson(json);
  }

  final int? id;
  final String? name;
  final String? prefix;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;

  /// Converts an [ApiKeyDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'prefix': prefix,
      'createdAt': createdAt?.toIso8601String(),
      'lastUsedAt': lastUsedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'revokedAt': revokedAt?.toIso8601String(),
    };
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    prefix,
    createdAt,
    lastUsedAt,
    expiresAt,
    revokedAt,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiKeyDto &&
        id == other.id &&
        name == other.name &&
        prefix == other.prefix &&
        createdAt == other.createdAt &&
        lastUsedAt == other.lastUsedAt &&
        expiresAt == other.expiresAt &&
        revokedAt == other.revokedAt;
  }
}
