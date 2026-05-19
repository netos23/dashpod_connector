import 'dart:async';

/// Outcome of running a [FlavorDetector] against a project.
class FlavorDetectionResult {
  const FlavorDetectionResult({
    required this.platform,
    required this.flavors,
    this.warning,
  });

  /// Label for the platform/source (`android`, `ios`, `macos`, …).
  final String platform;

  /// Flavor names in the order they were discovered. Empty when the
  /// detector ran but the project declares no flavors.
  final List<String> flavors;

  /// Non-fatal context: parser couldn't read a file, command exited
  /// non-zero, etc. Surfaced to the user but does not block init.
  final String? warning;
}

/// Per-platform flavor discovery.
///
/// Detectors short-circuit (`canRun == false`) when the platform's
/// scaffolding (`android/`, `ios/`, …) is missing — typical for
/// pure-Dart packages.
abstract class FlavorDetector {
  const FlavorDetector();

  String get platform;
  bool canRun();
  Future<FlavorDetectionResult> detect();
}
