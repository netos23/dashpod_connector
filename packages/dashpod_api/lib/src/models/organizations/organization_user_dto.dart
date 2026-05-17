import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/organizations/organization_user_dto_role.dart';
import 'package:dashpod_api/src/models/public_user_dto.dart';
import 'package:meta/meta.dart';

@immutable
class OrganizationUserDto {
  OrganizationUserDto({this.user, this.role});

  /// Converts a `Map<String, dynamic>` to an [OrganizationUserDto].
  factory OrganizationUserDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'OrganizationUserDto',
      json,
      () => OrganizationUserDto(
        user: PublicUserDto.maybeFromJson(
          json['user'] as Map<String, dynamic>?,
        ),
        role: OrganizationUserDtoRole.maybeFromJson(json['role'] as String?),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static OrganizationUserDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return OrganizationUserDto.fromJson(json);
  }

  final PublicUserDto? user;
  final OrganizationUserDtoRole? role;

  /// Converts an [OrganizationUserDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'user': user?.toJson(), 'role': role?.toJson()};
  }

  @override
  int get hashCode => Object.hashAll([user, role]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrganizationUserDto &&
        user == other.user &&
        role == other.role;
  }
}
