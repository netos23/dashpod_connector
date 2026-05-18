import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class CreateReleaseRequestDto {
  CreateReleaseRequestDto({
    this.version,
    this.flutterRevision,
    this.flutterVersion,
    this.displayName,
  });

  /// Converts a `Map<String, dynamic>` to a [CreateReleaseRequestDto].
  factory CreateReleaseRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CreateReleaseRequestDto',
      json,
      () => CreateReleaseRequestDto(
        version: json['version'] as String?,
        flutterRevision: json['flutter_revision'] as String?,
        flutterVersion: json['flutter_version'] as String?,
        displayName: json['display_name'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CreateReleaseRequestDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CreateReleaseRequestDto.fromJson(json);
  }

  final String? version;
  final String? flutterRevision;
  final String? flutterVersion;
  final String? displayName;

  /// Converts a [CreateReleaseRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'flutter_revision': flutterRevision,
      'flutter_version': flutterVersion,
      'display_name': displayName,
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([version, flutterRevision, flutterVersion, displayName]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateReleaseRequestDto &&
        version == other.version &&
        flutterRevision == other.flutterRevision &&
        flutterVersion == other.flutterVersion &&
        displayName == other.displayName;
  }
}
