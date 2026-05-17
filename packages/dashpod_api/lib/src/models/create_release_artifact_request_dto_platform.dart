enum CreateReleaseArtifactRequestDtoPlatform {
  android._('android'),
  ios._('ios'),
  linux._('linux'),
  macos._('macos'),
  windows._('windows');

  const CreateReleaseArtifactRequestDtoPlatform._(this.value);

  /// Creates a CreateReleaseArtifactRequestDtoPlatform from a json value.
  factory CreateReleaseArtifactRequestDtoPlatform.fromJson(String json) {
    return CreateReleaseArtifactRequestDtoPlatform.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException(
        'Unknown CreateReleaseArtifactRequestDtoPlatform value: $json',
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static CreateReleaseArtifactRequestDtoPlatform? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return CreateReleaseArtifactRequestDtoPlatform.fromJson(json);
  }

  /// The value of the enum.  This is the exact value
  /// from the OpenAPI spec and will be used for network transport.
  final String value;

  /// Converts the enum to its json value.
  String toJson() => value;

  /// Returns the string form of the enum.
  @override
  String toString() => value;
}
