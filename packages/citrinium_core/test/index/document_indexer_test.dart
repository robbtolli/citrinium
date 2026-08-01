import 'package:citrinium_core/index.dart';
import 'package:citrinium_core/parser.dart';
import 'package:test/test.dart';

ScannedDocument _index(String rawText, {String relPath = 'note.md'}) {
  return buildScannedDocument(
    relPath: relPath,
    sha256: 'irrelevant-for-this-test',
    mtimeMs: 0,
    sizeBytes: rawText.length,
    doc: MarkdownDocument.parse(rawText),
  );
}

void main() {
  group('buildScannedDocument', () {
    test('maps a task line to a task entry with state/metadata', () {
      final scanned = _index(
        '- [ ] Call pharmacy 📅 2026-08-01 ⏰17:00 @phone #waiting-for/dr-lee ^t7f3a2b\n',
      );

      expect(scanned.entries, hasLength(1));
      final entry = scanned.entries.single;
      expect(entry.kind, 'task');
      expect(entry.taskState, 'open');
      // `text` is the verbatim content span (metadata included, not
      // stripped) -- inline metadata lives *inside* the rapid-log line by
      // design (`design.md` §3.2), not in a separate description field.
      expect(
        entry.text,
        'Call pharmacy 📅 2026-08-01 ⏰17:00 @phone #waiting-for/dr-lee ^t7f3a2b',
      );
      expect(entry.dueDate, '2026-08-01');
      expect(entry.dueTime, '17:00');
      expect(entry.contexts, ['phone']);
      expect(entry.tags, ['waiting-for/dr-lee']);
      expect(entry.blockId, 't7f3a2b');
    });

    test('preserves unknown task markers verbatim', () {
      final scanned = _index('- [?] Something custom\n');
      expect(scanned.entries.single.taskState, 'unknown:?');
    });

    test('maps completed/migrated/dropped/waiting-for states', () {
      final scanned = _index('''
- [x] done
- [>] migrated
- [<] scheduled
- [-] dropped
- [w] waiting
- [/] in progress
''');
      final states = scanned.entries.map((e) => e.taskState).toList();
      expect(states, [
        'completed',
        'migrated',
        'scheduled',
        'dropped',
        'waitingFor',
        'inProgress',
      ]);
    });

    test('maps BuJo event/note lines', () {
      final scanned = _index(
        '- ○ Dentist appointment 📅 2026-08-03\n- – Idea: batch refills\n',
      );
      expect(scanned.entries, hasLength(2));
      expect(scanned.entries[0].kind, 'event');
      expect(scanned.entries[0].text, 'Dentist appointment 📅 2026-08-03');
      expect(scanned.entries[0].dueDate, '2026-08-03');
      // (this one has no trailing metadata, so verbatim == the "clean" text)
      expect(scanned.entries[1].kind, 'note');
      expect(scanned.entries[1].text, 'Idea: batch refills');
    });

    test('maps a plain bullet with no signifier to an untyped entry', () {
      final scanned = _index('- just a thought, not yet clarified\n');
      expect(scanned.entries.single.kind, 'untyped');
      expect(scanned.entries.single.text, 'just a thought, not yet clarified');
    });

    test('does not index prose, headings, or blank lines as entries', () {
      final scanned = _index('# Heading\n\nSome prose.\n');
      expect(scanned.entries, isEmpty);
    });

    test('does not index lines inside a code fence, even if task-shaped', () {
      final scanned = _index('```\n- [ ] not a real task\n```\n');
      expect(scanned.entries, isEmpty);
    });

    test('extracts wikilinks with correlated source line index', () {
      final scanned = _index('- [ ] See [[Project X]] for details\n');
      expect(scanned.links, hasLength(1));
      final link = scanned.links.single;
      expect(link.targetRaw, 'Project X');
      expect(link.kind, 'wikilink');
      expect(link.sourceLineIndex, 0);
    });

    test('embeds are distinguished from plain wikilinks', () {
      final scanned = _index('![[diagram.png]]\n');
      expect(scanned.links.single.kind, 'embed');
    });

    test('a link on a prose line has a null sourceLineIndex', () {
      final scanned = _index('See [[Some Note]] for context.\n');
      expect(scanned.links.single.sourceLineIndex, isNull);
    });

    test('derives title from an H1 heading when there is no frontmatter', () {
      final scanned = _index('# My Title\n\nBody.\n');
      expect(scanned.title, 'My Title');
    });

    test('derives title from the filename when there is no heading', () {
      final scanned = _index('just text\n', relPath: 'Projects/citrinium.md');
      expect(scanned.title, '');
    });

    test('frontmatter title/citrinium.type win over heading/filename', () {
      final scanned = _index('''
---
title: Explicit Title
citrinium:
  type: project
---
# Different Heading
''');
      expect(scanned.title, 'Explicit Title');
      expect(scanned.docType, 'project');
      expect(scanned.frontmatterJson, contains('"type":"project"'));
    });

    test('defaults docType to note when there is no citrinium.type', () {
      final scanned = _index('# Just a note\n');
      expect(scanned.docType, 'note');
    });
  });
}
