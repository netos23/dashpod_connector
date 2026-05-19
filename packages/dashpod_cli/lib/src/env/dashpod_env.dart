import 'dart:io';

import 'package:cli_util/cli_util.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Per-process environment for the CLI.
///
/// Owns the "where do paths live and what env vars matter" concerns —
/// equivalent to the env-style object in `private_docs/CLIENT_ARCHITECTURE.MD
/// §3.1.3`. Kept deliberately small for the scaffold; expand it as more
/// subsystems land (logs dir, vendored Flutter cache, Podfile lock hash,
/// etc.).
class DashpodEnv {
  DashpodEnv({
    required this.environment,
    required this.workingDirectory,
    Stdin? input,
    String hostedUrlDefault = 'https://api.dashpod.dev',
    String authServiceUrlDefault = 'https://auth.dashpod.dev',
  })  : _input = input ?? stdin,
        _hostedUrlDefault = hostedUrlDefault,
        _authServiceUrlDefault = authServiceUrlDefault;

  factory DashpodEnv.fromPlatform({Directory? workingDirectory}) =>
      DashpodEnv(
        environment: Platform.environment,
        workingDirectory: workingDirectory ?? Directory.current,
      );

  final Map<String, String> environment;
  final Directory workingDirectory;
  final Stdin _input;
  final String _hostedUrlDefault;
  final String _authServiceUrlDefault;

  /// The hosted API base URL (e.g. `https://api.dashpod.dev`).
  ///
  /// Resolution order: `DASHPOD_HOSTED_URL` env var → optional `base_url`
  /// override read from `dashpod.yaml` (not yet wired up here) → default.
  Uri get hostedUri =>
      Uri.parse(environment['DASHPOD_HOSTED_URL'] ?? _hostedUrlDefault);

  /// Auth service URL used by the OAuth loopback flow (future slice).
  Uri get authServiceUri => Uri.parse(
        environment['DASHPOD_AUTH_SERVICE_URL'] ?? _authServiceUrlDefault,
      );

  /// Static bearer token used as a temporary stand-in for full auth.
  /// Mirrors the `DASHPOD_TOKEN` short-circuit described in
  /// `private_docs/CLIENT_ARCHITECTURE.MD §3.3.3`.
  String? get sessionToken => environment['DASHPOD_TOKEN'];

  /// The XDG-style config directory for persisted state
  /// (`credentials.json`, logs, …). Created lazily by callers.
  Directory get configDirectory =>
      Directory(p.join(applicationConfigHome('dashpod')));

  /// Walks up from `workingDirectory` looking for `pubspec.yaml`.
  /// Returns null if none is found.
  File? get pubspecFile {
    Directory? dir = workingDirectory;
    while (dir != null) {
      final candidate = File(p.join(dir.path, 'pubspec.yaml'));
      if (candidate.existsSync()) return candidate;
      final parent = dir.parent;
      if (parent.path == dir.path) return null;
      dir = parent;
    }
    return null;
  }

  /// Target path for `dashpod.yaml`. Always sibling to `pubspec.yaml`
  /// when one was found, otherwise placed in `workingDirectory`.
  File get dashpodYamlFile {
    final pubspec = pubspecFile;
    final dir = pubspec != null
        ? Directory(p.dirname(pubspec.path))
        : workingDirectory;
    return File(p.join(dir.path, 'dashpod.yaml'));
  }

  /// Reads the `name:` field from a pubspec without pulling a full
  /// pubspec_parse dependency — keeps the scaffold lean.
  String? readPubspecName(File pubspec) {
    try {
      final doc = loadYaml(pubspec.readAsStringSync());
      if (doc is YamlMap) {
        final name = doc['name'];
        if (name is String && name.isNotEmpty) return name;
      }
    } catch (_) {
      // Malformed pubspec — let downstream surface a clearer error.
    }
    return null;
  }

  /// Conservative "are we on CI" probe — matches the set of env vars
  /// listed in `private_docs/CLIENT_ARCHITECTURE.MD §3.1.3`.
  bool get isRunningOnCI {
    const ciVars = [
      'BOT',
      'TRAVIS',
      'CONTINUOUS_INTEGRATION',
      'CI',
      'APPVEYOR',
      'CIRRUS_CI',
      'JENKINS_URL',
      'GITHUB_ACTIONS',
      'TF_BUILD',
    ];
    if (ciVars.any(environment.containsKey)) return true;
    if (environment.containsKey('AWS_REGION') &&
        environment.containsKey('CODEBUILD_INITIATOR')) {
      return true;
    }
    return false;
  }

  /// True iff stdin is a terminal *and* we are not running on CI. Used by
  /// commands before prompting interactively.
  bool get canAcceptUserInput {
    if (isRunningOnCI) return false;
    try {
      return _input.hasTerminal;
    } catch (_) {
      return false;
    }
  }
}