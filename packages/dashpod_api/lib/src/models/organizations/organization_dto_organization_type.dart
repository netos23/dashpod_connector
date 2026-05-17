enum OrganizationDtoOrganizationType {
  personal._('personal'),
  team._('team');

  const OrganizationDtoOrganizationType._(this.value);

  /// Creates a OrganizationDtoOrganizationType from a json value.
  factory OrganizationDtoOrganizationType.fromJson(String json) {
    return OrganizationDtoOrganizationType.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException(
        'Unknown OrganizationDtoOrganizationType value: $json',
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static OrganizationDtoOrganizationType? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return OrganizationDtoOrganizationType.fromJson(json);
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
