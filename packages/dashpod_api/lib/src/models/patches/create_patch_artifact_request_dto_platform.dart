enum CreatePatchArtifactRequestDtoPlatform {
  android._('android'),
  ios._('ios'),
  linux._('linux'),
  macos._('macos'),
  windows._('windows');

  const CreatePatchArtifactRequestDtoPlatform._(this.value);

  /// Creates a CreatePatchArtifactRequestDtoPlatform from a json value.
  factory CreatePatchArtifactRequestDtoPlatform.fromJson(String json) {
    return CreatePatchArtifactRequestDtoPlatform.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException(
        'Unknown CreatePatchArtifactRequestDtoPlatform value: $json',
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static CreatePatchArtifactRequestDtoPlatform? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return CreatePatchArtifactRequestDtoPlatform.fromJson(json);
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
