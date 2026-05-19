import 'dart:io';

import 'package:dashpod_cli/dashpod_cli.dart';

Future<void> main(List<String> args) async {
  final code = await DashpodCliCommandRunner().run(args) ?? 0;
  await stdout.flush();
  await stderr.flush();
  exit(code);
}