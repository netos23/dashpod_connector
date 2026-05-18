enum UpdateOrgMemberRoleRequestDtoRole {
  owner._('owner'),
  admin._('admin'),
  appManager._('appManager'),
  developer._('developer'),
  viewer._('viewer'),
  none._('none');

  const UpdateOrgMemberRoleRequestDtoRole._(this.value);

  /// Creates a UpdateOrgMemberRoleRequestDtoRole from a json value.
  factory UpdateOrgMemberRoleRequestDtoRole.fromJson(String json) {
    return UpdateOrgMemberRoleRequestDtoRole.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException(
        'Unknown UpdateOrgMemberRoleRequestDtoRole value: $json',
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static UpdateOrgMemberRoleRequestDtoRole? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return UpdateOrgMemberRoleRequestDtoRole.fromJson(json);
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
