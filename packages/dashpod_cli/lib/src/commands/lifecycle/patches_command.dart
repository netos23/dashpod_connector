import 'dart:async';

import 'package:dashpod_api/dashpod_api.dart';

import '../../api/api_client.dart';
import '../../json/json_output.dart';
import '../dashpod_command.dart';
import 'lifecycle_resolver.dart';

/// `dashpod patches` — read/admin commands for OTA patches.
///
/// Mirrors `private_docs/CLIENT_ARCHITECTURE.MD §3.9`. Channel
/// auto-creation matches the `maybeGetChannel ?? createChannel`
/// pattern used by the patch publish path.
class PatchesCommand extends DashpodCommand {
  PatchesCommand({
    required super.env,
    required super.console,
    required super.logger,
    required JsonOutputSink json,
    required DashpodApiClientFactory apiClientFactory,
  }) : super(json: json) {
    addSubcommand(_PatchesListCommand(
      env: env,
      console: console,
      logger: logger,
      json: json,
      apiClientFactory: apiClientFactory,
    ));
    addSubcommand(_PatchesInfoCommand(
      env: env,
      console: console,
      logger: logger,
      json: json,
      apiClientFactory: apiClientFactory,
    ));
    addSubcommand(_PatchesPromoteCommand(
      env: env,
      console: console,
      logger: logger,
      json: json,
      apiClientFactory: apiClientFactory,
      isSetTrackAlias: false,
    ));
    addSubcommand(_PatchesPromoteCommand(
      env: env,
      console: console,
      logger: logger,
      json: json,
      apiClientFactory: apiClientFactory,
      isSetTrackAlias: true,
    ));
  }

  @override
  String get name => 'patches';

  @override
  String get description => 'Inspect and promote OTA patches.';
}

abstract class _PatchesSubcommand extends DashpodCommand {
  _PatchesSubcommand({
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
      )
      ..addOption(
        'release-version',
        help: 'Release version to operate on ("latest" picks the most recent).',
      );
  }

  final DashpodApiClientFactory _apiClientFactory;
  DashpodApiClient buildApi() => _apiClientFactory(env);

  int reportFail(JsonErrorCode code, String message) {
    if (isJsonMode) return emitJsonError(code: code, message: message);
    logger.err(message);
    return 1;
  }

  /// Resolves `(appId, releaseId)` from the shared flags, or returns
  /// the early-exit code via [reportFail].
  Future<({String appId, int releaseId, String version})?>
      resolveAppAndRelease() async {
    final resolver = LifecycleResolver(env: env, api: buildApi());
    final version = argResults!['release-version'] as String?;
    if (version == null || version.isEmpty) {
      reportFail(JsonErrorCode.usageError, '--release-version is required.');
      return null;
    }
    try {
      final yaml = resolver.loadDashpodYaml();
      final appId = resolver.resolveAppId(
        dashpodYaml: yaml,
        flavor: argResults!['flavor'] as String?,
        overrideAppId: argResults!['app-id'] as String?,
      );
      final release = await resolver.resolveRelease(
        appId: appId,
        version: version,
      );
      if (release.id == null) {
        reportFail(
          JsonErrorCode.softwareError,
          'Server returned a release with no id (version ${release.version}).',
        );
        return null;
      }
      return (
        appId: appId,
        releaseId: release.id!,
        version: release.version ?? version,
      );
    } on LifecycleResolveException catch (e) {
      reportFail(JsonErrorCode.softwareError, e.message);
      return null;
    } catch (e) {
      reportFail(JsonErrorCode.fetchFailed, '$e');
      return null;
    }
  }
}

class _PatchesListCommand extends _PatchesSubcommand {
  _PatchesListCommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    required super.apiClientFactory,
  });

  @override
  String get name => 'list';

  @override
  String get description => 'List patches published against a release.';

  @override
  Future<int> run() async {
    final resolved = await resolveAppAndRelease();
    if (resolved == null) return 1;

    try {
      final response = await buildApi().releasePatches.listPatches(
            resolved.appId,
            resolved.releaseId,
          );
      final patches = response.patches ?? const <ReleasePatchDto>[];
      if (isJsonMode) {
        return emitJsonSuccess(data: {
          'app_id': resolved.appId,
          'release_id': resolved.releaseId,
          'release_version': resolved.version,
          'patches': [for (final p in patches) p.toJson()],
        });
      }
      if (patches.isEmpty) {
        logger.info('No patches for release ${resolved.version}.');
        return 0;
      }
      logger.info(
        'Patches for release ${resolved.version} on ${resolved.appId}:',
      );
      for (final p in patches) {
        final artifactCount = p.artifacts?.length ?? 0;
        logger.info(
          '#${orDash(p.number).padRight(3)} '
          'channel=${orDash(p.channel).padRight(8)} '
          'artifacts=$artifactCount '
          'rolled_back=${p.rolledBack ?? false}',
        );
      }
      return 0;
    } catch (e) {
      return reportFail(JsonErrorCode.fetchFailed, '$e');
    }
  }
}

