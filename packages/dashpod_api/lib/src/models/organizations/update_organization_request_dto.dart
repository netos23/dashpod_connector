import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class UpdateOrganizationRequestDto {
  UpdateOrganizationRequestDto({
    this.name,
    this.website,
    this.description,
    this.picture,
  });

  /// Converts a `Map<String, dynamic>` to a [UpdateOrganizationRequestDto].
  factory UpdateOrganizationRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'UpdateOrganizationRequestDto',
      json,
      () => UpdateOrganizationRequestDto(
        name: json['name'] as String?,
        website: json['website'] as String?,
        description: json['description'] as String?,
        picture: json['picture'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static UpdateOrganizationRequestDto? maybeFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return UpdateOrganizationRequestDto.fromJson(json);
  }

  final String? name;
  final String? website;
  final String? description;
  final String? picture;

  /// Converts a [UpdateOrganizationRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'website': website,
      'description': description,
      'picture': picture,
    };
  }

  @override
  int get hashCode => Object.hashAll([name, website, description, picture]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpdateOrganizationRequestDto &&
        name == other.name &&
        website == other.website &&
        description == other.description &&
        picture == other.picture;
  }
}
