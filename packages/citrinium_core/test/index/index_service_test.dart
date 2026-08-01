import 'dart:io';

import 'package:citrinium_core/index.dart';
import 'package:citrinium_core/parser.dart';
import 'package:citrinium_core/vault.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<void> _write(Directory vault, String relPath, String content) async {
  final file = File(p.join(vault.path, relPath));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}

void main() {
  group('IndexService', () {
    late Directory vault;
    late IndexDatabase db;
    late IndexService service;

    setUp(() async {
      vault = await Directory.systemTemp.createTemp('citrinium_index_test');
      db = IndexDatabase.memory();
      service = IndexService(database: db, vaultRootPath: vault.path);
    });

    tearDown(() async {
      await db.close();
      await vault.delete(recursive: true);
    });

    test('fullRebuild indexes every tracked file in the vault', () async {
      await _write(vault, 'inbox.md', '- [ ] Buy milk\n- [x] Done thing\n');
      await _write(
        vault,
        'Projects/citrinium.md',
        '---\ncitrinium:\n  type: project\n---\n# Citrinium\n',
      );
      await _write(vault, '.obsidian/workspace.md', 'should be ignored');

      final stats = await service.fullRebuild();

      expect(stats.documentCount, 2);
      final docs = await service.watchAllDocuments().first;
      expect(docs.map((d) => d.relPath).toSet(), {
        'Projects/citrinium.md',
        'inbox.md',
      });

      final project = docs.firstWhere((d) => d.relPath == 'Projects/citrinium.md');
      expect(project.docType, 'project');
      expect(project.title, 'Citrinium');

      final inbox = docs.firstWhere((d) => d.relPath == 'inbox.md');
      final entries = await service.watchEntriesForDocument(inbox.id).first;
      expect(entries, hasLength(2));
      expect(entries[0].kind, 'task');
      expect(entries[0].taskState, 'open');
      expect(entries[1].taskState, 'completed');
    });

    test('ensureUpToDate rebuilds a brand-new (empty) database', () async {
      await _write(vault, 'note.md', '# Note\n');
      await service.ensureUpToDate();
      final stats = await service.watchStats().first;
      expect(stats.documentCount, 1);
      expect(stats.parserVersion, currentParserVersion.toString());
    });

    test(
      'ensureUpToDate is a no-op when parserVersion already matches',
      () async {
        await _write(vault, 'note.md', '# Note\n');
        await service.fullRebuild();
        // Mutate the file on disk *without* re-running fullRebuild --
        // if ensureUpToDate re-scanned, this new file would show up.
        await _write(vault, 'second.md', '# Second\n');

        await service.ensureUpToDate();

        final stats = await service.watchStats().first;
        expect(stats.documentCount, 1, reason: 'should not have rescanned');
      },
    );

    test(
      'ensureUpToDate rebuilds when the stored parserVersion is stale',
      () async {
        await _write(vault, 'note.md', '# Note\n');
        await service.fullRebuild();
        await db.setMeta('parserVersion', '0');
        await _write(vault, 'second.md', '# Second\n');

        await service.ensureUpToDate();

        final stats = await service.watchStats().first;
        expect(stats.documentCount, 2);
        expect(stats.parserVersion, currentParserVersion.toString());
      },
    );

    test('handleChange upserts an added file incrementally', () async {
      await service.fullRebuild();
      await _write(vault, 'new.md', '- [ ] fresh task\n');

      await service.handleChange(
        VaultChangeEvent(type: VaultChangeType.add, path: VaultPath('new.md')),
      );

      final doc = await service.documentByRelPath('new.md');
      expect(doc, isNotNull);
      final entries = await service.watchEntriesForDocument(doc!.id).first;
      expect(entries.single.textContent, 'fresh task');
    });

    test(
      'handleChange skips reparsing when the file content is unchanged (same sha256)',
      () async {
        await _write(vault, 'note.md', '- [ ] task\n');
        await service.fullRebuild();
        final before = await service.documentByRelPath('note.md');

        // Touch the file's mtime without changing its content.
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final file = File(p.join(vault.path, 'note.md'));
        await file.writeAsString('- [ ] task\n');

        await service.handleChange(
          VaultChangeEvent(
            type: VaultChangeType.modify,
            path: VaultPath('note.md'),
          ),
        );

        final after = await service.documentByRelPath('note.md');
        expect(after!.id, before!.id, reason: 'row should not have been replaced');
        expect(after.sha256, before.sha256);
      },
    );

    test('handleChange reparses when content actually changed', () async {
      await _write(vault, 'note.md', '- [ ] task one\n');
      await service.fullRebuild();

      await _write(vault, 'note.md', '- [ ] task one\n- [ ] task two\n');
      await service.handleChange(
        VaultChangeEvent(
          type: VaultChangeType.modify,
          path: VaultPath('note.md'),
        ),
      );

      final doc = await service.documentByRelPath('note.md');
      final entries = await service.watchEntriesForDocument(doc!.id).first;
      expect(entries, hasLength(2));
    });

    test('handleChange removes a document on a remove event', () async {
      await _write(vault, 'note.md', '# Note\n');
      await service.fullRebuild();

      await File(p.join(vault.path, 'note.md')).delete();
      await service.handleChange(
        VaultChangeEvent(
          type: VaultChangeType.remove,
          path: VaultPath('note.md'),
        ),
      );

      expect(await service.documentByRelPath('note.md'), isNull);
      final stats = await service.watchStats().first;
      expect(stats.documentCount, 0);
    });

    test(
      'handleChange treats a raced remove (file gone before we read it) as a removal',
      () async {
        await _write(vault, 'note.md', '# Note\n');
        await service.fullRebuild();
        await File(p.join(vault.path, 'note.md')).delete();

        // An `add`/`modify` event whose file no longer exists by the time
        // we get to it (a real race with a fast delete) should not throw.
        await service.handleChange(
          VaultChangeEvent(
            type: VaultChangeType.modify,
            path: VaultPath('note.md'),
          ),
        );

        expect(await service.documentByRelPath('note.md'), isNull);
      },
    );

    test('resolves wikilinks to their target document by unique basename', () async {
      await _write(vault, 'Projects/citrinium.md', '# Citrinium\n');
      await _write(
        vault,
        'inbox.md',
        '- [ ] Check [[citrinium]] for status\n',
      );

      await service.fullRebuild();

      final project = await service.documentByRelPath('Projects/citrinium.md');
      final inbox = await service.documentByRelPath('inbox.md');
      final links = await db.select(db.links).get();
      final link = links.singleWhere((l) => l.sourceDocumentId == inbox!.id);
      expect(link.targetDocumentId, project!.id);
    });

    test('leaves an ambiguous wikilink target unresolved', () async {
      await _write(vault, 'a/note.md', '# A\n');
      await _write(vault, 'b/note.md', '# B\n');
      await _write(vault, 'inbox.md', '- [ ] See [[note]]\n');

      await service.fullRebuild();

      final links = await db.select(db.links).get();
      expect(links.single.targetDocumentId, isNull);
    });

    test('leaves a dangling wikilink target unresolved (not an error)', () async {
      await _write(vault, 'inbox.md', '- [ ] See [[Nonexistent Note]]\n');
      await service.fullRebuild();

      final links = await db.select(db.links).get();
      expect(links.single.targetDocumentId, isNull);
    });

    test(
      'a link resolves retroactively once its target is created',
      () async {
        await _write(vault, 'inbox.md', '- [ ] See [[Later Note]]\n');
        await service.fullRebuild();

        await _write(vault, 'Later Note.md', '# Later Note\n');
        await service.handleChange(
          VaultChangeEvent(
            type: VaultChangeType.add,
            path: VaultPath('Later Note.md'),
          ),
        );

        final target = await service.documentByRelPath('Later Note.md');
        final links = await db.select(db.links).get();
        expect(links.single.targetDocumentId, target!.id);
      },
    );

    test('removing a link target nulls out target_document_id', () async {
      await _write(vault, 'note.md', '# Note\n');
      await _write(vault, 'inbox.md', '- [ ] See [[note]]\n');
      await service.fullRebuild();

      await File(p.join(vault.path, 'note.md')).delete();
      await service.handleChange(
        VaultChangeEvent(type: VaultChangeType.remove, path: VaultPath('note.md')),
      );

      final links = await db.select(db.links).get();
      expect(links.single.targetDocumentId, isNull);
    });
  });
}
