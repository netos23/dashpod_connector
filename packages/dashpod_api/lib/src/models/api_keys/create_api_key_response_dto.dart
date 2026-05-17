import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/api_keys/api_key_dto.dart';
import 'package:meta/meta.dart';

@immutable
class CreateApiKeyResponseDto {
  CreateApiKeyResponseDto({this.key, this.token});

  /// Converts a `Map<String, dynamic>` to a [CreateApiKeyResponseDto].
  factory CreateApiKeyResponseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreateApiKeyResponseDto',
      json,
      () => CreateApiKeyResponseDto(
        key: ApiKeyDto.maybeFromJson(json['key'] as Map<String, dynamic>?),
        token: json['token'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreateApiKeyResponseDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CreateApiKeyResponseDto.fromJson(json);
  }

  final ApiKeyDto? key;
  final String? token;

  /// Converts a [CreateApiKeyResponseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'key': key?.toJson(), 'token': token};
  }

  @override
  int get hashCode => Object.hashAll([key, token]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateApiKeyResponseDto &&
        key == other.key &&
        token == other.token;
  }
}
