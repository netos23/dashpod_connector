import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/organizations/organization_dto_organization_type.dart';
import 'package:meta/meta.dart';

@immutable
class OrganizationDto {
  OrganizationDto({
    this.id,
    this.name,
    this.organizationType,
    this.picture,
    this.website,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  /// Converts a `Map<String, dynamic>` to an [OrganizationDto].
  factory OrganizationDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'OrganizationDto',
      json,
      () => OrganizationDto(
        id: (json['id'] as int?),
        name: json['name'] as String?,
        organizationType: OrganizationDtoOrganizationType.maybeFromJson(
          json['organization_type'] as String?,
        ),
        picture: json['picture'] as String?,
        website: json['website'] as String?,
        description: json['description'] as String?,
        createdAt: maybeParseDateTime(json['created_at'] as String?),
        updatedAt: maybeParseDateTime(json['updated_at'] as String?),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static OrganizationDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return OrganizationDto.fromJson(json);
  }

  final int? id;
  final String? name;
  final OrganizationDtoOrganizationType? organizationType;
  final String? picture;
  final String? website;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Converts an [OrganizationDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'organization_type': organizationType?.toJson(),
      'picture': picture,
      'website': website,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    organizationType,
    picture,
    website,
    description,
    createdAt,
    updatedAt,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrganizationDto &&
        id == other.id &&
        name == other.name &&
        organizationType == other.organizationType &&
        picture == other.picture &&
        website == other.website &&
        description == other.description &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }
}
