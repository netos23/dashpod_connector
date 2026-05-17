import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class CreateAppCollaboratorRequestDto {
  const CreateAppCollaboratorRequestDto({this.email});

  /// Converts a `Map<String, dynamic>` to a [CreateAppCollaboratorRequestDto].
  factory CreateAppCollaboratorRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreateAppCollaboratorRequestDto',
      json,
      () => CreateAppCollaboratorRequestDto(email: json['email'] as String?),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreateAppCollaboratorRequestDto? maybeFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return CreateAppCollaboratorRequestDto.fromJson(json);
  }

  final String? email;

  /// Converts a [CreateAppCollaboratorRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'email': email};
  }

  @override
  int get hashCode => email.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateAppCollaboratorRequestDto && email == other.email;
  }
}
