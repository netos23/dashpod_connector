/// Thrown when the `flutter` key in pubspec.yaml `environment` is a version
/// constraint (e.g. `^3.8.0`) rather than a pinned version (e.g. `3.20.0`).
///
/// Constraints are not supported because the resolver cannot pick a specific
/// SDK version to download from an open range.
final class PubspecVersionConstraintException implements Exception {
  const PubspecVersionConstraintException({
    required this.pubspecPath,
    required this.constraint,
  });

  /// Absolute path to the pubspec.yaml that contained the constraint.
  final String pubspecPath;

  /// The raw constraint string as written in pubspec.yaml.
  final String constraint;

  @override
  String toString() =>
      'PubspecVersionConstraintException: "$constraint" in $pubspecPath '
      'is a version constraint, not a pinned version. '
      'Use an exact version (e.g. flutter: 3.22.0).';
}
