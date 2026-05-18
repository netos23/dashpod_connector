import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import 'errors.dart';

/// Reads the `flutter` key from a pubspec.yaml `environment` section and
/// returns it as a [Version], or `null` if the key is absent.
///
/// Throws [PubspecVersionConstraintException] when the value is a constraint
/// (e.g. `^3.8.0`) rather than a pinned version.
/// Throws [Exception] when the pubspec.yaml is missing or malformed.
final class PubspecFlutterVersionReader {
  const PubspecFlutterVersionReader();

  /// Reads the pinned Flutter version from the pubspec.yaml in [packagePath].
  Version? read(String packagePath) {
    final pubspecFile = File(p.join(packagePath, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      throw Exception('pubspec.yaml not found at ${pubspecFile.path}');
    }

    final parsed = loadYaml(pubspecFile.readAsStringSync());
    if (parsed is! YamlMap) {
      throw Exception('Failed to parse pubspec.yaml at ${pubspecFile.path}');
    }

    final environment = parsed['environment'] as YamlMap?;
    final flutterEntry = environment?['flutter'] as String?;
    if (flutterEntry == null) return null;

    final constraint = VersionConstraint.parse(flutterEntry);
    if (constraint is Version) return constraint;

    // Parsed successfully but it is a range, not a pinned version.
    throw PubspecVersionConstraintException(
      pubspecPath: pubspecFile.path,
      constraint: flutterEntry,
    );
  }
}
