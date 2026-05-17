import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class AppDto {
  AppDto({this.id, this.displayName});

  /// Converts a `Map<String, dynamic>` to an [AppDto].
  factory AppDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'AppDto',
      json,
      () => AppDto(
        id: json['id'] as String?,
        displayName: json['displayName'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static AppDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return AppDto.fromJson(json);
  }

  final String? id;
  final String? displayName;

  /// Converts an [AppDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'id': id, 'displayName': displayName};
  }

  @override
  int get hashCode => Object.hashAll([id, displayName]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppDto &&
        id == other.id &&
        displayName == other.displayName;
  }
}
