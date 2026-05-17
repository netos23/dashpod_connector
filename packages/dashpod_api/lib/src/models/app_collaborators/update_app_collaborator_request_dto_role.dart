enum UpdateAppCollaboratorRequestDtoRole {
  admin._('admin'),
  developer._('developer');

  const UpdateAppCollaboratorRequestDtoRole._(this.value);

  /// Creates a UpdateAppCollaboratorRequestDtoRole from a json value.
  factory UpdateAppCollaboratorRequestDtoRole.fromJson(String json) {
    return UpdateAppCollaboratorRequestDtoRole.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException(
        'Unknown UpdateAppCollaboratorRequestDtoRole value: $json',
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static UpdateAppCollaboratorRequestDtoRole? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return UpdateAppCollaboratorRequestDtoRole.fromJson(json);
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
