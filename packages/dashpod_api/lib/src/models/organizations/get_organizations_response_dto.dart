import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/organizations/organization_membership_dto.dart';
import 'package:meta/meta.dart';

@immutable
class GetOrganizationsResponseDto {
  GetOrganizationsResponseDto({this.organizations});

  /// Converts a `Map<String, dynamic>` to a [GetOrganizationsResponseDto].
  factory GetOrganizationsResponseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'GetOrganizationsResponseDto',
      json,
      () => GetOrganizationsResponseDto(
        organizations: (json['organizations'] as List?)
            ?.map<OrganizationMembershipDto>(
              (e) =>
                  OrganizationMembershipDto.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static GetOrganizationsResponseDto? maybeFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return GetOrganizationsResponseDto.fromJson(json);
  }

  final List<OrganizationMembershipDto>? organizations;

  /// Converts a [GetOrganizationsResponseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'organizations': organizations?.map((e) => e.toJson()).toList()};
  }

  @override
  int get hashCode => listHash(organizations).hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GetOrganizationsResponseDto &&
        listsEqual(organizations, other.organizations);
  }
}
