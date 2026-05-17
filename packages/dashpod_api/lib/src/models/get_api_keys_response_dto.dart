import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/api_key_dto.dart';
import 'package:meta/meta.dart';

@immutable
class GetApiKeysResponseDto {
  GetApiKeysResponseDto({this.apiKeys});

  /// Converts a `Map<String, dynamic>` to a [GetApiKeysResponseDto].
  factory GetApiKeysResponseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'GetApiKeysResponseDto',
      json,
      () => GetApiKeysResponseDto(
        apiKeys: (json['apiKeys'] as List?)
            ?.map<ApiKeyDto>(
              (e) => ApiKeyDto.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static GetApiKeysResponseDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return GetApiKeysResponseDto.fromJson(json);
  }

  final List<ApiKeyDto>? apiKeys;

  /// Converts a [GetApiKeysResponseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'apiKeys': apiKeys?.map((e) => e.toJson()).toList()};
  }

  @override
  int get hashCode => listHash(apiKeys).hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GetApiKeysResponseDto && listsEqual(apiKeys, other.apiKeys);
  }
}
