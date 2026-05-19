import 'dart:convert';
import 'dart:io';

/// Machine-readable error categories. Stable identifiers; downstream
/// tooling will switch on these. See `private_docs/CLIENT_ARCHITECTURE.MD
/// §5` for the contract.
enum JsonErrorCode {
  usageError,
  processExit,
  softwareError,
  interactivePromptRequired,
  fetchFailed,
}

extension on JsonErrorCode {
  String get wire {
    switch (this) {
      case JsonErrorCode.usageError:
        return 'usage_error';
      case JsonErrorCode.processExit:
        return 'process_exit';
      case JsonErrorCode.softwareError:
        return 'software_error';
      case JsonErrorCode.interactivePromptRequired:
        return 'interactive_prompt_required';
      case JsonErrorCode.fetchFailed:
        return 'fetch_failed';
    }
  }
}

/// Pure-data envelope. Kept around (rather than written straight to the
/// sink) so tests can assert on the shape without dealing with IO.
class JsonOutput {
  const JsonOutput.success({
    required this.command,
    this.data = const {},
    this.warnings = const [],
  })  : ok = true,
        errorCode = null,
        errorMessage = null,
        errorHint = null;

  const JsonOutput.error({
    required this.command,
    required JsonErrorCode code,
    required String message,
    String? hint,
  })  : ok = false,
        data = const {},
        warnings = const [],
        errorCode = code,
        errorMessage = message,
        errorHint = hint;

  final bool ok;
  final String command;
  final Map<String, Object?> data;
  final List<String> warnings;
  final JsonErrorCode? errorCode;
  final String? errorMessage;
  final String? errorHint;

  Map<String, Object?> toJson() {
    if (ok) {
      return {
        'ok': true,
        'command': command,
        'data': data,
        if (warnings.isNotEmpty) 'warnings': warnings,
      };
    }
    return {
      'ok': false,
      'command': command,
      'error': {
        'code': errorCode!.wire,
        'message': errorMessage,
        if (errorHint != null) 'hint': errorHint,
      },
    };
  }
}

/// Writes [JsonOutput] envelopes to a sink when JSON mode is enabled.
///
/// The `enabled` callback is evaluated lazily because the runner does not
/// know whether `--json` was set until after argv is scanned.
class JsonOutputSink {
  JsonOutputSink({
    required IOSink sink,
    required bool Function() enabled,
  })  : _sink = sink,
        _enabled = enabled;

  final IOSink _sink;
  final bool Function() _enabled;
  static const _encoder = JsonEncoder.withIndent(null);

  bool get isEnabled => _enabled();

  void emit(JsonOutput envelope) {
    if (!isEnabled) return;
    _sink.writeln(_encoder.convert(envelope.toJson()));
  }

  void success({
    required String command,
    Map<String, Object?> data = const {},
    List<String> warnings = const [],
  }) =>
      emit(JsonOutput.success(
        command: command,
        data: data,
        warnings: warnings,
      ));

  void error({
    required String command,
    required JsonErrorCode code,
    required String message,
    String? hint,
  }) =>
      emit(JsonOutput.error(
        command: command,
        code: code,
        message: message,
        hint: hint,
      ));
}