import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../config/dashpod_yaml.dart';
import '../../env/dashpod_env.dart';
import '../validator.dart';

/// Verifies that the project's `pubspec.yaml` declares `dashpod.yaml`
/// as a Flutter asset.
///
/// Without that entry, the on-device updater can't read the file at
/// runtime (it's not bundled into the app). This is the most common
/// "I configured the CLI but updates don't work" failure mode, so the
/// validator has an auto-fix that delegates to
/// [DashpodYamlIo.insertAsFlutterAsset].
class DashpodYamlAssetValidator extends Validator {
  DashpodYamlAssetValidator({
    required this.env,
    DashpodYamlIo? yamlIo,
  }) : _yamlIo = yamlIo ?? const DashpodYamlIo();

  final DashpodEnv env;
  final DashpodYamlIo _yamlIo;

  @override
  String get description => 'dashpod.yaml is bundled as a Flutter asset';

  @override
  bool canRunInCurrentContext() {
    final pubspec = env.pubspecFile;
    if (pubspec == null) return false;
    return env.dashpodYamlFile.existsSync();
  }

  @override
  String get incorrectContextMessage =>
      'No pubspec.yaml + dashpod.yaml pair found near '
      '${env.workingDirectory.path}; run `dashpod init` first.';

  @override
  Future<List<ValidationIssue>> validate() async {
    final pubspec = env.pubspecFile!;
    final dashpodYaml = env.dashpodYamlFile;
    final assetName = p.basename(dashpodYaml.path);

    final doc = loadYaml(pubspec.readAsStringSync());
    final flutter = (doc is YamlMap) ? doc['flutter'] : null;
    final assets = (flutter is YamlMap) ? flutter['assets'] : null;
    final present = assets is YamlList &&
        assets.any((e) => e?.toString() == assetName);

    if (present) return const [];

    return [
      ValidationIssue(
        severity: ValidationIssueSeverity.error,
        message: '$assetName is missing from pubspec.yaml flutter.assets',
        displayMessage: 'Add the following to pubspec.yaml so the on-device '
            'updater can read it at runtime:\n'
            '\n'
            '  flutter:\n'
            '    assets:\n'
            '      - $assetName',
        fix: () async {
          _yamlIo.insertAsFlutterAsset(pubspec, assetName);
        },
      ),
    ];
  }
}
