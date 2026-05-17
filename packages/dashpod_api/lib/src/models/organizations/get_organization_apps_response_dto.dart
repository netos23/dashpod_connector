import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/apps/app_metadata_dto.dart';
import 'package:meta/meta.dart';

@immutable
class GetOrganizationAppsResponseDto {
  GetOrganizationAppsResponseDto({this.apps});

  /// Converts a `Map<String, dynamic>` to a [GetOrganizationAppsResponseDto].
  factory GetOrganizationAppsResponseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'GetOrganizationAppsResponseDto',
      json,
      () => GetOrganizationAppsResponseDto(
        apps: (json['apps'] as List?)
            ?.map<AppMetadataDto>(
              (e) => AppMetadataDto.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static GetOrganizationAppsResponseDto? maybeFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return GetOrganizationAppsResponseDto.fromJson(json);
  }

  final List<AppMetadataDto>? apps;

  /// Converts a [GetOrganizationAppsResponseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'apps': apps?.map((e) => e.toJson()).toList()};
  }

  @override
  int get hashCode => listHash(apps).hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GetOrganizationAppsResponseDto &&
        listsEqual(apps, other.apps);
  }
}
