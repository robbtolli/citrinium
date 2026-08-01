import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Whether this platform gets the desktop vault-selection flow (a real
/// directory picker) rather than the mobile one (an auto-provisioned
/// directory), per `docs/milestones/m0.md`'s "Vault location" decision.
bool get isDesktopVaultPlatform =>
    Platform.isLinux || Platform.isMacOS || Platform.isWindows;

/// Opens a native directory picker for the user to choose an existing (or
/// new, empty) folder as their vault. Returns `null` if the user cancelled.
Future<String?> pickVaultDirectory() => getDirectoryPath();

/// Mobile has no directory-picker equivalent worth building for M0 (and
/// Android's SAF is ruled out permanently -- see `docs/milestones/m0.md`'s
/// "Android storage" decision): this auto-provisions a `Vault/` directory
/// inside the app's documents directory instead, creating it on first run.
Future<String> provisionMobileVaultDirectory() async {
  final documentsDir = await getApplicationDocumentsDirectory();
  final vaultDir = Directory(p.join(documentsDir.path, 'Vault'));
  if (!await vaultDir.exists()) {
    await vaultDir.create(recursive: true);
  }
  return vaultDir.path;
}
