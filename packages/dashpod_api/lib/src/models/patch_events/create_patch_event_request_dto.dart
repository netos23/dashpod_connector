import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/patch_events/patch_event_dto.dart';
import 'package:meta/meta.dart';

@immutable
class CreatePatchEventRequestDto {
  CreatePatchEventRequestDto({this.event});

  /// Converts a `Map<String, dynamic>` to a [CreatePatchEventRequestDto].
  factory CreatePatchEventRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreatePatchEventRequestDto',
      json,
      () => CreatePatchEventRequestDto(
        event: PatchEventDto.maybeFromJson(
          json['event'] as Map<String, dynamic>?,
        ),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreatePatchEventRequestDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CreatePatchEventRequestDto.fromJson(json);
  }

  final PatchEventDto? event;

  /// Converts a [CreatePatchEventRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'event': event?.toJson()};
  }

  @override
  int get hashCode => event.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreatePatchEventRequestDto && event == other.event;
  }
}
