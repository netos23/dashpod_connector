enum UpdateReleaseRequestDtoPlatform {
  android._('android'),
  ios._('ios'),
  linux._('linux'),
  macos._('macos'),
  windows._('windows');

  const UpdateReleaseRequestDtoPlatform._(this.value);

  /// Creates a UpdateReleaseRequestDtoPlatform from a json value.
  factory UpdateReleaseRequestDtoPlatform.fromJson(String json) {
    return UpdateReleaseRequestDtoPlatform.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException(
        'Unknown UpdateReleaseRequestDtoPlatform value: $json',
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static UpdateReleaseRequestDtoPlatform? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return UpdateReleaseRequestDtoPlatform.fromJson(json);
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
