import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../process/dashpod_process.dart';
import 'flavor_detector.dart';

/// Detects Android product flavors by interrogating Gradle.
///
/// Strategy: run `./gradlew :app:tasks --all -q` and look at the
/// `Build tasks` group for entries of the form `assemble<Flavor>Release`.
/// Each leading-uppercase token is a flavor.
///
/// This avoids parsing build.gradle (KTS or Groovy) which has too many
/// dialects in the wild. Gradle is the source of truth.
class AndroidFlavorDetector extends FlavorDetector {
  AndroidFlavorDetector({
    required this.projectRoot,
    required this.process,
  });

  /// Flutter project root (the directory containing `pubspec.yaml`).
  final Directory projectRoot;
  final DashpodProcess process;

  Directory get _androidDir => Directory(p.join(projectRoot.path, 'android'));

  File get _gradlew {
    final name = Platform.isWindows ? 'gradlew.bat' : 'gradlew';
    return File(p.join(_androidDir.path, name));
  }

  @override
  String get platform => 'android';

  @override
  bool canRun() => _androidDir.existsSync() && _gradlew.existsSync();

  @override
  Future<FlavorDetectionResult> detect() async {
    final gradlew = _gradlew.path;
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['+x', gradlew]);
      } catch (_) {
        // best-effort
      }
    }

    final result = await process.run(
      gradlew,
      [':app:tasks', '--all', '-q'],
      workingDirectory: _androidDir.path,
      useVendedFlutter: false,
    );

    if (result.exitCode != 0) {
      return FlavorDetectionResult(
        platform: platform,
        flavors: const [],
        warning: 'gradlew exited with ${result.exitCode}; '
            'assuming no flavors.',
      );
    }

    final flavors = _parseAssembleTasks(result.stdout.toString());
    return FlavorDetectionResult(platform: platform, flavors: flavors);
  }

  /// Extracts flavor names from `assemble<Flavor>Release` style tasks.
  /// Filters out `assembleRelease` / `assembleDebug` / `assembleProfile`
  /// (the no-flavor variants).
  static List<String> _parseAssembleTasks(String stdout) {
    final pattern = RegExp(r'^assemble([A-Z][A-Za-z0-9]*)Release\b',
        multiLine: true);
    final names = <String>{};
    for (final m in pattern.allMatches(stdout)) {
      final token = m.group(1)!;
      // Drop the catch-all `Release` (matches `assembleRelease`).
      if (token.isEmpty) continue;
      // First-letter-lower-case to match the canonical flavor name.
      names.add(token[0].toLowerCase() + token.substring(1));
    }
    return names.toList()..sort();
  }
}
