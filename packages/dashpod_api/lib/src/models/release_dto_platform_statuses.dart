enum ReleaseDtoPlatformStatuses {
  draft._('draft'),
  active._('active');

  const ReleaseDtoPlatformStatuses._(this.value);

  /// Creates a ReleaseDtoPlatformStatuses from a json value.
  factory ReleaseDtoPlatformStatuses.fromJson(String json) {
    return ReleaseDtoPlatformStatuses.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException(
        'Unknown ReleaseDtoPlatformStatuses value: $json',
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static ReleaseDtoPlatformStatuses? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return ReleaseDtoPlatformStatuses.fromJson(json);
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
