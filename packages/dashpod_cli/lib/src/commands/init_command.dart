import 'dart:async';

import 'package:dashpod_api/dashpod_api.dart';
import 'package:path/path.dart' as p;

import '../api/api_client.dart';
import '../config/dashpod_yaml.dart';
import '../io/console.dart';
import '../json/json_output.dart';
import 'dashpod_command.dart';

/// `dashpod init` — first-time project setup.
///
/// Implements a subset of the init flow described in
/// `private_docs/CLIENT_ARCHITECTURE.MD §2.1`:
///
///   1. Sanity-check `pubspec.yaml` exists and `dashpod.yaml` does not
///      (unless `--force`).
///   2. Resolve the target organisation: `--organization-id` wins, else
///      single-org auto-select, else interactive picker.
///   3. Create the app on the server (`POST /apps`) — or reuse the id
///      passed via `--app-id`.
///   4. Write `dashpod.yaml` and insert it into `pubspec.yaml`'s
///      `flutter.assets` list.
///
/// **Not yet wired up** (each warrants its own slice; tracked against
/// the missing parts list in the migration status report):
///   * Android / iOS / macOS flavour detection (`gradlew :app:tasks --all`,
///     Xcode scheme inspection) and the resulting `flavors:` map.
///   * Doctor validators with `applyFixes: true`.
///   * Authenticated HTTP — today the API client only honours
///     `DASHPOD_TOKEN` as a static bearer token.
class InitCommand extends DashpodCommand {
  InitCommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    required DashpodApiClientFactory apiClientFactory,
    DashpodYamlIo? yamlIo,
  })  : _apiClientFactory = apiClientFactory,
        _yamlIo = yamlIo ?? const DashpodYamlIo() {
    argParser
      ..addFlag(
        'force',
        negatable: false,
        help: 'Overwrite an existing dashpod.yaml.',
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
        help: 'Skip server-side app creation and use this id directly.',
      );
  }

  @override
  String get name => 'init';

  @override
  String get description =>
      'Initialise dashpod.yaml and register the app with the server.';

  final DashpodApiClientFactory _apiClientFactory;
  final DashpodYamlIo _yamlIo;

  @override
  Future<int> run() async {
    final results = argResults!;
    final force = results['force'] as bool;
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
    final displayName = displayNameArg ?? pubspecName ?? 'My Dashpod App';

    String appId;
    if (preexistingAppId != null) {
      appId = preexistingAppId;
    } else {
      final api = _apiClientFactory(env);
      try {
        final orgId = await _resolveOrganizationId(api, orgIdArg);
        if (orgId == null) {
          return _fail(
            JsonErrorCode.interactivePromptRequired,
            'No organisation could be resolved. Pass --organization-id.',
          );
        }
        final app = await api.apps.createApp(
          CreateAppRequestDto(
            displayName: displayName,
            organizationId: orgId,
          ),
        );
        final id = app.id;
        if (id == null) {
          return _fail(
            JsonErrorCode.fetchFailed,
            'Server response did not include an app id.',
          );
        }
        appId = id;
      } catch (e) {
        return _fail(
          JsonErrorCode.fetchFailed,
          'Failed to create app: $e',
        );
      }
    }

    final yaml = DashpodYaml(appId: appId);
    _yamlIo.write(dashpodYamlFile, yaml);
    _yamlIo.insertAsFlutterAsset(pubspec, p.basename(dashpodYamlFile.path));

    if (isJsonMode) {
      return emitJsonSuccess(data: {
        'app_id': appId,
        'display_name': displayName,
        'dashpod_yaml_path': dashpodYamlFile.path,
        'pubspec_path': pubspec.path,
      });
    }

    logger.info('Wrote ${dashpodYamlFile.path} (app_id: $appId).');
    logger.info(
      'Added ${p.basename(dashpodYamlFile.path)} to '
      '${p.basename(pubspec.path)} flutter.assets.',
    );
    return 0;
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