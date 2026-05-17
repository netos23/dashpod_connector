import 'package:space_gen/space_gen.dart';

class DashpodFileRenderer extends FileRenderer {
  DashpodFileRenderer(super.config);

  @override
  String modelPath(LayoutContext context) {
    final snakeName = context.schema.snakeName;
    final className = context.schema.typeName;
    final isMessage =
        className.endsWith('Request') || className.endsWith('Response');
    if (!isMessage) return 'src/models/$snakeName.dart';
    final base = _messageBaseName(snakeName);
    if (context.operationSnakeNames.contains(base)) {
      return 'src/messages/$base/$snakeName.dart';
    }
    return 'src/messages/$snakeName.dart';
  }

  /// Route generated round-trip tests to `test/generated/` so they sit
  /// alongside the hand-written tests at `test/src/` without colliding.
  /// Mirrors [modelPath], just under a dedicated directory.
  @override
  String? testPath(LayoutContext context) {
    final modelRelative = modelPath(context);
    // Strip a leading `src/` — we already namespace under `generated/`.
    final trimmed = modelRelative.startsWith('src/')
        ? modelRelative.substring('src/'.length)
        : modelRelative;
    final withSuffix = trimmed.replaceFirst(RegExp(r'\.dart$'), '_test.dart');
    return 'test/generated/$withSuffix';
  }

  /// Tests import the hand-maintained top-level barrel, not the
  /// generator's `api.dart` (which we don't emit — see below).
  @override
  String testBarrelImport() => 'dashpod_api.dart';

  /// Strip a trailing `_request`/`_response` (and any HTTP status code
  /// inline-schema suffix like `200_response`) from [snake], returning
  /// the operation-name portion. Non-matching input is returned as-is.
  static String _messageBaseName(String snake) {
    for (final suffix in const ['_request', '_response']) {
      if (snake.endsWith(suffix)) {
        var base = snake.substring(0, snake.length - suffix.length);
        final match = RegExp(r'\d+$').firstMatch(base);
        if (match != null) {
          base = base.substring(0, match.start);
        }
        return base;
      }
    }
    return snake;
  }


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
}

Future<int> main(List<String> arguments) =>
    runCli(arguments, fileRendererBuilder: DashpodFileRenderer.new);
