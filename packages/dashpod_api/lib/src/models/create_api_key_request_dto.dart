import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class CreateApiKeyRequestDto {
  const CreateApiKeyRequestDto({this.name, this.expiresAt});

  /// Converts a `Map<String, dynamic>` to a [CreateApiKeyRequestDto].
  factory CreateApiKeyRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreateApiKeyRequestDto',
      json,
      () => CreateApiKeyRequestDto(
        name: json['name'] as String?,
        expiresAt: maybeParseDateTime(json['expiresAt'] as String?),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreateApiKeyRequestDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CreateApiKeyRequestDto.fromJson(json);
  }

  final String? name;
  final DateTime? expiresAt;

  /// Converts a [CreateApiKeyRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'name': name, 'expiresAt': expiresAt?.toIso8601String()};
  }

  @override
  int get hashCode => Object.hashAll([name, expiresAt]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateApiKeyRequestDto &&
        name == other.name &&
        expiresAt == other.expiresAt;
  }
}
