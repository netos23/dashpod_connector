import 'dart:async';
import 'dart:io';

import '../archive_diff/archive_differ.dart';
import '../env/dashpod_env.dart';
import '../io/console.dart';
import '../logger/logger.dart';

/// Thrown when the diff between the release and the patch contains
/// changes that cannot be expressed as an OTA patch (e.g. native code
/// changes for an Android patch) and the user has not opted in.
class UnpatchableChangeException implements Exception {
  UnpatchableChangeException(this.message);
  final String message;
  @override
  String toString() => 'UnpatchableChangeException: $message';
}

/// Thrown when a user is given the diff prompt and declines.
class UserCancelledException implements Exception {
  UserCancelledException(this.message);
  final String message;
  @override
  String toString() => 'UserCancelledException: $message';
}

/// Runs the [ArchiveDiffer] and either confirms the diff is safe, asks
/// the user to confirm, or aborts.
///
/// Mirrors `private_docs/CLIENT_ARCHITECTURE.MD §3.6.3`. The class is
/// platform-agnostic — it consumes whatever [ArchiveDiffer] subclass
/// the caller hands it.
class PatchDiffChecker {
  PatchDiffChecker({
    required this.env,
    required this.console,
    required this.logger,
  });

  final DashpodEnv env;
  final ConsoleIo console;
  final Logger logger;

  Future<DiffStatus> confirmUnpatchableDiffsIfNecessary({
    required File releaseArchive,
    required File patchArchive,
    required ArchiveDiffer differ,
    bool allowAssetChanges = false,
    bool allowNativeChanges = false,
  }) async {
    final diffs = await differ.changedFiles(
      release: releaseArchive,
      patch: patchArchive,
    );

    final hasAssetChanges = differ.containsPotentiallyBreakingAssetDiffs(diffs);
    final hasNativeChanges = await differ.containsPotentiallyBreakingNativeDiffs(
      diffs: diffs,
      releaseArchive: releaseArchive,
      patchArchive: patchArchive,
    );

    if (hasNativeChanges) {
      _logBucket('Native code changed', diffs.native);
      await _gate(
        kind: 'native',
        allow: allowNativeChanges,
        prompt: 'Native code changed between the release and the patch. '
            'These changes will NOT be picked up by the OTA patch. '
            'Continue anyway?',
      );
    }

    if (hasAssetChanges) {
      _logBucket('Assets changed', diffs.assets);
      await _gate(
        kind: 'asset',
        allow: allowAssetChanges,
        prompt: 'Assets changed between the release and the patch. '
            'OTA patches cannot ship asset changes. Continue anyway?',
      );
    }

    return DiffStatus(
      hasAssetChanges: hasAssetChanges,
      hasNativeChanges: hasNativeChanges,
      diffs: diffs,
    );
  }

  void _logBucket(String header, List<String> paths) {
    if (paths.isEmpty) return;
    logger.warn('$header:');
    for (final p in paths) {
      logger.warn('  $p');
    }
  }

  Future<void> _gate({
    required String kind,
    required bool allow,
    required String prompt,
  }) async {
    if (allow) return;
    if (!env.canAcceptUserInput) {
      throw UnpatchableChangeException(
        'Unsupported $kind changes detected and the CLI is non-interactive. '
        'Re-run with --allow-$kind-changes if you understand the implications.',
      );
    }
    final confirmed = console.confirm(prompt, defaultAnswer: false);
    if (!confirmed) {
      throw UserCancelledException('User declined to ship a patch with $kind changes.');
    }
  }
}
