import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:dexdiff/dexdiff.dart';
import 'package:path/path.dart' as p;

import 'archive_differ.dart';

/// Outcome of running [AndroidArchiveDiffer.compareDex] on a single
/// .dex path. `additiveOnly == true` means the only differences are
/// new classes/methods — semantically safe for a patch.
class DexComparison {
  DexComparison({
    required this.path,
    required this.additiveOnly,
    required this.report,
  });

  final String path;
  final bool additiveOnly;
  final DiffReport report;
}

/// Android-specific path classification + DEX semantic differ
/// integration. Matches `private_docs/CLIENT_ARCHITECTURE.MD §3.6.2`.
class AndroidArchiveDiffer extends ArchiveDiffer {
  const AndroidArchiveDiffer({this.dexParser = const DalvikParser()});

  final DalvikParser dexParser;

  /// Files that change every build and are not load-bearing for the
  /// on-device app behaviour.
  static const _ignoredBasenames = <String>{
    'AssetManifest.bin',
    'NOTICES.Z',
  };

  /// Files at *added* paths under `assets/`. Adding an asset via an OTA
  /// patch is unsupported, but rewriting `AssetManifest.json` is fine.
  static const _alwaysIgnoredPaths = <String>{
    'base/assets/flutter_assets/AssetManifest.json',
  };

  @override
  bool shouldIgnore(String path) {
    if (_alwaysIgnoredPaths.contains(path)) return true;
    return _ignoredBasenames.contains(p.basename(path));
  }

  @override
  bool isAssetPath(String path) {
    // Anything under base/assets/ or base/res/ (i.e. user-visible asset
    // bytes) is "asset" for OTA purposes. Doesn't double-count Dart or
    // DEX entries, which are filtered ahead of this check by the caller
    // checking [isDartPath] / [isNativePath] first.
    return path.startsWith('base/assets/') ||
        path.startsWith('base/res/') ||
        path == 'base/manifest/AndroidManifest.xml';
  }

  @override
  bool isDartPath(String path) {
    final basename = p.basename(path);
    return basename == 'libapp.so';
  }

  @override
  bool isNativePath(String path) {
    final basename = p.basename(path);
    if (basename == 'libflutter.so') return true; // pinned per Flutter rev
    return p.extension(path) == '.dex';
  }

  @override
  Future<bool> containsPotentiallyBreakingNativeDiffs({
    required ContentDiffs diffs,
    required File releaseArchive,
    required File patchArchive,
  }) async {
    if (diffs.native.isEmpty) return false;

    // libflutter.so changing is always breaking (the user has changed
    // the Flutter revision; no OTA can recover from that).
    if (diffs.native.any((p) => p.endsWith('libflutter.so'))) return true;

    final dexPaths =
        diffs.native.where((p) => p.endsWith('.dex')).toList(growable: false);
    if (dexPaths.isEmpty) return false;

    final releaseEntries = await _entriesByName(releaseArchive, dexPaths);
    final patchEntries = await _entriesByName(patchArchive, dexPaths);
    for (final path in dexPaths) {
      final cmp = compareDex(
        path: path,
        releaseBytes: releaseEntries[path],
        patchBytes: patchEntries[path],
      );
      if (!cmp.additiveOnly) return true;
    }
    return false;
  }

  /// Runs the semantic DEX differ on a single path. `releaseBytes` /
  /// `patchBytes` may be null when the file was added or removed —
  /// either of those is considered a breaking change.
  DexComparison compareDex({
    required String path,
    required Uint8List? releaseBytes,
    required Uint8List? patchBytes,
  }) {
    if (releaseBytes == null || patchBytes == null) {
      return DexComparison(
        path: path,
        additiveOnly: false,
        report: const DiffReport.identical(),
      );
    }
    try {
      final base = dexParser.parse(releaseBytes);
      final cand = dexParser.parse(patchBytes);
      final report = const DalvikDiffer().diff(base, cand);
      final additiveOnly = report.changes.every(
        (c) =>
            c.kind == ChangeKind.classAdded ||
            c.kind == ChangeKind.methodAdded ||
            c.kind == ChangeKind.fieldAdded ||
            c.kind.isSafe,
      );
      return DexComparison(
        path: path,
        additiveOnly: additiveOnly,
        report: report,
      );
    } catch (_) {
      // Conservative: unparseable DEX = breaking. The CLI will surface
      // a per-DEX explanation when prompting the user.
      return DexComparison(
        path: path,
        additiveOnly: false,
        report: const DiffReport.identical(),
      );
    }
  }

  Future<Map<String, Uint8List>> _entriesByName(
    File archive,
    List<String> names,
  ) async {
    final wanted = names.toSet();
    final out = <String, Uint8List>{};
    final input = InputFileStream(archive.path);
    try {
      final zip = ZipDecoder().decodeStream(input, verify: false);
      for (final entry in zip) {
        if (!entry.isFile) continue;
        if (!wanted.contains(entry.name)) continue;
        out[entry.name] = entry.readBytes()!;
      }
    } finally {
      await input.close();
    }
    return out;
  }
}
