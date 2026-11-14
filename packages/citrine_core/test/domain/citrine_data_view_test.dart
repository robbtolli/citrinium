import 'package:citrine_core/citrine_core.dart';
import 'package:test/test.dart';

void main() {
  Document fakeDoc(
    String relPath, {
    int id = 1,
    String docType = 'note',
  }) =>
      Document(
        id: id,
        relPath: relPath,
        sha256: 'hash',
        mtimeMs: 0,
        sizeBytes: 100,
        docType: docType,
        title: relPath,
        indexedAtMs: 0,
      );

  IndexedEntryWithDocument makeItem({
    required int id,
    required String relPath,
    String docType = 'note',
    int lineIndex = 0,
    String kind = 'task',
    String taskState = 'open',
    String text = 'Sample item',
    String? dueDate,
    String? recurrenceRaw,
    List<String> contexts = const [],
    List<String> tags = const [],
  }) {
    return IndexedEntryWithDocument(
      entry: Entry(
        id: id,
        documentId: id,
        lineIndex: lineIndex,
        charStart: 0,
        charEnd: text.length,
        kind: kind,
        taskState: taskState,
        textContent: text,
        dueDate: dueDate,
        dueTime: null,
        recurrenceRaw: recurrenceRaw,
        signifier: null,
        blockId: null,
      ),
      document: fakeDoc(relPath, id: id, docType: docType),
      contexts: contexts,
      tags: tags,
    );
  }

  group('CitrineDataViewQuery & block parsing (B-01, B-02)', () {
    test('parses YAML-style key/value lines and round-trips via toMarkdownFence', () {
      const body = '''
view: tasks
filter: due-today
title: "Today's Tasks"
tag: #deepwork
context: @computer
include_overdue: true
limit: 5
''';
      final query = CitrineDataViewQuery.parse(body);
      expect(query.view, CitrineDataViewPreset.tasks);
      expect(query.filter, 'due-today');
      expect(query.title, "Today's Tasks");
      expect(query.tag, 'deepwork');
      expect(query.context, 'computer');
      expect(query.includeOverdue, isTrue);
      expect(query.limit, 5);
      expect(query.resolvedTitle, "Today's Tasks");

      final fenced = query.toMarkdownFence();
      final blocks = findCitrineDataViewBlocks(fenced);
      expect(blocks, hasLength(1));
      expect(blocks.single.query.filter, 'due-today');
      expect(blocks.single.query.includeOverdue, isTrue);
      expect(blocks.single.query.limit, 5);
    });

    test('findCitrineDataViewBlocks locates multiple blocks inside a daily note', () {
      const md = '''
# 2026-11-14

```citrine
view: top-focus
```

Some prose notes.

```citrine
view: tasks
filter: due-today
include_overdue: true
```
''';
      final blocks = findCitrineDataViewBlocks(md);
      expect(blocks, hasLength(2));
      expect(blocks[0].query.view, CitrineDataViewPreset.topFocus);
      expect(blocks[1].query.view, CitrineDataViewPreset.tasks);
      expect(blocks[1].query.filter, 'due-today');
      expect(blocks[1].query.includeOverdue, isTrue);
      expect(md.substring(blocks[0].startOffset, blocks[0].endOffset), startsWith('```citrine'));
    });

    test('evaluateCitrineDataView filters dueToday, overdue, createdToday, projects, and completed', () {
      final refDate = DateTime(2026, 11, 14);
      final entries = [
        makeItem(
          id: 1,
          relPath: 'daily/2026-11-14.md',
          lineIndex: 1,
          text: 'Due today task',
          dueDate: '2026-11-14',
          tags: const ['deepwork'],
        ),
        makeItem(
          id: 2,
          relPath: 'daily/2026-11-10.md',
          lineIndex: 2,
          text: 'Overdue task',
          dueDate: '2026-11-12',
        ),
        makeItem(
          id: 3,
          relPath: 'daily/2026-11-14.md',
          lineIndex: 3,
          text: 'Completed today task',
          taskState: 'completed',
          dueDate: '2026-11-14',
        ),
        makeItem(
          id: 4,
          relPath: 'projects/launch.md',
          docType: 'project',
          lineIndex: 4,
          text: 'Project next action',
          dueDate: '2026-11-18',
        ),
        makeItem(
          id: 5,
          relPath: 'daily/2026-11-14.md',
          lineIndex: 5,
          kind: 'event',
          taskState: '',
          text: 'Team sync',
          dueDate: '2026-11-14',
        ),
      ];

      final dueTodayOnly = evaluateCitrineDataView(
        query: const CitrineDataViewQuery(view: CitrineDataViewPreset.dueToday),
        allEntries: entries,
        referenceDate: refDate,
      );
      expect(dueTodayOnly.map((e) => e.entry.textContent), ['Due today task']);

      final duePlusOverdue = evaluateCitrineDataView(
        query: const CitrineDataViewQuery(
          view: CitrineDataViewPreset.dueToday,
          includeOverdue: true,
        ),
        allEntries: entries,
        referenceDate: refDate,
      );
      expect(
        duePlusOverdue.map((e) => e.entry.textContent),
        ['Due today task', 'Overdue task'],
      );

      final topFocus = evaluateCitrineDataView(
        query: const CitrineDataViewQuery(view: CitrineDataViewPreset.topFocus),
        allEntries: entries,
        referenceDate: refDate,
        pinnedFocusKeys: {'daily/2026-11-14.md:1'},
      );
      expect(topFocus.map((e) => e.entry.textContent), ['Due today task']);

      final projects = evaluateCitrineDataView(
        query: const CitrineDataViewQuery(view: CitrineDataViewPreset.projects),
        allEntries: entries,
        referenceDate: refDate,
      );
      expect(projects.map((e) => e.entry.textContent), ['Project next action']);

      final completedToday = evaluateCitrineDataView(
        query: const CitrineDataViewQuery(
          view: CitrineDataViewPreset.tasks,
          filter: 'completed-today',
          status: 'completed',
        ),
        allEntries: entries,
        referenceDate: refDate,
      );
      expect(
        completedToday.map((e) => e.entry.textContent),
        ['Completed today task'],
      );
    });
  });
}
