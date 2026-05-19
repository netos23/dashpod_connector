import 'dart:io';

import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Boot-time signature verification mode for the on-device updater. Mirrors
/// the field of the same name in `private_docs/ARCHITECTURE.MD §4.2`.
enum PatchVerification {
  strict,
  installOnly;

  String get wire => switch (this) {
        PatchVerification.strict => 'strict',
        PatchVerification.installOnly => 'install_only',
      };

  static PatchVerification? fromWire(String? raw) => switch (raw) {
        'strict' => PatchVerification.strict,
        'install_only' => PatchVerification.installOnly,
        _ => null,
      };
}

/// Strongly-typed view of `dashpod.yaml`.
///
/// Schema and defaults defined in
/// `private_docs/CLIENT_ARCHITECTURE.MD §3.2` (consumed by the on-device
/// updater per `ARCHITECTURE.MD §4.2`).
@immutable
class DashpodYaml {
  const DashpodYaml({
    required this.appId,
    this.flavors = const {},
    this.baseUrl,
    this.autoUpdate,
    this.patchVerification,
  });

  /// Required base app id.
  final String appId;

  /// Optional `flavor -> app_id` map for multi-flavour projects.
  final Map<String, String> flavors;

  /// Optional `base_url` override for the on-device updater.
  final String? baseUrl;

  /// If false, the on-device updater will not auto-check for updates.
  final bool? autoUpdate;

  /// Signature verification mode for the on-device updater.
  final PatchVerification? patchVerification;

  /// Returns the app id for the given [flavor], falling back to [appId]
  /// when no entry is present.
  String idForFlavor(String? flavor) {
    if (flavor == null) return appId;
    return flavors[flavor] ?? appId;
  }
}

/// File-system layer for `dashpod.yaml`. Split out from [DashpodYaml] so
/// commands can be tested against an in-memory replacement.
class DashpodYamlIo {
  const DashpodYamlIo();

  /// Parses [file]. Throws [FormatException] on malformed input or
  /// unrecognised top-level keys (matching the
  /// `disallowUnrecognizedKeys: true` rule in CLIENT_ARCHITECTURE.MD §3.2).
  DashpodYaml read(File file) {
    final doc = loadYaml(file.readAsStringSync());
    if (doc is! YamlMap) {
      throw const FormatException('dashpod.yaml must be a YAML map.');
    }
    const allowed = {
      'app_id',
      'flavors',
      'base_url',
      'auto_update',
      'patch_verification',
    };
    final unknown =
        doc.keys.cast<String>().where((k) => !allowed.contains(k)).toList();
    if (unknown.isNotEmpty) {
      throw FormatException(
        'Unrecognised keys in dashpod.yaml: ${unknown.join(', ')}',
      );
    }
    final appId = doc['app_id'];
    if (appId is! String || appId.isEmpty) {
      throw const FormatException('dashpod.yaml is missing required `app_id`.');
    }
    final flavorsNode = doc['flavors'];
    final flavors = <String, String>{};
    if (flavorsNode is YamlMap) {
      flavorsNode.forEach((k, v) {
        if (k is String && v is String) flavors[k] = v;
      });
    }
    return DashpodYaml(
      appId: appId,
      flavors: flavors,
      baseUrl: doc['base_url'] as String?,
      autoUpdate: doc['auto_update'] as bool?,
      patchVerification:
          PatchVerification.fromWire(doc['patch_verification'] as String?),
    );
  }

  /// Writes [yaml] to [file], creating parents as needed.
  void write(File file, DashpodYaml yaml) {
    final buffer = StringBuffer()
      ..writeln('# Dashpod project config. Checked in; embedded as a Flutter')
      ..writeln('# asset so the on-device updater can read it at runtime.')
      ..writeln('app_id: ${yaml.appId}');
    if (yaml.flavors.isNotEmpty) {
      buffer.writeln('flavors:');
      for (final entry in yaml.flavors.entries) {
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }
    if (yaml.baseUrl != null) buffer.writeln('base_url: ${yaml.baseUrl}');
    if (yaml.autoUpdate != null) {
      buffer.writeln('auto_update: ${yaml.autoUpdate}');
    }
    if (yaml.patchVerification != null) {
      buffer.writeln('patch_verification: ${yaml.patchVerification!.wire}');
    }
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(buffer.toString());
  }

  /// Ensures [assetName] appears in the `flutter.assets` list of
  /// [pubspec]. Uses `yaml_edit` so existing comments and structure are
  /// preserved. No-op if the entry already exists.
  void insertAsFlutterAsset(File pubspec, String assetName) {
    final editor = YamlEditor(pubspec.readAsStringSync());
    final doc = editor.parseAt([]);
    if (doc is! YamlMap) {
      throw const FormatException('pubspec.yaml must be a YAML map.');
    }

    if (doc['flutter'] is! YamlMap) {
      editor.update(['flutter'], {'assets': [assetName]});
      pubspec.writeAsStringSync(editor.toString());
      return;
    }

    final flutter = doc['flutter'] as YamlMap;
    final assets = flutter['assets'];
    if (assets is! YamlList) {
      editor.update(['flutter', 'assets'], [assetName]);
      pubspec.writeAsStringSync(editor.toString());
      return;
    }

    final existing = assets.cast<dynamic>().map((e) => e.toString()).toList();
    if (existing.contains(assetName)) return;
    editor.appendToList(['flutter', 'assets'], assetName);
    pubspec.writeAsStringSync(editor.toString());
  }
}