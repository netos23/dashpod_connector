enum CreateReleaseArtifactResponseDtoPlatform {
  android._('android'),
  ios._('ios'),
  linux._('linux'),
  macos._('macos'),
  windows._('windows');

  const CreateReleaseArtifactResponseDtoPlatform._(this.value);

  /// Creates a CreateReleaseArtifactResponseDtoPlatform from a json value.
  factory CreateReleaseArtifactResponseDtoPlatform.fromJson(String json) {
    return CreateReleaseArtifactResponseDtoPlatform.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException(
        'Unknown CreateReleaseArtifactResponseDtoPlatform value: $json',
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static CreateReleaseArtifactResponseDtoPlatform? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return CreateReleaseArtifactResponseDtoPlatform.fromJson(json);
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
