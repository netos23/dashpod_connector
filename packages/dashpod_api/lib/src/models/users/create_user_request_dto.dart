import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class CreateUserRequestDto {
  CreateUserRequestDto({this.name, this.organisationName});

  /// Converts a `Map<String, dynamic>` to a [CreateUserRequestDto].
  factory CreateUserRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreateUserRequestDto',
      json,
      () => CreateUserRequestDto(
        name: json['name'] as String?,
        organisationName: json['organisationName'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreateUserRequestDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CreateUserRequestDto.fromJson(json);
  }

  final String? name;
  final String? organisationName;

  /// Converts a [CreateUserRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'name': name, 'organisationName': organisationName};
  }

  @override
  int get hashCode => Object.hashAll([name, organisationName]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateUserRequestDto &&
        name == other.name &&
        organisationName == other.organisationName;
  }
}
