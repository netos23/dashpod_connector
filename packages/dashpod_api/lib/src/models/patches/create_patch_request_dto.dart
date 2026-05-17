import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class CreatePatchRequestDto {
  CreatePatchRequestDto({this.releaseId, this.metadata});

  /// Converts a `Map<String, dynamic>` to a [CreatePatchRequestDto].
  factory CreatePatchRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreatePatchRequestDto',
      json,
      () => CreatePatchRequestDto(
        releaseId: (json['releaseId'] as int?),
        metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value),
        ),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreatePatchRequestDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CreatePatchRequestDto.fromJson(json);
  }

  final int? releaseId;
  final Map<String, dynamic>? metadata;

  /// Converts a [CreatePatchRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'releaseId': releaseId, 'metadata': metadata};
  }

  @override
  int get hashCode => Object.hashAll([releaseId, mapHash(metadata)]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreatePatchRequestDto &&
        releaseId == other.releaseId &&
        mapsEqual(metadata, other.metadata);
  }
}
