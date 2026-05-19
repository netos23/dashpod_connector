import 'dart:async';

import '../cache/cache.dart';
import '../json/json_output.dart';
import 'dashpod_command.dart';

/// `dashpod cache` — manage the on-disk download cache.
///
/// Only `clean` is wired up at the scaffold stage; `update` will be added
/// alongside the first vendored artefact (the bsdiff `patch` binary in
/// Tier 5).
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
  }

  @override
  String get name => 'cache';

  @override
  String get description => 'Manage the on-disk download cache.';
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
