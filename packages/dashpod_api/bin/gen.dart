import 'dart:io' as io;

import 'package:space_gen/space_gen.dart';
import 'package:space_gen/src/render/templates.dart';

class DashpodFileRenderer extends FileRenderer {
  DashpodFileRenderer(super.config);

  Uri? _serverUrl;

  /// schema.snakeName → clean API group name (e.g. 'patch_check', 'releases')
  final Map<String, String> _schemaApiGroup = {};

  /// All clean API names and their singular forms, sorted longest-first for
  /// greedy prefix matching in [modelPath].
  final List<(String prefix, String group)> _apiPrefixes = [];

  // ── API name helpers ────────────────────────────────────────────────────────

  static String _cleanApiSnakeName(Api api) {
    final name = api.snakeName;
    const suffix = '_controller';
    return name.endsWith(suffix)
        ? name.substring(0, name.length - suffix.length)
        : name;
  }

  String _apiFileName(Api api) => '${_cleanApiSnakeName(api)}_api';

  String _apiFilePath(Api api) => 'lib/api/${_apiFileName(api)}.dart';

  String _apiPackagePath(Api api) => 'api/${_apiFileName(api)}.dart';

  // Strip 'Controller' from the PascalCase class name.
  String _apiClassName(Api api) => api.className.replaceFirst('Controller', '');

  // Simple singularization: drop 'es' for -ches/-shes/-xes/-zes, else drop 's'.
  static String _singular(String name) {
    if (name.endsWith('ches') ||
        name.endsWith('shes') ||
        name.endsWith('xes') ||
        name.endsWith('zes')) {
      return name.substring(0, name.length - 2);
    }
    if (name.endsWith('s')) return name.substring(0, name.length - 1);
    return name;
  }

  // ── layout hooks ───────────────────────────────────────────────────────────

  @override
  String modelPath(LayoutContext context) {
    final snakeName = context.schema.snakeName;

    // Direct mapping: schema was explicitly referenced by an endpoint.
    final directApi = _schemaApiGroup[snakeName];
    if (directApi != null) {
      return 'src/models/$directApi/$snakeName.dart';
    }

    // Tier 2: sub-schema — find the longest directly-mapped schema name that is
    // a prefix of snakeName (e.g. patch_check_request_dto_arch → patch_check).
    String? bestApi;
    int bestLength = 0;
    for (final entry in _schemaApiGroup.entries) {
      if (snakeName.startsWith('${entry.key}_') &&
          entry.key.length > bestLength) {
        bestApi = entry.value;
        bestLength = entry.key.length;
      }
    }
    if (bestApi != null) {
      return 'src/models/$bestApi/$snakeName.dart';
    }

    // Tier 3: API-name prefix — greedy longest match among all API clean names
    // and their singular forms (e.g. 'releases' → also try 'release_').
    for (final (prefix, group) in _apiPrefixes) {
      if (snakeName.startsWith('${prefix}_') || snakeName == prefix) {
        return 'src/models/$group/$snakeName.dart';
      }
    }

    return 'src/models/$snakeName.dart';
  }

  @override
  String? testPath(LayoutContext context) {
    final modelRelative = modelPath(context);
    final trimmed = modelRelative.startsWith('src/')
        ? modelRelative.substring('src/'.length)
        : modelRelative;
    final withSuffix = trimmed.replaceFirst(RegExp(r'\.dart$'), '_test.dart');
    return 'test/generated/$withSuffix';
  }

  @override
  String testBarrelImport() => 'dashpod_api.dart';

  // ── scaffolding no-ops (hand-maintained files) ────────────────────────────

  @override
  void renderPubspec() {}

  @override
  void renderAnalysisOptions() {}

  @override
  void renderGitignore() {}

  @override
  void renderCspellConfig(List<String> misspellings) {}

  @override
  void renderAuth() {}

  @override
  void renderApiException() {}

  @override
  void renderApiClient(RenderSpec spec) {}

  @override
  void renderClient(List<Api> apis, {required String specName}) {}

  // ── spec render ───────────────────────────────────────────────────────────

  @override
  void render(RenderSpec spec, {bool clearDirectory = true}) {
    _serverUrl = spec.serverUrl;
    if (clearDirectory) {
      for (final stale in const [
        'lib/client.dart',
        'lib/api_client.dart',
        'lib/auth.dart',
      ]) {
        final file = fileWriter.fs.file('${fileWriter.outDir.path}/$stale');
        if (file.existsSync()) file.deleteSync();
      }
      // Base clearDirectory doesn't know about lib/src/; clear it here so
      // stale files from old layouts don't linger.
      for (final dir in const ['lib/src/models', 'lib/src/messages']) {
        final d = fileWriter.fs.directory('${fileWriter.outDir.path}/$dir');
        if (d.existsSync()) d.deleteSync(recursive: true);
      }
    }
    super.render(spec, clearDirectory: clearDirectory);
  }

  // ── barrel: separate api / models / dashpod_api barrels ──────────────────

  @override
  void renderPublicApi(Iterable<Api> apis, Iterable<RenderSchema> schemas) {
    final apisList = apis.toList();
    final schemasList = schemas.toList();

    // lib/api.dart – API classes
    final apiExports =
        apisList
            .map((a) => 'package:$packageName/${_apiPackagePath(a)}')
            .toList()
          ..sort();
    _writeBarrel('lib/api.dart', apiExports);

    // lib/models.dart – model/DTO classes
    final modelExports =
        schemasList
            .map((s) => 'package:$packageName/${modelPackagePath(s)}')
            .toList()
          ..sort();
    _writeBarrel('lib/models.dart', modelExports);

    // lib/dashpod_api.dart – top-level barrel re-exporting both
    _writeBarrel('lib/dashpod_api.dart', [
      'package:$packageName/api.dart',
      'package:$packageName/models.dart',
    ]);
  }

