import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../env/dashpod_env.dart';
import '../validator.dart';

/// Ensures the host Android app's `AndroidManifest.xml` declares the
/// `android.permission.INTERNET` permission.
///
/// The updater needs network access to call `patches/check`. Without
/// this permission the OTA path silently fails on a deployed app — and
/// "silently" is the worst kind of failure, because the local emulator
/// usually has the permission granted implicitly. So this validator
/// is `error`, not `warning`.
class AndroidInternetPermissionValidator extends Validator {
  AndroidInternetPermissionValidator({required this.env});

  final DashpodEnv env;

  static const _permissionLine =
      '    <uses-permission android:name="android.permission.INTERNET"/>';

  File? get _manifest {
    final pubspec = env.pubspecFile;
    if (pubspec == null) return null;
    final projectDir = Directory(p.dirname(pubspec.path));
    final candidate = File(p.join(
      projectDir.path,
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    ));
    return candidate.existsSync() ? candidate : null;
  }

  @override
  String get description =>
      'Android app declares the INTERNET permission';

  @override
  bool canRunInCurrentContext() => _manifest != null;

  @override
  String get incorrectContextMessage =>
      'No android/app/src/main/AndroidManifest.xml found; '
      'project is not a Flutter Android app.';

  @override
  Future<List<ValidationIssue>> validate() async {
    final manifest = _manifest!;
    final contents = manifest.readAsStringSync();
    final hasPermission = RegExp(
      r'<uses-permission[^>]*android:name\s*=\s*"android\.permission\.INTERNET"',
    ).hasMatch(contents);

    if (hasPermission) return const [];

    return [
      ValidationIssue(
        severity: ValidationIssueSeverity.error,
        message: 'AndroidManifest.xml is missing the INTERNET permission',
        displayMessage: 'Add this inside <manifest> in '
            '${manifest.path}:\n'
            '\n'
            '$_permissionLine',
        fix: () async => _insertPermission(manifest, contents),
      ),
    ];
  }

  void _insertPermission(File manifest, String contents) {
    // Insert as the first child of <manifest>. Matches the format
    // `flutter create` would produce.
    final match = RegExp(r'<manifest\b[^>]*>').firstMatch(contents);
    if (match == null) {
      throw StateError('Could not locate <manifest> tag in ${manifest.path}');
    }
    final updated = contents.replaceRange(
      match.end,
      match.end,
      '\n$_permissionLine',
    );
    manifest.writeAsStringSync(updated);
  }
}
