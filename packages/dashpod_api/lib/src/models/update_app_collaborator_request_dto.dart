import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/update_app_collaborator_request_dto_role.dart';
import 'package:meta/meta.dart';

@immutable
class UpdateAppCollaboratorRequestDto {
  UpdateAppCollaboratorRequestDto({this.role});

  /// Converts a `Map<String, dynamic>` to a [UpdateAppCollaboratorRequestDto].
  factory UpdateAppCollaboratorRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'UpdateAppCollaboratorRequestDto',
      json,
      () => UpdateAppCollaboratorRequestDto(
        role: UpdateAppCollaboratorRequestDtoRole.maybeFromJson(
          json['role'] as String?,
        ),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static UpdateAppCollaboratorRequestDto? maybeFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return UpdateAppCollaboratorRequestDto.fromJson(json);
  }

  final UpdateAppCollaboratorRequestDtoRole? role;

  /// Converts a [UpdateAppCollaboratorRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'role': role?.toJson()};
  }

  @override
  int get hashCode => role.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpdateAppCollaboratorRequestDto && role == other.role;
  }
}
