import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class CreateAppRequestDto {
  const CreateAppRequestDto({this.displayName, this.organizationId});

  /// Converts a `Map<String, dynamic>` to a [CreateAppRequestDto].
  factory CreateAppRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreateAppRequestDto',
      json,
      () => CreateAppRequestDto(
        displayName: json['displayName'] as String?,
        organizationId: json['organizationId'] as int?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreateAppRequestDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CreateAppRequestDto.fromJson(json);
  }

  final String? displayName;
  final int? organizationId;

  /// Converts a [CreateAppRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'displayName': displayName, 'organizationId': organizationId};
  }

  @override
  int get hashCode => Object.hashAll([displayName, organizationId]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateAppRequestDto &&
        displayName == other.displayName &&
        organizationId == other.organizationId;
  }
}
