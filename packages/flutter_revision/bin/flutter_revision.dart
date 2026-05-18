import 'dart:io';

import 'package:flutter_revision/flutter_revision.dart';

/// Resolves and prints the Flutter revision for a package.
///
/// Usage:
/// ```
/// dart run bin/flutter_revision.dart <path-to-package> [<output-file>]
/// ```
///
/// Exits 0 on success, 1 on error, 64 (EX_USAGE) on bad arguments.
Future<void> main(List<String> args) async {
  if (args.isEmpty || args.length > 2) {
    stderr.writeln(
      'Usage: dart run bin/flutter_revision.dart '
      '<path-to-package> [<output-file>]',
    );
    exit(64);
  }

  final packageDir = Directory(args[0]);
  if (!packageDir.existsSync()) {
    stderr.writeln('Error: directory not found: ${packageDir.path}');
    exit(1);
  }

  final resolver = FlutterRevisionResolver(log: stdout.writeln);
  final revision = resolver.resolve(packageDir.path);
  final versionArg = revision.toVersionArg();

  stdout.writeln('Resolved Flutter revision: $versionArg');

  if (args.length > 1) {
    final outputFile = File(args[1])
      ..createSync(recursive: true)
      ..writeAsStringSync(versionArg);
    stdout.writeln('Wrote revision to ${outputFile.path}');
  }
}
