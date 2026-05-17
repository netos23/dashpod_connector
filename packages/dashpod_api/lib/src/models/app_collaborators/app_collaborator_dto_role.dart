enum AppCollaboratorDtoRole {
  admin._('admin'),
  developer._('developer');

  const AppCollaboratorDtoRole._(this.value);

  /// Creates a AppCollaboratorDtoRole from a json value.
  factory AppCollaboratorDtoRole.fromJson(String json) {
    return AppCollaboratorDtoRole.values.firstWhere(
      (value) => value.value == json,
      orElse: () =>
          throw FormatException('Unknown AppCollaboratorDtoRole value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static AppCollaboratorDtoRole? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return AppCollaboratorDtoRole.fromJson(json);
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
