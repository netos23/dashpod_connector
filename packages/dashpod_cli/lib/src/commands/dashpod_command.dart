import 'package:args/command_runner.dart';

import '../env/dashpod_env.dart';
import '../io/console.dart';
import '../json/json_output.dart';

/// Base class for every `dashpod <subcommand>`.
///
/// Centralises:
///   * access to the shared services (env, console, JSON sink)
///   * `fullCommandName` — the slash-joined parent → child path used by
///     JSON envelopes and (future) telemetry
///   * `emitJsonSuccess` / `emitJsonError` so subcommands do not have to
///     branch on the `--json` flag themselves.
abstract class DashpodCommand extends Command<int> {
  DashpodCommand({
    required this.env,
    required this.console,
    required JsonOutputSink json,
  }) : _json = json;

  final DashpodEnv env;
  final ConsoleIo console;
  final JsonOutputSink _json;

  bool get isJsonMode => _json.isEnabled;

  String get fullCommandName {
    final parts = <String>[];
    Command<int>? c = this;
    while (c != null) {
      parts.add(c.name);
      c = c.parent;
    }
    return parts.reversed.join(' ');
  }

  int emitJsonSuccess({
    Map<String, Object?>? data,
    List<String> warnings = const [],
    int exitCode = 0,
  }) {
    _json.success(
      command: fullCommandName,
      data: data ?? const {},
      warnings: warnings,
    );
    return exitCode;
  }

  int emitJsonError({
    required JsonErrorCode code,
    required String message,
    String? hint,
    int exitCode = 1,
  }) {
    _json.error(
      command: fullCommandName,
      code: code,
      message: message,
      hint: hint,
    );
    return exitCode;
  }
}