import 'dart:io';

import 'package:citrinium_core/index.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<void> _write(Directory vault, String relPath, String content) async {
  final file = File(p.join(vault.path, relPath));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}

/// `docs/milestones/m0.md` exit criterion #4 ("deleting the index database
/// and relaunching reconstructs identical index state from files alone")
/// and W6's "rebuild determinism test: scan -> snapshot -> wipe -> rescan ->
/// identical", made concrete against a real (temp-dir) vault and a real
/// on-disk SQLite file -- not just an in-memory database -- since the exit
/// criterion is specifically about *deleting the database file*.
void main() {
  group('rebuild determinism', () {
    late Directory vault;
    late File dbFile;

    setUp(() async {
      vault = await Directory.systemTemp.createTemp(
        'citrinium_rebuild_determinism_test',
      );
      dbFile = File(p.join(vault.path, '..', 'index.sqlite'));

      await _write(
        vault,
        'inbox.md',
        '- [ ] Buy milk 📅 2026-08-01 @errands #groceries\n'
            '- [x] Done thing ^abc123\n'
            '- ○ Dentist 📅 2026-08-03\n'
            '- – A random idea\n'
            '- untyped bullet\n',
      );
      await _write(
        vault,
        'Projects/citrinium.md',
        '---\ncitrinium:\n  type: project\ntitle: Citrinium\n---\n'
            '# Citrinium\n\nSee [[inbox]] and [[Nonexistent]].\n',
      );
      await _write(vault, 'Areas/health.md', '# Health\n\nSome notes.\n');
    });

    tearDown(() async {
      await vault.delete(recursive: true);
      if (await dbFile.exists()) await dbFile.delete();
    });

    test(
      'scan -> snapshot -> wipe db -> rescan -> identical fingerprint and content',
      () async {
        final db1 = IndexDatabase.native(dbFile);
        final service1 = IndexService(database: db1, vaultRootPath: vault.path);
        await service1.fullRebuild();

        final fingerprint1 = await db1.computeFingerprint();
        final docs1 = await service1.watchAllDocuments().first;
        final entriesByPath1 = <String, List<String>>{};
        for (final doc in docs1) {
          final entries = await service1.watchEntriesForDocument(doc.id).first;
          entriesByPath1[doc.relPath] = entries
              .map((e) => '${e.kind}:${e.taskState}:${e.textContent}')
              .toList();
        }
        final linkCount1 = (await db1.select(db1.links).get()).length;
        await db1.close();

        // Wipe the index database file entirely -- this is the literal
        // exit-criterion #4 action.
        await dbFile.delete();
        expect(await dbFile.exists(), isFalse);

        final db2 = IndexDatabase.native(dbFile);
        final service2 = IndexService(database: db2, vaultRootPath: vault.path);
        await service2.fullRebuild();

        final fingerprint2 = await db2.computeFingerprint();
        final docs2 = await service2.watchAllDocuments().first;
        final entriesByPath2 = <String, List<String>>{};
        for (final doc in docs2) {
          final entries = await service2.watchEntriesForDocument(doc.id).first;
          entriesByPath2[doc.relPath] = entries
              .map((e) => '${e.kind}:${e.taskState}:${e.textContent}')
              .toList();
        }
        final linkCount2 = (await db2.select(db2.links).get()).length;
        await db2.close();

        expect(
          fingerprint2,
          fingerprint1,
          reason: 'vaultFingerprint must be identical after a wipe+rescan',
        );
        expect(docs2.map((d) => d.relPath).toSet(), docs1.map((d) => d.relPath).toSet());
        expect(
          docs2.map((d) => d.sha256).toSet(),
          docs1.map((d) => d.sha256).toSet(),
        );
        expect(entriesByPath2, entriesByPath1);
        expect(linkCount2, linkCount1);
      },
    );

    test(
      'rebuilding twice in a row without any file changes is a no-op on content',
      () async {
        final db = IndexDatabase.native(dbFile);
        final service = IndexService(database: db, vaultRootPath: vault.path);

        await service.fullRebuild();
        final fingerprint1 = await db.computeFingerprint();

        await service.fullRebuild();
        final fingerprint2 = await db.computeFingerprint();

        expect(fingerprint2, fingerprint1);
        await db.close();
      },
    );
  });
}
