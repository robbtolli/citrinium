import 'dart:async';
import 'dart:io';

import 'package:citrinium_core/index.dart';
import 'package:citrinium_core/vault.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Polling-tolerant wait, matching `test/vault/vault_watcher_test.dart`'s
/// helper: native watchers are fast, but CI/polling fallbacks can be slow.
Future<void> _waitUntil(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// `docs/milestones/m0.md` exit criterion #5: "Editing a `.md` file in an
/// external editor updates the running app's UI without restart." This
/// wires the real `WatcherVaultWatcher` (W1) directly to a real
/// `IndexService` (W3) over a real temp-dir vault -- the same path the
/// Flutter app's provider layer (W4) drives -- and asserts the index
/// converges to reflect an external edit made with plain `dart:io` file
/// writes (standing in for "an external editor"), with no app-initiated
/// write in between.
void main() {
  group('watcher -> index convergence', () {
    late Directory vault;
    late IndexDatabase db;
    late IndexService service;
    late WatcherVaultWatcher watcher;
    StreamSubscription<VaultChangeEvent>? sub;

    setUp(() async {
      vault = await Directory.systemTemp.createTemp(
        'citrinium_watcher_convergence_test',
      );
      db = IndexDatabase.memory();
      service = IndexService(database: db, vaultRootPath: vault.path);
      await service.fullRebuild();

      watcher = WatcherVaultWatcher(
        vaultRootPath: vault.path,
        debounce: const Duration(milliseconds: 50),
      );
      sub = watcher.events.listen(service.handleChange);
      await watcher.start();
    });

    tearDown(() async {
      await sub?.cancel();
      await watcher.stop();
      await db.close();
      await vault.delete(recursive: true);
    });

    test('creating a new file externally adds it to the index', () async {
      await File(
        p.join(vault.path, 'external.md'),
      ).writeAsString('- [ ] added externally\n');

      await _waitUntil(
        () async => await service.documentByRelPath('external.md') != null,
      );

      final doc = await service.documentByRelPath('external.md');
      final entries = await service.watchEntriesForDocument(doc!.id).first;
      expect(entries.single.textContent, 'added externally');
    });

    test(
      'editing an existing file externally updates its indexed entries',
      () async {
        final file = File(p.join(vault.path, 'note.md'));
        await file.writeAsString('- [ ] original text\n');
        await _waitUntil(
          () async => await service.documentByRelPath('note.md') != null,
        );

        await file.writeAsString('- [x] original text\n');

        await _waitUntil(() async {
          final doc = await service.documentByRelPath('note.md');
          if (doc == null) return false;
          final entries = await service.watchEntriesForDocument(doc.id).first;
          return entries.isNotEmpty && entries.single.taskState == 'completed';
        });
      },
    );

    test('deleting a file externally removes it from the index', () async {
      final file = File(p.join(vault.path, 'note.md'));
      await file.writeAsString('# Note\n');
      await _waitUntil(
        () async => await service.documentByRelPath('note.md') != null,
      );

      await file.delete();

      await _waitUntil(
        () async => await service.documentByRelPath('note.md') == null,
      );
    });
  });
}
