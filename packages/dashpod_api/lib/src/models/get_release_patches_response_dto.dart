import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/release_patch_dto.dart';
import 'package:meta/meta.dart';

@immutable
class GetReleasePatchesResponseDto {
  GetReleasePatchesResponseDto({this.patches});

  /// Converts a `Map<String, dynamic>` to a [GetReleasePatchesResponseDto].
  factory GetReleasePatchesResponseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'GetReleasePatchesResponseDto',
      json,
      () => GetReleasePatchesResponseDto(
        patches: (json['patches'] as List?)
            ?.map<ReleasePatchDto>(
              (e) => ReleasePatchDto.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static GetReleasePatchesResponseDto? maybeFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return GetReleasePatchesResponseDto.fromJson(json);
  }

  final List<ReleasePatchDto>? patches;

  /// Converts a [GetReleasePatchesResponseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'patches': patches?.map((e) => e.toJson()).toList()};
  }

  @override
  int get hashCode => listHash(patches).hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GetReleasePatchesResponseDto &&
        listsEqual(patches, other.patches);
  }
}
