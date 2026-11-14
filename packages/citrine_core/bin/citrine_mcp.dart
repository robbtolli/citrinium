import 'dart:io';

import 'package:citrine_core/citrine_core.dart';

Future<void> main(List<String> args) async {
  String? vaultPath;
  String? dbPath;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--vault' && i + 1 < args.length) {
      vaultPath = args[++i];
    } else if (args[i] == '--db' && i + 1 < args.length) {
      dbPath = args[++i];
    }
  }

  vaultPath ??= Platform.environment['CITRINE_VAULT'];
  if (vaultPath == null || vaultPath.isEmpty) {
    stderr.writeln('Error: --vault <path> or CITRINE_VAULT is required.');
    exitCode = 2;
    return;
  }

  final server = CitrineMcpServer(vaultPath: vaultPath, dbPath: dbPath);
  await server.open();
  try {
    await server.serveStdio(input: stdin, output: stdout);
  } finally {
    await server.close();
  }
}
