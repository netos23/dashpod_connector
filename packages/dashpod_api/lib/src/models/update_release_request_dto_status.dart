enum UpdateReleaseRequestDtoStatus {
  draft._('draft'),
  active._('active');

  const UpdateReleaseRequestDtoStatus._(this.value);

  /// Creates a UpdateReleaseRequestDtoStatus from a json value.
  factory UpdateReleaseRequestDtoStatus.fromJson(String json) {
    return UpdateReleaseRequestDtoStatus.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException(
        'Unknown UpdateReleaseRequestDtoStatus value: $json',
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static UpdateReleaseRequestDtoStatus? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return UpdateReleaseRequestDtoStatus.fromJson(json);
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