  void _writeBarrel(String path, List<String> exportPaths) {
    final exportContexts = exportPaths
        .map((p) => {'path': p, 'hasShow': false, 'shownTypes': ''})
        .toList();
    final output = templates.loadTemplate('public_api').renderString({
      'imports': <String>[],
      'exports': exportContexts,
    });
    fileWriter.writeFile(path: path, content: output);
  }

  // ── Retrofit client generation ────────────────────────────────────────────

  @override
  List<Api> renderApis(List<Api> apis) {
    // Populate schema→API map before renderModels is called so modelPath works.
    _buildSchemaApiGroup(apis);

    final myTemplates = _customTemplateProvider();
    final rendered = <Api>[];

    for (final api in apis) {
      final renderedApi = schemaRenderer.renderApi(api);
      usedModelHelpers.addAll(renderedApi.usage.modelHelpers);

      final endpointContexts = _endpointContexts(api);
      final schemaImports = (_schemaImportPaths(
        api,
      ).toList()..sort()).map((p) => {'path': p}).toList();

      final content = myTemplates.loadTemplate('retrofit_client').renderString({
        'className': _apiClassName(api),
        'fileName': _apiFileName(api),
        'description': api.description,
        'baseUrl': _serverUrl?.toString() ?? '',
        'endpoints': endpointContexts,
        'imports': schemaImports,
      });

      fileWriter.writeFile(path: _apiFilePath(api), content: content);
      rendered.add(api);
    }

    return rendered;
  }

  void _buildSchemaApiGroup(List<Api> apis) {
    _schemaApiGroup.clear();
    _apiPrefixes.clear();

    for (final api in apis) {
      final group = _cleanApiSnakeName(api);

      // Tier-1: direct endpoint schema references.
      void add(RenderSchema schema) {
        if (schema.createsNewType && !schema.isSmooshed) {
          _schemaApiGroup.putIfAbsent(schema.snakeName, () => group);
        }
      }

      for (final endpoint in api.endpoints) {
        for (final p in endpoint.parameters) {
          add(p.type);
        }
        final rb = endpoint.requestBody;
        if (rb != null) add(rb.schema);
        for (final r in endpoint.operation.responses) {
          add(r.content);
        }
        for (final r in endpoint.operation.rangeResponses) {
          add(r.content);
        }
        final def = endpoint.operation.defaultResponse;
        if (def != null) add(def.content);
      }

      // Tier-3 prefixes: the clean API name and its singular form so that
      // entity DTOs like 'release_dto' are matched by the 'releases' API
      // even when they're not directly referenced by an endpoint.
      _apiPrefixes.add((group, group));
      final singular = _singular(group);
      if (singular != group) _apiPrefixes.add((singular, group));
    }

    // Sort longest prefix first so greedy matching picks the most specific group.
    _apiPrefixes.sort((a, b) => b.$1.length.compareTo(a.$1.length));
  }

  List<Map<String, dynamic>> _endpointContexts(Api api) {
    final result = <Map<String, dynamic>>[];
    for (final endpoint in api.endpoints) {
      final stdCtx = endpoint.toTemplateContext(
        schemaRenderer,
        removePrefix: api.removePrefix,
      );
      final methodName = stdCtx['methodName'] as String? ?? endpoint.methodName;
      final returnType = stdCtx['returnType'] as String? ?? 'void';

      final params = <Map<String, dynamic>>[];
      for (final p in endpoint.parameters) {
        final dartName = p.dartParameterName(quirks);
        final annotation = switch (p.inLocation.name) {
          'path' => "@Path('${p.name}')",
          'query' => "@Query('${p.name}')",
          'header' => "@Header('${p.name}')",
          _ => "@Query('${p.name}')",
        };
        params.add({
          'annotation': annotation,
          'type': p.isRequired ? p.type.typeName : '${p.type.typeName}?',
          'dartName': dartName,
        });
      }
      final rb = endpoint.requestBody;
      if (rb != null) {
        final typeName = rb.schema.typeName;
        params.add({
          'annotation': '@Body()',
          'type': rb.isRequired
              ? typeName
              : typeName.endsWith('?')
              ? typeName
              : '$typeName?',
          'dartName': rb.dartParameterName(quirks),
        });
      }
      result.add({
        'httpMethod': endpoint.method.name.toUpperCase(),
        'urlPath': endpoint.path,
        'returnType': returnType,
        'methodName': methodName,
        'params': params,
      });
    }
    return result;
  }

  Set<String> _schemaImportPaths(Api api) {
    final paths = <String>{};
    void add(RenderSchema schema) {
      if (schema.createsNewType && !schema.isSmooshed) {
        paths.add(modelPackageImport(this, schema));
      }
    }

    for (final endpoint in api.endpoints) {
      for (final p in endpoint.parameters) {
        add(p.type);
      }
      final rb = endpoint.requestBody;
      if (rb != null) add(rb.schema);
      for (final r in endpoint.operation.responses) {
        add(r.content);
      }
      for (final r in endpoint.operation.rangeResponses) {
        add(r.content);
      }
      final def = endpoint.operation.defaultResponse;
      if (def != null) add(def.content);
    }
    return paths;
  }

  TemplateProvider _customTemplateProvider() {
    final scriptPath = io.Platform.script.toFilePath();
    final packageDir = io.File(scriptPath).parent.parent.path;
    return TemplateProvider.fromDirectory(
      fileWriter.fs.directory('$packageDir/bin/templates'),
    );
  }
}

Future<int> main(List<String> arguments) =>
    runCli(arguments, fileRendererBuilder: DashpodFileRenderer.new);
