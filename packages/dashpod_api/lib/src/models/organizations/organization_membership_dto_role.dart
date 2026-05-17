enum OrganizationMembershipDtoRole {
  owner._('owner'),
  admin._('admin'),
  appManager._('appManager'),
  developer._('developer'),
  viewer._('viewer'),
  none._('none');

  const OrganizationMembershipDtoRole._(this.value);

  /// Creates a OrganizationMembershipDtoRole from a json value.
  factory OrganizationMembershipDtoRole.fromJson(String json) {
    return OrganizationMembershipDtoRole.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException(
        'Unknown OrganizationMembershipDtoRole value: $json',
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static OrganizationMembershipDtoRole? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return OrganizationMembershipDtoRole.fromJson(json);
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
