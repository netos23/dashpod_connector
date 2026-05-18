import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

/// Reads the Flutter SDK version from FVM configuration files.
///
/// Checks, in order:
/// 1. `.fvmrc` (FVM v3) — `{ "flutter": "<version>" }`
/// 2. `.fvm/fvm_config.json` (FVM v2) — `{ "flutterSdkVersion": "<version>" }`
///
/// Returns `null` if neither file is present, no version key is found, or the
/// value is a channel name (e.g. `"stable"`, `"beta"`) rather than a semver.
/// Throws [FormatException] if a file contains invalid JSON.
final class FvmConfigReader {
  const FvmConfigReader();

  /// Reads the pinned Flutter version for the package at [packagePath].
  Version? read(String packagePath) {
    final fvmrc = File(p.join(packagePath, '.fvmrc'));
    if (fvmrc.existsSync()) {
      final version = _readFvmrc(fvmrc);
      if (version != null) return version;
    }

    final fvmConfig = File(p.join(packagePath, '.fvm', 'fvm_config.json'));
    if (fvmConfig.existsSync()) {
      return _readFvmConfig(fvmConfig);
    }

    return null;
  }

  Version? _readFvmrc(File file) {
    final json =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return _parseVersion(json['flutter'] as String?);
  }

  Version? _readFvmConfig(File file) {
    final json =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return _parseVersion(json['flutterSdkVersion'] as String?);
  }

  Version? _parseVersion(String? value) {
    if (value == null) return null;
    try {
      return Version.parse(value);
    } on FormatException {
      return null;
    }
  }
}