import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/release_artifact_dto.dart';
import 'package:meta/meta.dart';

@immutable
class GetReleaseArtifactsResponseDto {
  GetReleaseArtifactsResponseDto({this.artifacts});

  /// Converts a `Map<String, dynamic>` to a [GetReleaseArtifactsResponseDto].
  factory GetReleaseArtifactsResponseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'GetReleaseArtifactsResponseDto',
      json,
      () => GetReleaseArtifactsResponseDto(
        artifacts: (json['artifacts'] as List?)
            ?.map<ReleaseArtifactDto>(
              (e) => ReleaseArtifactDto.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static GetReleaseArtifactsResponseDto? maybeFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return GetReleaseArtifactsResponseDto.fromJson(json);
  }

  final List<ReleaseArtifactDto>? artifacts;

  /// Converts a [GetReleaseArtifactsResponseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'artifacts': artifacts?.map((e) => e.toJson()).toList()};
  }

  @override
  int get hashCode => listHash(artifacts).hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GetReleaseArtifactsResponseDto &&
        listsEqual(artifacts, other.artifacts);
  }
}
