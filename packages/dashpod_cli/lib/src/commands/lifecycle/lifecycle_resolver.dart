import 'package:dashpod_api/dashpod_api.dart';

import '../../api/api_client.dart';
import '../../config/dashpod_yaml.dart';
import '../../env/dashpod_env.dart';

/// Thrown by [LifecycleResolver] when the user-side input doesn't
/// resolve to a concrete artefact (no `dashpod.yaml`, unknown flavor,
/// release version not found, …). The lifecycle commands catch it and
/// re-emit it through their JSON envelope.
class LifecycleResolveException implements Exception {
  LifecycleResolveException(this.message);
  final String message;
  @override
  String toString() => 'LifecycleResolveException: $message';
}

/// Shared "where is `dashpod.yaml` and which appId/release applies"
/// resolver for the read & admin commands. Each command would otherwise
/// re-duplicate ~30 lines of "load yaml → look up flavor → fetch list".
class LifecycleResolver {
  LifecycleResolver({
    required this.env,
    required this.api,
    DashpodYamlIo? yamlIo,
  }) : _yamlIo = yamlIo ?? const DashpodYamlIo();

  final DashpodEnv env;
  final DashpodApiClient api;
  final DashpodYamlIo _yamlIo;

  /// Reads `dashpod.yaml` from the working directory's project root.
  /// Throws [LifecycleResolveException] when missing or malformed.
  DashpodYaml loadDashpodYaml() {
    final file = env.dashpodYamlFile;
    if (!file.existsSync()) {
      throw LifecycleResolveException(
        'dashpod.yaml not found at ${file.path}. Run `dashpod init` first.',
      );
    }
    try {
      return _yamlIo.read(file);
    } on FormatException catch (e) {
      throw LifecycleResolveException(e.message);
    }
  }

  /// Resolves the app id from the yaml's flavor map, honouring an
  /// optional `--app-id` override.
  String resolveAppId({
    required DashpodYaml dashpodYaml,
    String? flavor,
    String? overrideAppId,
  }) {
    if (overrideAppId != null && overrideAppId.isNotEmpty) {
      return overrideAppId;
    }
    if (flavor != null && !dashpodYaml.flavors.containsKey(flavor)) {
      throw LifecycleResolveException(
        'Flavor "$flavor" is not declared in dashpod.yaml.',
      );
    }
    return dashpodYaml.idForFlavor(flavor);
  }

  /// Resolves a release by version. `version=="latest"` picks the most
  /// recently created release.
  Future<ReleaseDto> resolveRelease({
    required String appId,
    required String version,
  }) async {
    final response = await api.releases.listReleases(appId, null);
    final releases = response.releases ?? const <ReleaseDto>[];
    if (releases.isEmpty) {
      throw LifecycleResolveException(
        'App $appId has no releases yet.',
      );
    }
    if (version == 'latest') {
      final sorted = releases.toList()
        ..sort((a, b) =>
            (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      return sorted.first;
    }
    final matches = releases.where((r) => r.version == version).toList();
    if (matches.isEmpty) {
      throw LifecycleResolveException(
        'No release found with version "$version" on app $appId.',
      );
    }
    return matches.first;
  }
}

/// Convenience formatter: collapses an `int?` bytes value into "1.2 MB".
String formatBytes(int? bytes) {
  if (bytes == null) return '?';
  const units = ['B', 'KiB', 'MiB', 'GiB'];
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  final precision = i == 0 ? 0 : 1;
  return '${value.toStringAsFixed(precision)} ${units[i]}';
}

/// Convenience: truncates long hex hashes for table display.
String shortHash(String? hash) {
  if (hash == null || hash.isEmpty) return '-';
  if (hash.length <= 12) return hash;
  return '${hash.substring(0, 12)}…';
}

/// Forces a value to its toString-able form, with a placeholder for null.
String orDash(Object? v) => v == null ? '-' : v.toString();

/// Ensures [argv] contains all of [required]; returns the first missing
/// name. Used by commands that take multiple required options.
String? firstMissing(Map<String, Object?> values, List<String> required) {
  for (final key in required) {
    final v = values[key];
    if (v == null || (v is String && v.isEmpty)) return key;
  }
  return null;
}
