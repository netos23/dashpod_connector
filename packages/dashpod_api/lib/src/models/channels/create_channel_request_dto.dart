import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class CreateChannelRequestDto {
  CreateChannelRequestDto({this.channel});

  /// Converts a `Map<String, dynamic>` to a [CreateChannelRequestDto].
  factory CreateChannelRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreateChannelRequestDto',
      json,
      () => CreateChannelRequestDto(channel: json['channel'] as String?),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreateChannelRequestDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CreateChannelRequestDto.fromJson(json);
  }

  final String? channel;

  /// Converts a [CreateChannelRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'channel': channel};
  }

  @override
  int get hashCode => channel.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateChannelRequestDto && channel == other.channel;
  }
}
