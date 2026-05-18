import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class InviteOrgMemberRequestDto {
  InviteOrgMemberRequestDto({this.email});

  /// Converts a `Map<String, dynamic>` to an [InviteOrgMemberRequestDto].
  factory InviteOrgMemberRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'InviteOrgMemberRequestDto',
      json,
      () => InviteOrgMemberRequestDto(email: json['email'] as String?),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static InviteOrgMemberRequestDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return InviteOrgMemberRequestDto.fromJson(json);
  }

  final String? email;

  /// Converts an [InviteOrgMemberRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'email': email};
  }

  @override
  int get hashCode => email.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InviteOrgMemberRequestDto && email == other.email;
  }
}
