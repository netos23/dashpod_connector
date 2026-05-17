import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class CreatePatchResponseDto {
  CreatePatchResponseDto({this.id, this.number});

  /// Converts a `Map<String, dynamic>` to a [CreatePatchResponseDto].
  factory CreatePatchResponseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreatePatchResponseDto',
      json,
      () => CreatePatchResponseDto(
        id: (json['id'] as int?),
        number: (json['number'] as int?),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreatePatchResponseDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CreatePatchResponseDto.fromJson(json);
  }

  final int? id;
  final int? number;

  /// Converts a [CreatePatchResponseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'id': id, 'number': number};
  }

  @override
  int get hashCode => Object.hashAll([id, number]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreatePatchResponseDto &&
        id == other.id &&
        number == other.number;
  }
}
