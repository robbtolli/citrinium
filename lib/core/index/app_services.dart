import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:citrinium_core/citrinium_core.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../vault/vault_path_provider.dart';

/// Everything that depends on a chosen vault being open: the index
/// database/service and the live file watcher wired to it. One instance
/// exists per (currently-chosen) vault; picking a different vault tears
/// this down and creates a new one (see [dispose] and
/// `appServicesProvider`'s `ref.onDispose`).
class AppServices {
  AppServices({
    required this.vaultPath,
    required this.database,
    required this.indexService,
    required this.watcher,
    required this.watcherSubscription,
  });

  final String vaultPath;
  final IndexDatabase database;
  final IndexService indexService;
  final VaultWatcher watcher;
  final StreamSubscription<VaultChangeEvent> watcherSubscription;

  Future<void> dispose() async {
    await watcherSubscription.cancel();
    await watcher.stop();
    await database.close();
  }
}

/// Opens the index database for [vaultPath] and wires a live [VaultWatcher]
/// to it, per `docs/milestones/m0.md` W3/W4: this is the concrete mechanism
/// behind exit criterion #5 ("editing a `.md` file in an external editor
/// updates the running app's UI without restart") -- every screen reads
/// through `IndexService`'s reactive streams, and this is what keeps them
/// fed from disk.
///
/// The index file lives at `<appSupport>/index/<sha256(vaultPath)>.sqlite`
/// -- **never** inside the vault itself, per the "Index location" decision,
/// so a future sync layer over the vault folder can't accidentally sync
/// the cache.
Future<AppServices> openAppServices(String vaultPath) async {
  final appSupportDir = await getApplicationSupportDirectory();
  final indexDir = Directory(p.join(appSupportDir.path, 'index'));
  await indexDir.create(recursive: true);

  final vaultHash = sha256.convert(utf8.encode(vaultPath)).toString();
  final indexFile = File(p.join(indexDir.path, '$vaultHash.sqlite'));

  final connection = driftDatabase(
    name: vaultHash,
    native: DriftNativeOptions(databasePath: () async => indexFile.path),
  );
  final database = IndexDatabase(connection);
  final indexService = IndexService(database: database, vaultRootPath: vaultPath);
  await indexService.ensureUpToDate();

  final watcher = WatcherVaultWatcher(vaultRootPath: vaultPath);
  final subscription = watcher.events.listen(indexService.handleChange);
  await watcher.start();

  return AppServices(
    vaultPath: vaultPath,
    database: database,
    indexService: indexService,
    watcher: watcher,
    watcherSubscription: subscription,
  );
}

/// `null` iff no vault has been chosen yet (see [vaultPathProvider]) --
/// screens/`app/router.dart` use `.value == null` (once resolved) to decide
/// whether to redirect to the first-run vault-setup screen.
final appServicesProvider = FutureProvider<AppServices?>((ref) async {
  final vaultPath = ref.watch(vaultPathProvider);
  if (vaultPath == null) return null;

  final services = await openAppServices(vaultPath);
  ref.onDispose(() {
    // Fire-and-forget: providers can't await their own disposal, but this
    // still runs before the next vault's `openAppServices` call resolves
    // in practice (picking a new vault is a rare, user-initiated action,
    // not a hot path).
    unawaited(services.dispose());
  });
  return services;
});
