import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';

/// Categorised diff between two archives. Mirrors the buckets the
/// upstream `ArchiveDiffer` produces (see
/// `private_docs/CLIENT_ARCHITECTURE.MD §3.6.3`).
class ContentDiffs {
  ContentDiffs({
    required this.assets,
    required this.dart,
    required this.native,
  });

  /// Paths whose contents differ and which classify as user-visible
  /// asset bytes (images, manifests, fonts, …).
  final List<String> assets;

  /// Paths that map to the Dart AOT snapshot.
  final List<String> dart;

  /// Paths that map to native code (.dex on Android, dylibs on iOS, …).
  final List<String> native;

  bool get isEmpty => assets.isEmpty && dart.isEmpty && native.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

/// Aggregated verdict consumed by [PatchDiffChecker].
class DiffStatus {
  DiffStatus({
    required this.hasAssetChanges,
    required this.hasNativeChanges,
    required this.diffs,
  });

  final bool hasAssetChanges;
  final bool hasNativeChanges;
  final ContentDiffs diffs;
}

/// Per-platform archive differ. The base class does the CRC32-based
/// zip-directory comparison; subclasses classify changed paths into the
/// three buckets and decide whether a change is "potentially breaking"
/// for an OTA patch.
///
/// The CRC32 read deliberately does **not** decompress entries — we want
/// the order-of-magnitude speedup that comes from comparing the central
/// directory of two ~100 MB AABs without paying any zlib cost.
abstract class ArchiveDiffer {
  const ArchiveDiffer();

  /// Returns the bucketed differences between [release] and [patch].
  /// Order of returned lists is deterministic (alphabetic).
  Future<ContentDiffs> changedFiles({
    required File release,
    required File patch,
  }) async {
    final releaseCrcs = await _readCentralDirectory(release);
    final patchCrcs = await _readCentralDirectory(patch);
    final changedPaths = <String>{};

    for (final entry in patchCrcs.entries) {
      final base = releaseCrcs[entry.key];
      if (base == null || base != entry.value) {
        changedPaths.add(entry.key);
      }
    }

    final assets = <String>[];
    final dart = <String>[];
    final native = <String>[];
    for (final path in changedPaths) {
      if (shouldIgnore(path)) continue;
      if (isAssetPath(path)) {
        assets.add(path);
      } else if (isDartPath(path)) {
        dart.add(path);
      } else if (isNativePath(path)) {
        native.add(path);
      }
    }
    assets.sort();
    dart.sort();
    native.sort();
    return ContentDiffs(assets: assets, dart: dart, native: native);
  }

  /// True for paths that are uninteresting at OTA-patch time (e.g.
  /// asset manifests rebuilt every Flutter build).
  bool shouldIgnore(String path) => false;

  /// True for asset-shaped paths. Adding asset paths via an OTA patch
  /// is not supported (assets aren't shipped in patches).
  bool isAssetPath(String path);

  /// True for the Dart AOT snapshot path.
  bool isDartPath(String path);

  /// True for native-code paths (.dex, dylibs, frameworks…).
  bool isNativePath(String path);

  /// Predicate used by the diff-checker after applying the per-path
  /// safety subroutines (DEX semantic differ, asset whitelists, …). The
  /// default is conservative: any [diffs.assets] entry is breaking.
  bool containsPotentiallyBreakingAssetDiffs(ContentDiffs diffs) =>
      diffs.assets.isNotEmpty;

  /// Default native verdict — overridden by [AndroidArchiveDiffer] to
  /// invoke `DexDiffer` and filter additive-only DEX changes.
  Future<bool> containsPotentiallyBreakingNativeDiffs({
    required ContentDiffs diffs,
    required File releaseArchive,
    required File patchArchive,
  }) async {
    return diffs.native.isNotEmpty;
  }

  Future<Map<String, int>> _readCentralDirectory(File file) async {
    final input = InputFileStream(file.path);
    try {
      final zip = ZipDecoder().decodeStream(input, verify: false);
      final out = <String, int>{};
      for (final entry in zip) {
        if (!entry.isFile) continue;
        final crc = entry.crc32;
        if (crc == null) continue;
        out[entry.name] = crc;
      }
      return out;
    } finally {
      await input.close();
    }
  }
}
