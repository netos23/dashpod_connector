enum PatchCheckRequestDtoArch {
  aarch64._('aarch64'),
  arm._('arm'),
  x86._('x86'),
  x8664._('x86_64');

  const PatchCheckRequestDtoArch._(this.value);

  /// Creates a PatchCheckRequestDtoArch from a json value.
  factory PatchCheckRequestDtoArch.fromJson(String json) {
    return PatchCheckRequestDtoArch.values.firstWhere(
      (value) => value.value == json,
      orElse: () => throw FormatException(
        'Unknown PatchCheckRequestDtoArch value: $json',
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static PatchCheckRequestDtoArch? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return PatchCheckRequestDtoArch.fromJson(json);
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
