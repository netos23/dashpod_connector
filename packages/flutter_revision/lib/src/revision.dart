import 'package:pub_semver/pub_semver.dart';

/// A function that receives log messages (e.g. `print` or a logger's info
/// method).
typedef LogSink = void Function(String message);

/// The resolved Flutter SDK revision for a package.
///
/// Either [StableRevision] (use the current stable channel) or
/// [PinnedRevision] (use a specific declared version).
sealed class FlutterRevision {
  const FlutterRevision();

  /// The string to pass as a Flutter version argument (e.g. to a download
  /// script or `flutter upgrade` invocation).
  String toVersionArg();

  @override
  String toString() => toVersionArg();
}

/// Use the Flutter stable channel. Returned when no version is pinned in
/// pubspec.yaml or when resolution falls back due to an error.
final class StableRevision extends FlutterRevision {
  const StableRevision();

  @override
  String toVersionArg() => 'stable';
}

/// Use a specific pinned Flutter version declared in pubspec.yaml.
final class PinnedRevision extends FlutterRevision {
  const PinnedRevision(this.version);

  final Version version;

  @override
  String toVersionArg() => version.toString();
}
