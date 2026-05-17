import 'dart:io';

import 'package:dexdiff/dexdiff.dart';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('Usage: dexdiff <baseline.dex> <candidate.dex>');
    exit(64); // EX_USAGE
  }

  final baselineFile = File(args[0]);
  final candidateFile = File(args[1]);

  if (!baselineFile.existsSync()) {
    stderr.writeln('Error: baseline file not found: ${args[0]}');
    exit(1);
  }
  if (!candidateFile.existsSync()) {
    stderr.writeln('Error: candidate file not found: ${args[1]}');
    exit(1);
  }

  final parser = const DalvikParser();
  final DalvikExecutable baseline;
  final DalvikExecutable candidate;
  try {
    baseline = parser.parse(baselineFile.readAsBytesSync());
    candidate = parser.parse(candidateFile.readAsBytesSync());
  } on FormatException catch (e) {
    stderr.writeln('Error: failed to parse DEX file: $e');
    exit(1);
  }

  final report = const DalvikDiffer().diff(baseline, candidate);
  final summary = report.describe();

  if (summary.isNotEmpty) {
    print(summary);
  } else {
    print('No differences found.');
  }

  exit(report.isSafe ? 0 : 1);
}
