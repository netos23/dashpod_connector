import 'dart:async';

import 'package:dashpod_api/dashpod_api.dart';

import '../../api/api_client.dart';
import '../../json/json_output.dart';
import '../dashpod_command.dart';
import 'lifecycle_resolver.dart';

/// `dashpod releases` — read-only inspection of release rows.
///
/// Mirrors `private_docs/CLIENT_ARCHITECTURE.MD §3.9`. The
/// publishing-side work lives under [ReleaseCommand]; this command is
/// "show me what's already on the server".
class ReleasesCommand extends DashpodCommand {
  ReleasesCommand({
    required super.env,
    required super.console,
    required super.logger,
    required JsonOutputSink json,
    required DashpodApiClientFactory apiClientFactory,
  }) : super(json: json) {
    addSubcommand(_ReleasesListCommand(
      env: env,
      console: console,
      logger: logger,
      json: json,
      apiClientFactory: apiClientFactory,
    ));
    addSubcommand(_ReleasesInfoCommand(
      env: env,
      console: console,
      logger: logger,
      json: json,
      apiClientFactory: apiClientFactory,
    ));
  }

  @override
  String get name => 'releases';

  @override
  String get description => 'Inspect releases on the configured app.';
}

abstract class _ReleasesSubcommand extends DashpodCommand {
  _ReleasesSubcommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    required DashpodApiClientFactory apiClientFactory,
  }) : _apiClientFactory = apiClientFactory {
    argParser
      ..addOption(
        'flavor',
        help: 'Resolve the app id via dashpod.yaml flavor map.',
      )
      ..addOption(
        'app-id',
        help: 'Bypass dashpod.yaml and operate on this app id directly.',
      );
  }

  final DashpodApiClientFactory _apiClientFactory;
  DashpodApiClient buildApi() => _apiClientFactory(env);

  int reportFail(JsonErrorCode code, String message) {
    if (isJsonMode) return emitJsonError(code: code, message: message);
    logger.err(message);
    return 1;
  }
}

class _ReleasesListCommand extends _ReleasesSubcommand {
  _ReleasesListCommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    required super.apiClientFactory,
  });

  @override
  String get name => 'list';

  @override
  String get description => 'List releases on the configured app.';

  @override
  Future<int> run() async {
    final resolver = LifecycleResolver(env: env, api: buildApi());
    final String appId;
    try {
      final yaml = resolver.loadDashpodYaml();
      appId = resolver.resolveAppId(
        dashpodYaml: yaml,
        flavor: argResults!['flavor'] as String?,
        overrideAppId: argResults!['app-id'] as String?,
      );
    } on LifecycleResolveException catch (e) {
      return reportFail(JsonErrorCode.softwareError, e.message);
    }

    try {
      final response = await buildApi().releases.listReleases(appId, null);
      final releases = response.releases ?? const <ReleaseDto>[];

      if (isJsonMode) {
        return emitJsonSuccess(data: {
          'app_id': appId,
          'releases': [for (final r in releases) r.toJson()],
        });
      }

      if (releases.isEmpty) {
        logger.info('No releases on app $appId.');
        return 0;
      }
      logger.info('Releases on $appId:');
      for (final r in releases) {
        final platforms = (r.platformStatuses ?? const {}).entries
            .map((e) => '${e.key}=${e.value.toJson()}')
            .join(',');
        logger.info(
          '#${orDash(r.id)}  ${orDash(r.version).padRight(14)} '
          '${orDash(r.displayName).padRight(24)} '
          'flutter=${orDash(r.flutterRevision)}  '
          '[$platforms]  ${orDash(r.createdAt)}',
        );
      }
      return 0;
    } catch (e) {
      return reportFail(JsonErrorCode.fetchFailed, '$e');
    }
  }
}

class _ReleasesInfoCommand extends _ReleasesSubcommand {
  _ReleasesInfoCommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    required super.apiClientFactory,
  }) {
    argParser.addOption(
      'release-version',
      help: 'Release version to inspect ("latest" picks the most recent).',
    );
  }

  @override
  String get name => 'info';

  @override
  String get description => 'Show details for a single release.';

  @override
  Future<int> run() async {
    final version = argResults!['release-version'] as String?;
    if (version == null || version.isEmpty) {
      return reportFail(
        JsonErrorCode.usageError,
        '--release-version is required.',
      );
    }

    final resolver = LifecycleResolver(env: env, api: buildApi());
    final String appId;
    final ReleaseDto release;
    try {
      final yaml = resolver.loadDashpodYaml();
      appId = resolver.resolveAppId(
        dashpodYaml: yaml,
        flavor: argResults!['flavor'] as String?,
        overrideAppId: argResults!['app-id'] as String?,
      );
      release = await resolver.resolveRelease(appId: appId, version: version);
    } on LifecycleResolveException catch (e) {
      return reportFail(JsonErrorCode.softwareError, e.message);
    }

    try {
      final detail = await buildApi().releases.getRelease(appId, release.id!);
      final artifacts = await buildApi().releases.listArtifacts(
        appId,
        release.id!,
        null,
        null,
      );

      final body = {
        'app_id': appId,
        'release': detail.toJson(),
        'artifacts': [
          for (final a in artifacts.artifacts ?? const <ReleaseArtifactDto>[])
            a.toJson(),
        ],
      };
      if (isJsonMode) return emitJsonSuccess(data: body);

      logger.info('Release #${detail.release?.id} (${detail.release?.version})');
      logger.info('  display name : ${orDash(detail.release?.displayName)}');
      logger.info('  flutter rev  : ${orDash(detail.release?.flutterRevision)}');
      logger.info('  created at   : ${orDash(detail.release?.createdAt)}');
      final ps = detail.release?.platformStatuses ?? const {};
      if (ps.isNotEmpty) {
        logger.info('  platforms    :');
        for (final e in ps.entries) {
          logger.info('    - ${e.key}: ${e.value.toJson()}');
        }
      }
      final arts = artifacts.artifacts ?? const <ReleaseArtifactDto>[];
      logger.info('  artifacts (${arts.length}):');
      for (final a in arts) {
        logger.info(
          '    ${orDash(a.platform).padRight(8)} '
          '${orDash(a.arch).padRight(20)} '
          '${formatBytes(a.size).padLeft(10)}  '
          '${shortHash(a.hash)} '
          '${a.canSideload == true ? "(sideload)" : ""}',
        );
      }
      return 0;
    } catch (e) {
      return reportFail(JsonErrorCode.fetchFailed, '$e');
    }
  }
}
