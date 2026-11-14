import 'dart:io';

import 'package:citrine_core/citrine_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late IndexDatabase db;
  late TaskSyncService syncService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('citrine_task_sync_test_');
    db = IndexDatabase.memory();
    syncService = TaskSyncService(
      db: db,
      vaultRootPath: tempDir.path,
      nowProvider: () => DateTime.utc(2026, 11, 14, 12, 0),
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('tagAndSaveMarkdownTask appends comment and stores offset hint', () async {
    final file = File(p.join(tempDir.path, 'daily', '2026-11-14.md'));
    await file.create(recursive: true);
    await file.writeAsString('# Today\n- [ ] Buy milk 📅 2026-11-14 @errands\n');

    final record = await syncService.tagAndSaveMarkdownTask(
      relPath: 'daily/2026-11-14.md',
      lineIndex: 1,
    );

    expect(record, isNotNull);
    expect(record!.sourceRelPath, 'daily/2026-11-14.md');
    expect(record.sourceByteOffset, 8); // '# Today\n' is 8 bytes
    expect(record.taskState, TaskStateKind.open.name);
    expect(record.textContent, 'Buy milk 📅 2026-11-14 @errands');
    expect(record.dueDate, '2026-11-14');

    final diskText = await file.readAsString();
    expect(
      diskText,
      '# Today\n- [ ] Buy milk 📅 2026-11-14 @errands <!-- citrine:task=${record.taskId} -->\n',
    );
  });

  test('createDatabaseTask creates DB-only task with null source fields', () async {
    final record = await syncService.createDatabaseTask(
      text: 'Plan Q4 roadmap',
      horizon: 'quarterly',
    );

    expect(record.sourceRelPath, isNull);
    expect(record.sourceByteOffset, isNull);
    expect(record.taskState, TaskStateKind.open.name);
    expect(record.textContent, 'Plan Q4 roadmap');
    expect(record.horizon, 'quarterly');
  });

  test('updateTask uses fast hint, falls back to scan, and detaches if missing', () async {
    final file = File(p.join(tempDir.path, 'notes.md'));
    await file.writeAsString('# Notes\n- [ ] Draft spec\n');

    final created = await syncService.tagAndSaveMarkdownTask(
      relPath: 'notes.md',
      lineIndex: 1,
    );
    expect(created, isNotNull);
    final taskId = created!.taskId;

    // 1. Fast-hint update
    final completed = await syncService.updateTask(
      taskId: taskId,
      state: TaskStateKind.completed,
    );
    expect(completed!.taskState, TaskStateKind.completed.name);
    expect(
      await file.readAsString(),
      '# Notes\n- [x] Draft spec <!-- citrine:task=$taskId -->\n',
    );

    // 2. Shift byte offset externally so hint is stale, verify full-file scan fallback
    await file.writeAsString(
      '# Notes\nExtra paragraph added above\n- [x] Draft spec <!-- citrine:task=$taskId -->\n',
    );
    final reopened = await syncService.updateTask(
      taskId: taskId,
      state: TaskStateKind.open,
      text: 'Draft final spec',
    );
    expect(reopened!.sourceRelPath, 'notes.md');
    expect(reopened.sourceByteOffset, isNot(created.sourceByteOffset));
    expect(
      await file.readAsString(),
      '# Notes\nExtra paragraph added above\n- [ ] Draft final spec <!-- citrine:task=$taskId -->\n',
    );

    // 3. Remove comment externally -> task detaches gracefully to DB-only
    await file.writeAsString('# Notes\nNo tasks here anymore\n');
    final detached = await syncService.updateTask(
      taskId: taskId,
      state: TaskStateKind.completed,
    );
    expect(detached!.sourceRelPath, isNull);
    expect(detached.sourceByteOffset, isNull);
    expect(detached.taskState, TaskStateKind.completed.name);
  });

  test('syncExternalFileTasks updates tagged tasks and reports untagged lines', () async {
    final file = File(p.join(tempDir.path, 'inbox.md'));
    await file.writeAsString(
      '- [ ] Tagged task <!-- citrine:task=t_existing_1 -->\n'
      '- [ ] Untagged task one\n'
      '- [x] Untagged task two\n',
    );

    final scan = await syncService.syncExternalFileTasks('inbox.md');
    expect(scan.taggedSyncedCount, 1);
    expect(scan.untaggedLineIndices, [1, 2]);

    final tagged = await syncService.getTask('t_existing_1');
    expect(tagged, isNotNull);
    expect(tagged!.textContent, 'Tagged task');
    expect(tagged.sourceRelPath, 'inbox.md');

    final importedCount = await syncService.importUntaggedTasksInFiles(['inbox.md']);
    expect(importedCount, 2);

    final allTasks = await syncService.listTasks();
    expect(allTasks.length, 3);

    final updatedContent = await file.readAsString();
    expect(citrineTaskCommentRegExp.allMatches(updatedContent).length, 3);
  });
}
