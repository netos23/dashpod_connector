import 'dart:async';
import 'dart:io';

import 'package:dashpod_api/dashpod_api.dart';
import 'package:path/path.dart' as p;

import '../api/api_client.dart';
import '../config/dashpod_yaml.dart';
import '../flavor/android_flavor_detector.dart';
import '../flavor/apple_flavor_detector.dart';
import '../flavor/flavor_detector.dart';
import '../io/console.dart';
import '../json/json_output.dart';
import '../process/dashpod_process.dart';
import 'dashpod_command.dart';

/// `dashpod init` — first-time project setup.
///
/// Implements the init flow described in
/// `private_docs/CLIENT_ARCHITECTURE.MD §2.1`:
///
///   1. Sanity-check `pubspec.yaml` exists and `dashpod.yaml` does not
///      (unless `--force`).
///   2. Resolve the target organisation: `--organization-id` wins, else
///      single-org auto-select, else interactive picker.
///   3. **Detect flavors** for every platform the project supports
///      (Android via `./gradlew :app:tasks`, iOS / macOS via
///      `xcodebuild -list`). The union is used to build the `flavors:`
///      map. Skipped entirely with `--no-detect-flavors`.
///   4. Create the app(s) on the server (`POST /apps`) — one per flavor,
///      plus a base app when there are no flavors. Reuses
///      `--app-id` for the base when supplied.
///   5. Write `dashpod.yaml` and insert it into `pubspec.yaml`'s
///      `flutter.assets` list.
///
/// **Not yet wired up:**
///   * Doctor validators with `applyFixes: true` (run `dashpod doctor`
///     manually after init for now).
///   * Authenticated HTTP — today the API client only honours
///     `DASHPOD_TOKEN` as a static bearer token.
class InitCommand extends DashpodCommand {
  InitCommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    required DashpodApiClientFactory apiClientFactory,
    required DashpodProcess process,
    DashpodYamlIo? yamlIo,
    List<FlavorDetector>? flavorDetectors,
  })  : _apiClientFactory = apiClientFactory,
        _process = process,
        _yamlIo = yamlIo ?? const DashpodYamlIo(),
        _flavorDetectorsOverride = flavorDetectors {
    argParser
      ..addFlag(
        'force',
        negatable: false,
        help: 'Overwrite an existing dashpod.yaml.',
      )
      ..addFlag(
        'detect-flavors',
        defaultsTo: true,
        help: 'Detect Android / iOS / macOS flavors and create one app per flavor.',
      )
      ..addOption(
        'organization-id',
        help: 'Use this organisation id and skip the picker.',
      )
      ..addOption(
        'display-name',
        help: 'Display name for the created app. Defaults to the pubspec '
            '`name` field.',
      )
      ..addOption(
        'app-id',
        help: 'Skip server-side creation of the base app and use this id directly.',
      );
  }

  @override
  String get name => 'init';

  @override
  String get description =>
      'Initialise dashpod.yaml and register the app(s) with the server.';

  final DashpodApiClientFactory _apiClientFactory;
  final DashpodProcess _process;
  final DashpodYamlIo _yamlIo;
  final List<FlavorDetector>? _flavorDetectorsOverride;

  @override
  Future<int> run() async {
    final results = argResults!;
    final force = results['force'] as bool;
    final detectFlavors = results['detect-flavors'] as bool;
    final orgIdArg = results['organization-id'] as String?;
    final displayNameArg = results['display-name'] as String?;
    final preexistingAppId = results['app-id'] as String?;

    final pubspec = env.pubspecFile;
    if (pubspec == null) {
      return _fail(
        JsonErrorCode.softwareError,
        'No pubspec.yaml found in ${env.workingDirectory.path} or any parent.',
      );
    }

    final dashpodYamlFile = env.dashpodYamlFile;
    if (dashpodYamlFile.existsSync() && !force) {
      return _fail(
        JsonErrorCode.softwareError,
        'dashpod.yaml already exists at ${dashpodYamlFile.path}. '
        'Pass --force to overwrite.',
      );
    }

    final pubspecName = env.readPubspecName(pubspec);
    final baseName = displayNameArg ?? pubspecName ?? 'My Dashpod App';

    // 1. Detect flavors (best-effort; warnings logged, never fatal).
    final flavors = detectFlavors
        ? await _detectAllFlavors(p.dirname(pubspec.path))
        : const <String>[];

    // 2. Resolve org + create apps.
    String baseAppId;
    final flavorAppIds = <String, String>{};
    try {
      final api = _apiClientFactory(env);
      final orgId = (preexistingAppId == null || flavors.isNotEmpty)
          ? await _resolveOrganizationId(api, orgIdArg)
          : null;
      if (orgId == null && preexistingAppId == null) {
        return _fail(
          JsonErrorCode.interactivePromptRequired,
          'No organisation could be resolved. Pass --organization-id.',
        );
      }

      if (preexistingAppId != null) {
        baseAppId = preexistingAppId;
      } else {
        baseAppId = await _createApp(api, displayName: baseName, orgId: orgId!);
      }

      for (final flavor in flavors) {
        final id = await _createApp(
          api,
          displayName: '$baseName ($flavor)',
          orgId: orgId!,
        );
        flavorAppIds[flavor] = id;
      }
    } catch (e) {
      return _fail(JsonErrorCode.fetchFailed, 'Failed to create app(s): $e');
    }

    // 3. Write dashpod.yaml + patch pubspec.
    final yaml = DashpodYaml(appId: baseAppId, flavors: flavorAppIds);
    _yamlIo.write(dashpodYamlFile, yaml);
    _yamlIo.insertAsFlutterAsset(pubspec, p.basename(dashpodYamlFile.path));

    if (isJsonMode) {
      return emitJsonSuccess(data: {
        'app_id': baseAppId,
        'flavors': flavorAppIds,
        'display_name': baseName,
        'dashpod_yaml_path': dashpodYamlFile.path,
        'pubspec_path': pubspec.path,
      });
    }

    logger.info('Wrote ${dashpodYamlFile.path}');
    logger.info('  base app_id: $baseAppId');
    for (final e in flavorAppIds.entries) {
      logger.info('  flavor "${e.key}": ${e.value}');
    }
    logger.info(
      'Added ${p.basename(dashpodYamlFile.path)} to '
      '${p.basename(pubspec.path)} flutter.assets.',
    );
    return 0;
  }

  Future<String> _createApp(
    DashpodApiClient api, {
    required String displayName,
    required int orgId,
  }) async {
    final app = await api.apps.createApp(
      CreateAppRequestDto(displayName: displayName, organizationId: orgId),
    );
    final id = app.id;
    if (id == null) {
      throw StateError('Server response for "$displayName" did not include an app id.');
    }
    return id;
  }

  Future<List<String>> _detectAllFlavors(String projectRootPath) async {
    final projectRoot = Directory(projectRootPath);
    final detectors = _flavorDetectorsOverride ??
        <FlavorDetector>[
          AndroidFlavorDetector(projectRoot: projectRoot, process: _process),
          AppleFlavorDetector(
            projectRoot: projectRoot,
            process: _process,
            isMacOs: false,
          ),
          AppleFlavorDetector(
            projectRoot: projectRoot,
            process: _process,
            isMacOs: true,
          ),
        ];

    final union = <String>{};
    for (final d in detectors) {
      if (!d.canRun()) {
        logger.detail('flavor: skipping ${d.platform} (no project files)');
        continue;
      }
      logger.detail('flavor: detecting on ${d.platform}…');
      final result = await d.detect();
      if (result.warning != null) {
        logger.warn('flavor ${d.platform}: ${result.warning}');
      }
      if (result.flavors.isNotEmpty) {
        logger.detail('flavor ${d.platform}: ${result.flavors.join(", ")}');
        union.addAll(result.flavors);
      }
    }
    return union.toList()..sort();
  }

  Future<int?> _resolveOrganizationId(
    DashpodApiClient api,
    String? overrideId,
  ) async {
    if (overrideId != null) {
      final parsed = int.tryParse(overrideId);
      if (parsed == null) {
        throw FormatException('Invalid --organization-id: $overrideId');
      }
      return parsed;
    }

    final response = await api.organizations.listOrganizations();
    final memberships = response.organizations ?? const [];
    final orgs = [
      for (final m in memberships)
        if (m.organization?.id != null) m.organization!,
    ];

    if (orgs.isEmpty) return null;
    if (orgs.length == 1) return orgs.first.id;

    if (!env.canAcceptUserInput) {
      throw StateError(
        'Multiple organisations found; pass --organization-id when running '
        'non-interactively.',
      );
    }

    return console.pick<int>(
      prompt: 'Select an organisation:',
      options: [
        for (final o in orgs)
          ConsoleOption(
            label: '${o.name ?? "(unnamed)"} [#${o.id}]',
            value: o.id!,
          ),
      ],
    );
  }

  int _fail(JsonErrorCode code, String message) {
    if (isJsonMode) {
      return emitJsonError(code: code, message: message);
    }
    logger.err(message);
    return code == JsonErrorCode.usageError ? 64 : 1;
  }
}
