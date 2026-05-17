import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/organizations/organization_dto.dart';
import 'package:dashpod_api/src/models/organizations/organization_membership_dto_role.dart';
import 'package:meta/meta.dart';

@immutable
class OrganizationMembershipDto {
  OrganizationMembershipDto({this.organization, this.role});

  /// Converts a `Map<String, dynamic>` to an [OrganizationMembershipDto].
  factory OrganizationMembershipDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'OrganizationMembershipDto',
      json,
      () => OrganizationMembershipDto(
        organization: OrganizationDto.maybeFromJson(
          json['organization'] as Map<String, dynamic>?,
        ),
        role: OrganizationMembershipDtoRole.maybeFromJson(
          json['role'] as String?,
        ),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static OrganizationMembershipDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return OrganizationMembershipDto.fromJson(json);
  }

  final OrganizationDto? organization;
  final OrganizationMembershipDtoRole? role;

  /// Converts an [OrganizationMembershipDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'organization': organization?.toJson(), 'role': role?.toJson()};
  }

  @override
  int get hashCode => Object.hashAll([organization, role]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrganizationMembershipDto &&
        organization == other.organization &&
        role == other.role;
  }
}
