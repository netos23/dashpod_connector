import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/organizations/organization_user_dto.dart';
import 'package:meta/meta.dart';

@immutable
class GetOrganizationUsersResponseDto {
  GetOrganizationUsersResponseDto({this.users});

  /// Converts a `Map<String, dynamic>` to a [GetOrganizationUsersResponseDto].
  factory GetOrganizationUsersResponseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'GetOrganizationUsersResponseDto',
      json,
      () => GetOrganizationUsersResponseDto(
        users: (json['users'] as List?)
            ?.map<OrganizationUserDto>(
              (e) => OrganizationUserDto.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static GetOrganizationUsersResponseDto? maybeFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return GetOrganizationUsersResponseDto.fromJson(json);
  }

  final List<OrganizationUserDto>? users;

  /// Converts a [GetOrganizationUsersResponseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'users': users?.map((e) => e.toJson()).toList()};
  }

  @override
  int get hashCode => listHash(users).hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GetOrganizationUsersResponseDto &&
        listsEqual(users, other.users);
  }
}
