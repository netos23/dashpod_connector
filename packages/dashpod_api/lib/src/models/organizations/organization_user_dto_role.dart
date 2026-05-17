enum OrganizationUserDtoRole {
  owner._('owner'),
  admin._('admin'),
  appManager._('appManager'),
  developer._('developer'),
  viewer._('viewer'),
  none._('none');

  const OrganizationUserDtoRole._(this.value);

  /// Creates a OrganizationUserDtoRole from a json value.
  factory OrganizationUserDtoRole.fromJson(String json) {
    return OrganizationUserDtoRole.values.firstWhere(
      (value) => value.value == json,
      orElse: () =>
          throw FormatException('Unknown OrganizationUserDtoRole value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static OrganizationUserDtoRole? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return OrganizationUserDtoRole.fromJson(json);
  }

  /// The value of the enum.  This is the exact value
  /// from the OpenAPI spec and will be used for network transport.
  final String value;

  /// Converts the enum to its json value.
  String toJson() => value;

  /// Returns the string form of the enum.
  @override
  String toString() => value.toString();
}
