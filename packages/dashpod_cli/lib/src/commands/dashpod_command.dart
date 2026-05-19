import 'package:args/command_runner.dart';

import '../env/dashpod_env.dart';
import '../io/console.dart';
import '../json/json_output.dart';
import '../logger/logger.dart';

/// Base class for every `dashpod <subcommand>`.
///
/// Centralises:
///   * access to the shared services (env, console, logger, JSON sink)
///   * `fullCommandName` — the space-joined parent → child path used by
///     JSON envelopes and (future) telemetry
///   * `emitJsonSuccess` / `emitJsonError` so subcommands do not have to
///     branch on the `--json` flag themselves.
///
/// Output channel split (matches the model in
/// `private_docs/CLIENT_ARCHITECTURE.MD §3.1.1`):
///   * Use [logger] for command output the user reads (`Wrote …`,
///     warnings, errors). The logger respects `--json` (drops to file
///     only) and `--verbose` (promotes detail lines).
///   * Use [console] for interactive prompts only (`pick`, `confirm`,
///     `readLine`).
abstract class DashpodCommand extends Command<int> {
  DashpodCommand({
    required this.env,
    required this.console,
    required this.logger,
    required JsonOutputSink json,
  }) : _json = json;

  final DashpodEnv env;
  final ConsoleIo console;
  final Logger logger;
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
