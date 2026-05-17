import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class UpdatePatchRequestDto {
  const UpdatePatchRequestDto({this.notes});

  /// Converts a `Map<String, dynamic>` to a [UpdatePatchRequestDto].
  factory UpdatePatchRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'UpdatePatchRequestDto',
      json,
      () => UpdatePatchRequestDto(notes: json['notes'] as String?),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static UpdatePatchRequestDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return UpdatePatchRequestDto.fromJson(json);
  }

  final String? notes;

  /// Converts a [UpdatePatchRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'notes': notes};
  }

  @override
  int get hashCode => notes.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpdatePatchRequestDto && notes == other.notes;
  }
}
