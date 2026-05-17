enum ListArtifactsParameter3 {
  android._('android'),
  ios._('ios'),
  linux._('linux'),
  macos._('macos'),
  windows._('windows');

  const ListArtifactsParameter3._(this.value);

  /// Creates a ListArtifactsParameter3 from a json value.
  factory ListArtifactsParameter3.fromJson(String json) {
    return ListArtifactsParameter3.values.firstWhere(
      (value) => value.value == json,
      orElse: () =>
          throw FormatException('Unknown ListArtifactsParameter3 value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static ListArtifactsParameter3? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return ListArtifactsParameter3.fromJson(json);
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
