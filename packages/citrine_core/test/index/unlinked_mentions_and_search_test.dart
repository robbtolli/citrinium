import 'package:citrine_core/citrine_core.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  group('Unlinked Mentions & Vault Search (M9 - N-02, N-03, FR-06)', () {
    late IndexDatabase db;

    setUp(() async {
      db = IndexDatabase(NativeDatabase.memory());
      // Seed sample documents
      await db.replaceAllDocuments([
        ScannedDocument(
          relPath: 'projects/alpha.md',
          sha256: 'sha-alpha',
          mtimeMs: 1000,
          sizeBytes: 100,
          docType: 'project',
          title: 'Project Alpha',
          frontmatterJson: null,
          rawText: '# Project Alpha\n- [ ] Initial prototype\n- [ ] Design Review @computer',
          entries: [
            const ScannedEntry(
              lineIndex: 1,
              charStart: 16,
              charEnd: 37,
              kind: 'task',
              text: 'Initial prototype',
              taskState: 'open',
            ),
            const ScannedEntry(
              lineIndex: 2,
              charStart: 38,
              charEnd: 67,
              kind: 'task',
              text: 'Design Review @computer',
              taskState: 'open',
              contexts: ['computer'],
            ),
          ],
          links: [],
        ),
        ScannedDocument(
          relPath: 'daily/2026-10-31.md',
          sha256: 'sha-daily',
          mtimeMs: 1000,
          sizeBytes: 120,
          docType: 'dailyLog',
          title: '2026-10-31',
          frontmatterJson: null,
          rawText: '# 2026-10-31\n- [ ] Worked on Project Alpha notes today\n- [ ] Read [[projects/alpha|Project Alpha]] specification',
          entries: [
            const ScannedEntry(
              lineIndex: 1,
              charStart: 13,
              charEnd: 54,
              kind: 'task',
              text: 'Worked on Project Alpha notes today',
              taskState: 'open',
            ),
            const ScannedEntry(
              lineIndex: 2,
              charStart: 55,
              charEnd: 111,
              kind: 'task',
              text: 'Read [[projects/alpha|Project Alpha]] specification',
              taskState: 'open',
            ),
          ],
          links: [
            const ScannedLink(
              targetRaw: 'projects/alpha',
              isEmbed: false,
              sourceLineIndex: 2,
            ),
          ],
        ),
      ]);
    });

    tearDown(() async {
      await db.close();
    });

    test('findUnlinkedMentionsForDocument discovers unlinked mention and skips linked mention', () async {
      final alphaDoc = await db.documentByRelPath('projects/alpha.md');
      expect(alphaDoc, isNotNull);

      final mentions = await db.findUnlinkedMentionsForDocument(alphaDoc!);
      expect(mentions, hasLength(1));
      expect(mentions.first.sourceDocument.relPath, 'daily/2026-10-31.md');
      expect(mentions.first.matchedText, 'Project Alpha');
      expect(mentions.first.lineIndex, 1);
      expect(mentions.first.snippet, contains('Project Alpha'));
    });

    test('searchVault filters by facet and text query', () async {
      final allResults = await db.searchVault(query: '');
      expect(allResults, isNotEmpty);

      final taskResults = await db.searchVault(query: 'prototype', tasksOnly: true);
      expect(taskResults, hasLength(1));
      expect(taskResults.first.matchType, 'task');
      expect(taskResults.first.snippet, 'Initial prototype');

      final contextResults = await db.searchVault(query: '', contextFilter: 'computer');
      expect(contextResults, hasLength(1));
      expect(contextResults.first.snippet, contains('Design Review'));

      final docTypeResults = await db.searchVault(query: '', docTypeFilter: 'project');
      expect(docTypeResults.any((r) => r.document.relPath == 'projects/alpha.md'), isTrue);
    });
  });
}
