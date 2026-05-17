import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/release_dto.dart';
import 'package:meta/meta.dart';

@immutable
class CreateReleaseResponseDto {
  CreateReleaseResponseDto({this.release});

  /// Converts a `Map<String, dynamic>` to a [CreateReleaseResponseDto].
  factory CreateReleaseResponseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreateReleaseResponseDto',
      json,
      () => CreateReleaseResponseDto(
        release: ReleaseDto.maybeFromJson(
          json['release'] as Map<String, dynamic>?,
        ),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreateReleaseResponseDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CreateReleaseResponseDto.fromJson(json);
  }

  final ReleaseDto? release;

  /// Converts a [CreateReleaseResponseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'release': release?.toJson()};
  }

  @override
  int get hashCode => release.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateReleaseResponseDto && release == other.release;
  }
}
