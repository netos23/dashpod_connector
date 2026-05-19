import 'dart:async';

import '../cache/cache.dart';
import '../json/json_output.dart';
import 'dashpod_command.dart';

/// `dashpod cache` — manage the on-disk download cache.
///
/// Two subcommands: `clean` removes the cache root, `update` invokes
/// [Cache.updateAll] so every registered [CachedArtifact] is freshly
/// downloaded and hash-verified.
class CacheCommand extends DashpodCommand {
  CacheCommand({
    required super.env,
    required super.console,
    required JsonOutputSink json,
    required super.logger,
    required Cache cache,
  }) : super(json: json) {
    addSubcommand(_CacheCleanCommand(
      env: env,
      console: console,
      json: json,
      logger: logger,
      cache: cache,
    ));
    addSubcommand(_CacheUpdateCommand(
      env: env,
      console: console,
      json: json,
      logger: logger,
      cache: cache,
    ));
  }

  @override
  String get name => 'cache';

  @override
  String get description => 'Manage the on-disk download cache.';
}

class _CacheUpdateCommand extends DashpodCommand {
  _CacheUpdateCommand({
    required super.env,
    required super.console,
    required super.json,
    required super.logger,
    required Cache cache,
  }) : _cache = cache;

  @override
  String get name => 'update';

  @override
  String get description =>
      'Download any missing or stale vendored artefacts.';

  final Cache _cache;

  @override
  Future<int> run() async {
    try {
      await _cache.updateAll();
    } catch (e) {
      if (isJsonMode) {
        return emitJsonError(
          code: JsonErrorCode.fetchFailed,
          message: 'Cache update failed: $e',
        );
      }
      logger.err('Cache update failed: $e');
      return 1;
    }
    final installed = _cache.artifacts
        .map((a) => {
              'name': a.name,
              'file_name': a.fileName,
              'path': a.installedFile(env, _cache.artifactDirectory).path,
            })
        .toList();
    if (isJsonMode) {
      return emitJsonSuccess(data: {
        'cache_root': _cache.root.path,
        'installed': installed,
      });
    }
    if (installed.isEmpty) {
      logger.info('No vendored artefacts registered.');
      return 0;
    }
    logger.info('Cache up to date at ${_cache.root.path}:');
    for (final a in installed) {
      logger.info('  ${a['name']} → ${a['path']}');
    }
    return 0;
  }
}

class _CacheCleanCommand extends DashpodCommand {
  _CacheCleanCommand({
    required super.env,
    required super.console,
    required super.json,
    required super.logger,
    required Cache cache,
  }) : _cache = cache;

  @override
  String get name => 'clean';

  @override
  String get description => 'Remove all downloaded artefacts from the cache.';

  final Cache _cache;

  @override
  Future<int> run() async {
    final root = _cache.root.path;
    final existed = _cache.root.existsSync();
    _cache.clean();
    if (isJsonMode) {
      return emitJsonSuccess(data: {
        'cache_root': root,
        'removed': existed,
      });
    }
    logger.info(existed
        ? 'Removed cache directory: $root'
        : 'Cache directory does not exist: $root');
    return 0;
  }
}
