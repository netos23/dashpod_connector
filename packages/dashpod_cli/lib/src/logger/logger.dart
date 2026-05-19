import 'dart:io';

import 'package:path/path.dart' as p;

/// Severity of a log line.
enum LogLevel { detail, info, warn, error }

/// CLI logger with two sinks: the terminal (level- and mode-aware) and a
/// per-run file mirror under `<configDir>/logs/<timestamp>.log` for
/// post-mortem ("file an issue" → tell the user where the log lives).
///
/// Dual-sink rules:
///   * `detail` — file always; stdout only when `--verbose`.
///   * `info`   — file always; stdout unless `--json` is set (which owns
///                stdout for the envelope).
///   * `warn`   — file + stderr always.
///   * `error`  — file + stderr always.
///
/// The file is created lazily on first write so commands that never log
/// don't leave empty files behind.
class Logger {
  Logger({
    required IOSink stdoutSink,
    required IOSink stderrSink,
    required this.logsDirectory,
    required this.isVerbose,
    required this.isJsonMode,
    DateTime Function()? clock,
  })  : _stdout = stdoutSink,
        _stderr = stderrSink,
        _clock = clock ?? DateTime.now;

  final IOSink _stdout;
  final IOSink _stderr;
  final Directory logsDirectory;
  final bool Function() isVerbose;
  final bool Function() isJsonMode;
  final DateTime Function() _clock;

  IOSink? _fileSink;
  File? _logFile;

  /// Path of the per-run log file. Null until something has been logged.
  File? get currentLogFile => _logFile;

  void detail(String message) => _write(LogLevel.detail, message);
  void info(String message) => _write(LogLevel.info, message);
  void warn(String message) => _write(LogLevel.warn, message);
  void err(String message) => _write(LogLevel.error, message);

  void _write(LogLevel level, String message) {
    final now = _clock();
    final fileLine = '[${now.toIso8601String()}] ${level.name.padRight(6)} '
        '$message';
    _appendToFile(fileLine);

    if (isJsonMode() && level == LogLevel.info) return;
    if (level == LogLevel.detail && !isVerbose()) return;

    final consoleSink = switch (level) {
      LogLevel.detail || LogLevel.info => _stdout,
      LogLevel.warn || LogLevel.error => _stderr,
    };
    consoleSink.writeln(message);
  }

  void _appendToFile(String line) {
    final sink = _fileSink ??= _openFile();
    sink.writeln(line);
  }

  IOSink _openFile() {
    logsDirectory.createSync(recursive: true);
    final stamp = _clock()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(p.join(logsDirectory.path, '$stamp.log'));
    _logFile = file;
    return file.openWrite(mode: FileMode.append);
  }

  Future<void> close() async {
    final sink = _fileSink;
    if (sink == null) return;
    await sink.flush();
    await sink.close();
    _fileSink = null;
  }
}
