import 'dart:convert';
import 'dart:io';

/// A single option shown by [ConsoleIo.pick].
class ConsoleOption<T> {
  const ConsoleOption({required this.label, required this.value});

  final String label;
  final T value;
}

/// Minimal terminal I/O wrapper.
///
/// Intentionally tiny — we want something the [DashpodCommand] base class
/// can hold without dragging in a heavy logger dependency. Replace with a
/// fuller progress-spinner / coloured-output package (e.g. mason_logger) in
/// a later slice once we know what's actually useful.
class ConsoleIo {
  ConsoleIo({
    required Stdin input,
    required IOSink output,
    required IOSink errorOutput,
  })  : _input = input,
        _output = output,
        _errorOutput = errorOutput;

  factory ConsoleIo.fromStdio() => ConsoleIo(
        input: stdin,
        output: stdout,
        errorOutput: stderr,
      );

  final Stdin _input;
  final IOSink _output;
  final IOSink _errorOutput;

  void writeln([Object? message = '']) => _output.writeln(message);
  void errorln([Object? message = '']) => _errorOutput.writeln(message);

  /// Reads a single line from stdin. Returns null on EOF.
  String? readLine() {
    return _input.readLineSync(encoding: utf8);
  }

  /// Asks the user to confirm; defaults to false when stdin is closed.
  bool confirm(String prompt, {bool defaultAnswer = false}) {
    final suffix = defaultAnswer ? '[Y/n]' : '[y/N]';
    _output.write('$prompt $suffix ');
    final line = readLine()?.trim().toLowerCase();
    if (line == null || line.isEmpty) return defaultAnswer;
    return line == 'y' || line == 'yes';
  }

  /// Presents [options] and returns the selected value. Throws
  /// [StateError] if stdin is closed before a valid selection is made.
  T pick<T>({
    required String prompt,
    required List<ConsoleOption<T>> options,
  }) {
    if (options.isEmpty) {
      throw ArgumentError.value(options, 'options', 'must not be empty');
    }
    _output.writeln(prompt);
    for (var i = 0; i < options.length; i++) {
      _output.writeln('  ${i + 1}) ${options[i].label}');
    }
    while (true) {
      _output.write('Selection [1-${options.length}]: ');
      final raw = readLine();
      if (raw == null) {
        throw StateError('stdin closed before selection');
      }
      final parsed = int.tryParse(raw.trim());
      if (parsed != null && parsed >= 1 && parsed <= options.length) {
        return options[parsed - 1].value;
      }
      _errorOutput.writeln('Please enter a number between 1 and '
          '${options.length}.');
    }
  }
}