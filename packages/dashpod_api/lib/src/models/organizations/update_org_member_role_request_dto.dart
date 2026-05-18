import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/organizations/update_org_member_role_request_dto_role.dart';
import 'package:meta/meta.dart';

@immutable
class UpdateOrgMemberRoleRequestDto {
  UpdateOrgMemberRoleRequestDto({this.role});

  /// Converts a `Map<String, dynamic>` to a [UpdateOrgMemberRoleRequestDto].
  factory UpdateOrgMemberRoleRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'UpdateOrgMemberRoleRequestDto',
      json,
      () => UpdateOrgMemberRoleRequestDto(
        role: UpdateOrgMemberRoleRequestDtoRole.maybeFromJson(
          json['role'] as String?,
        ),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static UpdateOrgMemberRoleRequestDto? maybeFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return UpdateOrgMemberRoleRequestDto.fromJson(json);
  }

  final UpdateOrgMemberRoleRequestDtoRole? role;

  /// Converts a [UpdateOrgMemberRoleRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'role': role?.toJson()};
  }

  @override
  int get hashCode => role.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpdateOrgMemberRoleRequestDto && role == other.role;
  }
}
