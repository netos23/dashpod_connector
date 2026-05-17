import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/release_dto.dart';
import 'package:meta/meta.dart';

@immutable
class GetReleasesResponseDto {
  GetReleasesResponseDto({this.releases});

  /// Converts a `Map<String, dynamic>` to a [GetReleasesResponseDto].
  factory GetReleasesResponseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'GetReleasesResponseDto',
      json,
      () => GetReleasesResponseDto(
        releases: (json['releases'] as List?)
            ?.map<ReleaseDto>(
              (e) => ReleaseDto.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static GetReleasesResponseDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return GetReleasesResponseDto.fromJson(json);
  }

  final List<ReleaseDto>? releases;

  /// Converts a [GetReleasesResponseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'releases': releases?.map((e) => e.toJson()).toList()};
  }

  @override
  int get hashCode => listHash(releases).hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GetReleasesResponseDto &&
        listsEqual(releases, other.releases);
  }
}
