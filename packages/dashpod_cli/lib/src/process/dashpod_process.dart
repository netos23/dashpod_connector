import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../env/dashpod_env.dart';
import '../logger/logger.dart';

/// Hook invoked the moment a streamed subprocess is spawned. Future use:
/// trace-flow events tied to the child pid.
typedef OnProcessStart = void Function(Process process);

/// Subprocess invocation wrapper.
///
/// Responsibilities:
///   * `useVendedFlutter` (default true) prepends [DashpodEnv.vendedFlutterBinDir]
///     to `PATH` so `flutter` / `dart` resolves to the pinned SDK.
///   * Every invocation is logged at `detail` level (command line, working
///     dir, exit code). Output is logged at `detail` too in [stream] mode.
///   * [stream] pipes stdout/stderr through the logger in real time — the
///     pattern needed for `flutter build` invocations in later tiers.
class DashpodProcess {
  DashpodProcess({required this.env, required this.logger});

  final DashpodEnv env;
  final Logger logger;

  /// Buffered run; returns the full result. Use for short-lived commands
  /// where you want stdout as a string.
  Future<ProcessResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool useVendedFlutter = true,
    bool runInShell = false,
  }) async {
    final mergedEnv = _buildEnv(environment, useVendedFlutter);
    final cwd = workingDirectory ?? env.workingDirectory.path;
    logger.detail('exec [$cwd] $executable ${args.join(' ')}');
    final result = await Process.run(
      executable,
      args,
      workingDirectory: cwd,
      environment: mergedEnv,
      includeParentEnvironment: true,
      runInShell: runInShell,
    );
    logger.detail('exit ${result.exitCode}: $executable');
    return result;
  }

  /// Streams stdout/stderr through [logger] line by line. Returns the
  /// final exit code. Use for long-lived commands whose output the user
  /// wants to follow live.
  Future<int> stream(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool useVendedFlutter = true,
    OnProcessStart? onStart,
  }) async {
    final mergedEnv = _buildEnv(environment, useVendedFlutter);
    final cwd = workingDirectory ?? env.workingDirectory.path;
    logger.detail('stream [$cwd] $executable ${args.join(' ')}');
    final process = await Process.start(
      executable,
      args,
      workingDirectory: cwd,
      environment: mergedEnv,
      includeParentEnvironment: true,
    );
    onStart?.call(process);
    final stdoutDone = _pipe(process.stdout, logger.info);
    final stderrDone = _pipe(process.stderr, logger.warn);
    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    logger.detail('exit $exitCode: $executable');
    return exitCode;
  }

  Map<String, String> _buildEnv(
    Map<String, String>? overrides,
    bool useVendedFlutter,
  ) {
    final merged = <String, String>{...overrides ?? const {}};
    if (useVendedFlutter) {
      final flutterBin = env.vendedFlutterBinDir;
      if (flutterBin != null) {
        final current = env.environment['PATH'] ?? '';
        final sep = Platform.isWindows ? ';' : ':';
        merged['PATH'] = '${flutterBin.path}$sep$current';
      }
    }
    return merged;
  }

  Future<void> _pipe(Stream<List<int>> stream, void Function(String) sink) {
    return stream
        .transform(systemEncoding.decoder)
        .transform(const LineSplitter())
        .forEach(sink);
  }
}
