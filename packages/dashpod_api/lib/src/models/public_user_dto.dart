import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class PublicUserDto {
  PublicUserDto({this.id, this.email, this.displayName});

  /// Converts a `Map<String, dynamic>` to a [PublicUserDto].
  factory PublicUserDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PublicUserDto',
      json,
      () => PublicUserDto(
        id: (json['id'] as int?),
        email: json['email'] as String?,
        displayName: json['display_name'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PublicUserDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PublicUserDto.fromJson(json);
  }

  final int? id;
  final String? email;
  final String? displayName;

  /// Converts a [PublicUserDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'id': id, 'email': email, 'display_name': displayName};
  }

  @override
  int get hashCode => Object.hashAll([id, email, displayName]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublicUserDto &&
        id == other.id &&
        email == other.email &&
        displayName == other.displayName;
  }
}
