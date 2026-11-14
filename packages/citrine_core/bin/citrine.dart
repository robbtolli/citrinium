import 'dart:io';

import 'package:citrine_core/citrine_core.dart';

Future<void> main(List<String> args) async {
  String? vaultPath;
  String? dbPath;
  final commandArgs = <String>[];

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--vault' && i + 1 < args.length) {
      vaultPath = args[++i];
    } else if (args[i] == '--db' && i + 1 < args.length) {
      dbPath = args[++i];
    } else {
      commandArgs.add(args[i]);
    }
  }

  vaultPath ??= Platform.environment['CITRINE_VAULT'];
  if (vaultPath == null || vaultPath.isEmpty) {
    stderr.writeln('Error: --vault <path> or CITRINE_VAULT is required.');
    exitCode = 2;
    return;
  }

  final runner = CitrineCliRunner(vaultPath: vaultPath, dbPath: dbPath);
  exitCode = await runner.run(commandArgs, out: stdout, err: stderr);
}