class _PatchesInfoCommand extends _PatchesSubcommand {
  _PatchesInfoCommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    required super.apiClientFactory,
  }) {
    argParser.addOption(
      'patch-number',
      help: 'Patch number within the release.',
    );
  }

  @override
  String get name => 'info';

  @override
  String get description => 'Show details for a single patch.';

  @override
  Future<int> run() async {
    final raw = argResults!['patch-number'] as String?;
    final number = raw == null ? null : int.tryParse(raw);
    if (number == null) {
      return reportFail(
        JsonErrorCode.usageError,
        '--patch-number is required and must be an integer.',
      );
    }

    final resolved = await resolveAppAndRelease();
    if (resolved == null) return 1;

    try {
      final response = await buildApi().releasePatches.listPatches(
            resolved.appId,
            resolved.releaseId,
          );
      final patches = response.patches ?? const <ReleasePatchDto>[];
      ReleasePatchDto? match;
      for (final p in patches) {
        if (p.number == number) {
          match = p;
          break;
        }
      }
      if (match == null) {
        return reportFail(
          JsonErrorCode.softwareError,
          'No patch #$number for release ${resolved.version}.',
        );
      }
      if (isJsonMode) {
        return emitJsonSuccess(data: {
          'app_id': resolved.appId,
          'release_id': resolved.releaseId,
          'release_version': resolved.version,
          'patch': match.toJson(),
        });
      }
      logger.info('Patch #${match.number} for release ${resolved.version}');
      logger.info('  channel      : ${orDash(match.channel)}');
      logger.info('  rolled back  : ${match.rolledBack ?? false}');
      logger.info('  notes        : ${orDash(match.notes)}');
      final arts = match.artifacts ?? const <PatchArtifactDto>[];
      logger.info('  artifacts (${arts.length}):');
      for (final a in arts) {
        logger.info(
          '    ${orDash(a.platform).padRight(8)} '
          '${orDash(a.arch).padRight(20)} '
          '${formatBytes(a.size).padLeft(10)}  '
          '${shortHash(a.hash)}',
        );
      }
      return 0;
    } catch (e) {
      return reportFail(JsonErrorCode.fetchFailed, '$e');
    }
  }
}

class _PatchesPromoteCommand extends _PatchesSubcommand {
  _PatchesPromoteCommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    required super.apiClientFactory,
    required this.isSetTrackAlias,
  }) {
    argParser
      ..addOption(
        'patch-number',
        help: 'Patch number within the release to promote.',
      )
      ..addOption(
        'track',
        help: 'Destination channel name (auto-created if missing). '
            'Defaults to "stable".',
        defaultsTo: 'stable',
      );
  }

  final bool isSetTrackAlias;

  @override
  String get name => isSetTrackAlias ? 'set-track' : 'promote';

  @override
  String get description => isSetTrackAlias
      ? 'Set the deployment channel of an existing patch.'
      : 'Promote an existing patch to a deployment channel.';

  @override
  Future<int> run() async {
    final raw = argResults!['patch-number'] as String?;
    final number = raw == null ? null : int.tryParse(raw);
    if (number == null) {
      return reportFail(
        JsonErrorCode.usageError,
        '--patch-number is required and must be an integer.',
      );
    }

    final track = (argResults!['track'] as String).trim();
    if (track.isEmpty) {
      return reportFail(JsonErrorCode.usageError, '--track must be non-empty.');
    }

    final resolved = await resolveAppAndRelease();
    if (resolved == null) return 1;

    try {
      final response = await buildApi().releasePatches.listPatches(
            resolved.appId,
            resolved.releaseId,
          );
      final patches = response.patches ?? const <ReleasePatchDto>[];
      ReleasePatchDto? match;
      for (final p in patches) {
        if (p.number == number) {
          match = p;
          break;
        }
      }
      if (match?.id == null) {
        return reportFail(
          JsonErrorCode.softwareError,
          'No patch #$number for release ${resolved.version}.',
        );
      }

      final channelId = await _resolveOrCreateChannel(
        appId: resolved.appId,
        name: track,
      );
      await buildApi().patches.createPromote(
            resolved.appId,
            PromotePatchRequestDto(patchId: match!.id, channelId: channelId),
          );

      if (isJsonMode) {
        return emitJsonSuccess(data: {
          'app_id': resolved.appId,
          'release_id': resolved.releaseId,
          'release_version': resolved.version,
          'patch_id': match.id,
          'patch_number': match.number,
          'channel': track,
        });
      }
      logger.info(
        'Promoted patch #${match.number} (id=${match.id}) → channel "$track".',
      );
      return 0;
    } catch (e) {
      return reportFail(JsonErrorCode.fetchFailed, '$e');
    }
  }

  Future<int> _resolveOrCreateChannel({
    required String appId,
    required String name,
  }) async {
    final existing = await buildApi().channels.listChannels(appId);
    for (final c in existing) {
      if (c.name == name && c.id != null) return c.id!;
    }
    final created = await buildApi().channels.createChannel(
          appId,
          CreateChannelRequestDto(channel: name),
        );
    final id = created.id;
    if (id == null) {
      throw StateError('Server did not return an id for channel "$name".');
    }
    return id;
  }
}
