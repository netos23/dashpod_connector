import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/app_collaborators/app_collaborator_dto.dart';
import 'package:meta/meta.dart';

@immutable
class GetAppCollaboratorsResponseDto {
  GetAppCollaboratorsResponseDto({this.collaborators});

  /// Converts a `Map<String, dynamic>` to a [GetAppCollaboratorsResponseDto].
  factory GetAppCollaboratorsResponseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'GetAppCollaboratorsResponseDto',
      json,
      () => GetAppCollaboratorsResponseDto(
        collaborators: (json['collaborators'] as List?)
            ?.map<AppCollaboratorDto>(
              (e) => AppCollaboratorDto.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static GetAppCollaboratorsResponseDto? maybeFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return GetAppCollaboratorsResponseDto.fromJson(json);
  }

  final List<AppCollaboratorDto>? collaborators;

  /// Converts a [GetAppCollaboratorsResponseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'collaborators': collaborators?.map((e) => e.toJson()).toList()};
  }

  @override
  int get hashCode => listHash(collaborators).hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GetAppCollaboratorsResponseDto &&
        listsEqual(collaborators, other.collaborators);
  }
}
