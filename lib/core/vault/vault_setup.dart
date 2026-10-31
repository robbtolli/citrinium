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

String? _customDefaultVaultPathOverride;

/// For test fixtures only: overrides the default starter vault path.
void debugSetDefaultStarterVaultPath(String? path) {
  _customDefaultVaultPathOverride = path;
}

/// Resolves the default location for the Starter Vault:
/// - Desktop: `~/Documents/citrinium` (or `<appDocuments>/citrinium` fallback)
/// - Mobile: `<appDocuments>/vault`
Future<String> resolveDefaultStarterVaultPath() async {
  if (_customDefaultVaultPathOverride != null) {
    return _customDefaultVaultPathOverride!;
  }
  if (isDesktopVaultPlatform) {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.trim().isNotEmpty) {
      return p.join(home.trim(), 'Documents', 'citrinium');
    }
    final documentsDir = await getApplicationDocumentsDirectory();
    return p.join(documentsDir.path, 'citrinium');
  } else {
    final documentsDir = await getApplicationDocumentsDirectory();
    return p.join(documentsDir.path, 'vault');
  }
}

/// Provisions and ensures the default Starter Vault directory exists on disk.
Future<String> provisionStarterVaultDirectory() async {
  final targetPath = await resolveDefaultStarterVaultPath();
  final dir = Directory(targetPath);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir.path;
}

/// Creates a new named blank vault inside [parentDirectoryPath] with [vaultName].
///
/// Validates that [vaultName] is non-empty and does not contain illegal path
/// characters or traversal (`..`, `/`, `\`).
Future<String> createNamedVaultInDirectory({
  required String parentDirectoryPath,
  required String vaultName,
}) async {
  final cleanName = vaultName.trim();
  if (cleanName.isEmpty) {
    throw ArgumentError('Vault name cannot be empty.');
  }
  if (cleanName == '.' ||
      cleanName == '..' ||
      cleanName.contains('/') ||
      cleanName.contains(r'\')) {
    throw ArgumentError('Vault name contains invalid path characters.');
  }

  final targetDir = Directory(p.join(parentDirectoryPath, cleanName));
  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }
  return targetDir.path;
}
