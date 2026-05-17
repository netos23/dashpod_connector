import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class ChannelDto {
  const ChannelDto({this.id, this.appId, this.name});

  /// Converts a `Map<String, dynamic>` to a [ChannelDto].
  factory ChannelDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'ChannelDto',
      json,
      () => ChannelDto(
        id: json['id'] as int?,
        appId: json['appId'] as String?,
        name: json['name'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static ChannelDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ChannelDto.fromJson(json);
  }

  final int? id;
  final String? appId;
  final String? name;

  /// Converts a [ChannelDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'id': id, 'appId': appId, 'name': name};
  }

  @override
  int get hashCode => Object.hashAll([id, appId, name]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChannelDto &&
        id == other.id &&
        appId == other.appId &&
        name == other.name;
  }
}
