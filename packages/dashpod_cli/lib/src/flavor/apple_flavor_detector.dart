import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../process/dashpod_process.dart';
import 'flavor_detector.dart';

/// Detects iOS / macOS flavors by enumerating Xcode schemes.
///
/// Flutter projects ship a single `Runner` scheme by default; any
/// additional scheme is taken to be a flavor (the same convention
/// `flutter run --flavor=<name>` uses).
class AppleFlavorDetector extends FlavorDetector {
  AppleFlavorDetector({
    required this.projectRoot,
    required this.process,
    required this.isMacOs,
  });

  final Directory projectRoot;
  final DashpodProcess process;
  final bool isMacOs;

  Directory get _platformDir => Directory(
        p.join(projectRoot.path, isMacOs ? 'macos' : 'ios'),
      );

  Directory? get _workspace {
    final ws = Directory(p.join(_platformDir.path, 'Runner.xcworkspace'));
    return ws.existsSync() ? ws : null;
  }

  Directory? get _project {
    final pr = Directory(p.join(_platformDir.path, 'Runner.xcodeproj'));
    return pr.existsSync() ? pr : null;
  }

  @override
  String get platform => isMacOs ? 'macos' : 'ios';

  @override
  bool canRun() {
    if (!Platform.isMacOS) return false; // xcodebuild is mac-only
    if (!_platformDir.existsSync()) return false;
    return _workspace != null || _project != null;
  }

  @override
  Future<FlavorDetectionResult> detect() async {
    final args = <String>['-list', '-json'];
    if (_workspace != null) {
      args.addAll(['-workspace', _workspace!.path]);
    } else {
      args.addAll(['-project', _project!.path]);
    }

    final result = await process.run(
      'xcodebuild',
      args,
      workingDirectory: _platformDir.path,
      useVendedFlutter: false,
    );

    if (result.exitCode != 0) {
      return FlavorDetectionResult(
        platform: platform,
        flavors: const [],
        warning: 'xcodebuild exited with ${result.exitCode}; '
            'assuming no flavors.',
      );
    }

    try {
      final doc = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      // Workspace vs project responses use different top-level keys.
      final inner = (doc['workspace'] ?? doc['project']) as Map<String, dynamic>?;
      final schemes = (inner?['schemes'] as List?)?.cast<String>() ?? const [];
      final flavors = schemes.where((s) => s != 'Runner').toList()..sort();
      return FlavorDetectionResult(platform: platform, flavors: flavors);
    } catch (e) {
      return FlavorDetectionResult(
        platform: platform,
        flavors: const [],
        warning: 'Failed to parse xcodebuild output: $e',
      );
    }
  }
}
