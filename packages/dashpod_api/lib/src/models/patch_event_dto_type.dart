enum PatchEventDtoType {
  patchInstall._('__patch_install__'),
  patchInstallFailure._('__patch_install_failure__'),
  patchDownload._('__patch_download__'),
  patchUpdateFailure._('__patch_update_failure__');

  const PatchEventDtoType._(this.value);

  /// Creates a PatchEventDtoType from a json value.
  factory PatchEventDtoType.fromJson(String json) {
    return PatchEventDtoType.values.firstWhere(
      (value) => value.value == json,
      orElse: () =>
          throw FormatException('Unknown PatchEventDtoType value: $json'),
    );
  }

  /// Convenience to create a nullable type from a nullable json value.
  /// Useful when parsing optional fields.
  static PatchEventDtoType? maybeFromJson(String? json) {
    if (json == null) {
      return null;
    }
    return PatchEventDtoType.fromJson(json);
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
