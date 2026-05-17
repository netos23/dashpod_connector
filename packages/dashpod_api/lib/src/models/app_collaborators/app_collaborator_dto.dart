import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/app_collaborators/app_collaborator_dto_role.dart';
import 'package:meta/meta.dart';

@immutable
class AppCollaboratorDto {
  AppCollaboratorDto({this.id, this.email, this.displayName, this.role});

  /// Converts a `Map<String, dynamic>` to an [AppCollaboratorDto].
  factory AppCollaboratorDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'AppCollaboratorDto',
      json,
      () => AppCollaboratorDto(
        id: (json['id'] as int?),
        email: json['email'] as String?,
        displayName: json['displayName'] as String?,
        role: AppCollaboratorDtoRole.maybeFromJson(json['role'] as String?),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static AppCollaboratorDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return AppCollaboratorDto.fromJson(json);
  }

  final int? id;
  final String? email;
  final String? displayName;
  final AppCollaboratorDtoRole? role;

  /// Converts an [AppCollaboratorDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'role': role?.toJson(),
    };
  }

  @override
  int get hashCode => Object.hashAll([id, email, displayName, role]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppCollaboratorDto &&
        id == other.id &&
        email == other.email &&
        displayName == other.displayName &&
        role == other.role;
  }
}
