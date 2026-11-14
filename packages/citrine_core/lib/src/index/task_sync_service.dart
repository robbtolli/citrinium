import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../parser/inline_metadata.dart';
import '../parser/markdown_document.dart';
import '../parser/parsed_line.dart';
import '../parser/task_comment.dart';
import '../parser/task_state.dart';
import '../vault/path_normalization.dart';
import '../vault/vault_file_io.dart';
import '../vault/vault_watcher.dart';
import 'index_database.dart';

/// Result of scanning one Markdown file for tagged and untagged tasks.
class FileTaskScanResult {
  const FileTaskScanResult({
    required this.relPath,
    required this.taggedSyncedCount,
    required this.untaggedLineIndices,
  });

  final String relPath;
  final int taggedSyncedCount;
  final List<int> untaggedLineIndices;

  bool get hasUntaggedTasks => untaggedLineIndices.isNotEmpty;
}

/// Manages bidirectional synchronization between `tasks` in SQLite and
/// `<!-- citrine:task=<id> -->` comments in Markdown vault files (`P-11`,
/// `T-02`, `FR-04`, `FR-16`).
class TaskSyncService {
  TaskSyncService({
    required this.db,
    required this.vaultRootPath,
    this.watcher,
    DateTime Function()? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now;

  final IndexDatabase db;
  final String vaultRootPath;
  final VaultWatcher? watcher;
  final DateTime Function() _nowProvider;

  int _nowMs() => _nowProvider().toUtc().millisecondsSinceEpoch;

  File _fileForRelPath(String relPath) {
    final absPath = VaultPath(relPath).toAbsolute(vaultRootPath);
    return File(absPath);
  }

  /// Watches all canonical tasks in SQLite, ordered by `updated_at_ms` desc.
  Stream<List<TaskRecord>> watchAllTasks() {
    return (db.select(db.tasks)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAtMs)]))
        .watch();
  }

  /// Lists canonical tasks with optional filters.
  Future<List<TaskRecord>> listTasks({
    String? state,
    String? horizon,
    String? sourceRelPath,
    String? dueDate,
  }) {
    final query = db.select(db.tasks);
    if (state != null) {
      query.where((t) => t.taskState.equals(state));
    }
    if (horizon != null) {
      query.where((t) => t.horizon.equals(horizon));
    }
    if (sourceRelPath != null) {
      query.where((t) => t.sourceRelPath.equals(sourceRelPath));
    }
    if (dueDate != null) {
      query.where((t) => t.dueDate.equals(dueDate));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAtMs)]);
    return query.get();
  }

  /// Fetches a single task by [taskId], or null.
  Future<TaskRecord?> getTask(String taskId) {
    return (db.select(db.tasks)..where((t) => t.taskId.equals(taskId)))
        .getSingleOrNull();
  }

  /// Creates a database-only task (e.g. from the Citrine UI, CLI, or MCP) with
  /// `source_rel_path = NULL` and `source_byte_offset = NULL`.
  Future<TaskRecord> createDatabaseTask({
    required String text,
    TaskStateKind state = TaskStateKind.open,
    String? dueDate,
    String? dueTime,
    String? recurrenceRaw,
    List<String> contexts = const [],
    List<String> tags = const [],
    String? horizon,
    String? taskId,
  }) async {
    final id = taskId ?? generateCitrineTaskId();
    final now = _nowMs();
    final cleanText = stripCitrineTaskComment(text).trim();
    await db.into(db.tasks).insert(
      TasksCompanion.insert(
        taskId: id,
        sourceRelPath: const Value(null),
        sourceByteOffset: const Value(null),
        taskState: state.name,
        textContent: cleanText,
        dueDate: Value(dueDate),
        dueTime: Value(dueTime),
        recurrenceRaw: Value(recurrenceRaw),
        contextsJson: Value(jsonEncode(contexts)),
        tagsJson: Value(jsonEncode(tags)),
        horizon: Value(horizon),
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );
    return (await getTask(id))!;
  }

  /// Saves (and tags if untagged) the task at [lineIndex] in [relPath].
  ///
  /// Called when the user navigates away from a task line in a Markdown note:
  /// appends `<!-- citrine:task=<id> -->` to the line if missing, writes the
  /// file, and upserts `(task_id, source_rel_path, source_byte_offset)` in
  /// SQLite.
  Future<TaskRecord?> tagAndSaveMarkdownTask({
    required String relPath,
    required int lineIndex,
  }) async {
    final file = _fileForRelPath(relPath);
    if (!await file.exists()) return null;
    final contents = await readVaultFile(file);
    final doc = MarkdownDocument.parse(contents.text);
    if (lineIndex < 0 || lineIndex >= doc.lines.length) return null;

    final line = doc.lines[lineIndex];
    if (line.kind != LineKind.task) return null;

    final rawLineWithNewline = doc.rawText.substring(
      line.span.start,
      _lineEndIncludingNewline(doc.rawText, line.span.end),
    );
    final existingId = extractCitrineTaskId(rawLineWithNewline);
    final taskId = existingId ?? generateCitrineTaskId();
    final byteOffset = _utf8ByteOffsetAtChar(doc.rawText, line.span.start);

    if (existingId == null) {
      final updatedLine = upsertCitrineTaskCommentInLine(
        rawLineWithNewline,
        taskId,
      );
      final updatedText = doc.rawText.replaceRange(
        line.span.start,
        _lineEndIncludingNewline(doc.rawText, line.span.end),
        updatedLine,
      );
      watcher?.suppressSelfWrite(VaultPath(file.path));
      await writeVaultFileAtomic(
        file,
        VaultFileContents(text: updatedText, hadBom: contents.hadBom),
      );
    }

    return _upsertTaskFromParsedLine(
      taskId: taskId,
      relPath: relPath,
      byteOffset: byteOffset,
      line: line,
      rawText: doc.rawText,
    );
  }

  /// Updates a task in SQLite and, if `source_rel_path != null`, syncs the
  /// change back to the `.md` file using `(source_rel_path, source_byte_offset)`
  /// first, falling back to a full-file scan for `<!-- citrine:task=<id> -->`,
  /// or clearing `source_rel_path`/`source_byte_offset` (making the task
  /// DB-only) if the file or comment is missing.
  Future<TaskRecord?> updateTask({
    required String taskId,
    TaskStateKind? state,
    String? text,
    String? dueDate,
    bool clearDueDate = false,
    String? dueTime,
    bool clearDueTime = false,
    String? recurrenceRaw,
    bool clearRecurrence = false,
    String? horizon,
  }) async {
    final existing = await getTask(taskId);
    if (existing == null) return null;

    final nextState = state ??
        TaskStateKind.values.firstWhere(
          (e) => e.name == existing.taskState,
          orElse: () => TaskStateKind.open,
        );
    final nextText =
        text != null ? stripCitrineTaskComment(text).trim() : existing.textContent;
    final nextDueDate = clearDueDate ? null : (dueDate ?? existing.dueDate);
    final nextDueTime = clearDueTime ? null : (dueTime ?? existing.dueTime);
    final nextRecurrence =
        clearRecurrence ? null : (recurrenceRaw ?? existing.recurrenceRaw);
    final nextHorizon = horizon ?? existing.horizon;
    final now = _nowMs();

    var nextRelPath = existing.sourceRelPath;
    var nextByteOffset = existing.sourceByteOffset;

    if (nextRelPath != null) {
      final syncResult = await _syncTaskUpdateToMarkdown(
        taskId: taskId,
        relPath: nextRelPath,
        hintByteOffset: nextByteOffset,
        state: nextState,
        newText: text != null ? nextText : null,
      );
      if (syncResult == null) {
        // File or comment missing: detach gracefully to DB-only.
        nextRelPath = null;
        nextByteOffset = null;
      } else {
        nextByteOffset = syncResult;
      }
    }

    await (db.update(db.tasks)..where((t) => t.taskId.equals(taskId))).write(
      TasksCompanion(
        sourceRelPath: Value(nextRelPath),
        sourceByteOffset: Value(nextByteOffset),
        taskState: Value(nextState.name),
        textContent: Value(nextText),
        dueDate: Value(nextDueDate),
        dueTime: Value(nextDueTime),
        recurrenceRaw: Value(nextRecurrence),
        horizon: Value(nextHorizon),
        updatedAtMs: Value(now),
      ),
    );

    return getTask(taskId);
  }

  /// Syncs tagged tasks in [relPath] to SQLite and returns any untagged task
  /// line indices found in the file (`FR-16`).
  Future<FileTaskScanResult> syncExternalFileTasks(String relPath) async {
    final file = _fileForRelPath(relPath);
    if (!await file.exists()) {
      return FileTaskScanResult(
        relPath: relPath,
        taggedSyncedCount: 0,
        untaggedLineIndices: const [],
      );
    }

    final contents = await readVaultFile(file);
    final doc = MarkdownDocument.parse(contents.text);
    var taggedCount = 0;
    final untagged = <int>[];

    for (final line in doc.lines) {
      if (line.kind != LineKind.task) continue;
      final lineText = line.span.of(doc.rawText);
      final taskId = extractCitrineTaskId(lineText);
      if (taskId != null) {
        final byteOffset = _utf8ByteOffsetAtChar(doc.rawText, line.span.start);
        await _upsertTaskFromParsedLine(
          taskId: taskId,
          relPath: relPath,
          byteOffset: byteOffset,
          line: line,
          rawText: doc.rawText,
        );
        taggedCount++;
      } else {
        untagged.add(line.index);
      }
    }

    return FileTaskScanResult(
      relPath: relPath,
      taggedSyncedCount: taggedCount,
      untaggedLineIndices: untagged,
    );
  }

  /// Imports all untagged task lines across [relPaths], appending
  /// `<!-- citrine:task=<id> -->` comments to the files and saving the tasks
  /// into SQLite (`FR-16`).
  Future<int> importUntaggedTasksInFiles(
    List<String> relPaths, {
    void Function(int completedFiles, int totalFiles)? onProgress,
  }) async {
    var totalImported = 0;
    for (var i = 0; i < relPaths.length; i++) {
      final relPath = relPaths[i];
      final file = _fileForRelPath(relPath);
      if (await file.exists()) {
        final contents = await readVaultFile(file);
        var currentText = contents.text;
        var doc = MarkdownDocument.parse(currentText);
        var modified = false;

        // Walk from bottom to top so char offsets stay valid while splicing.
        for (var li = doc.lines.length - 1; li >= 0; li--) {
          final line = doc.lines[li];
          if (line.kind != LineKind.task) continue;
          final lineEnd = _lineEndIncludingNewline(currentText, line.span.end);
          final rawLine = currentText.substring(line.span.start, lineEnd);
          if (extractCitrineTaskId(rawLine) != null) continue;

          final taskId = generateCitrineTaskId();
          final updatedLine = upsertCitrineTaskCommentInLine(rawLine, taskId);
          currentText = currentText.replaceRange(
            line.span.start,
            lineEnd,
            updatedLine,
          );
          modified = true;
          totalImported++;
        }

        if (modified) {
          watcher?.suppressSelfWrite(VaultPath(file.path));
          await writeVaultFileAtomic(
            file,
            VaultFileContents(text: currentText, hadBom: contents.hadBom),
          );
          // Re-parse to compute exact final byte offsets and upsert into DB.
          doc = MarkdownDocument.parse(currentText);
          for (final line in doc.lines) {
            if (line.kind != LineKind.task) continue;
            final taskId = extractCitrineTaskId(line.span.of(currentText));
            if (taskId == null) continue;
            final byteOffset = _utf8ByteOffsetAtChar(
              currentText,
              line.span.start,
            );
            await _upsertTaskFromParsedLine(
              taskId: taskId,
              relPath: relPath,
              byteOffset: byteOffset,
              line: line,
              rawText: currentText,
            );
          }
        }
      }
      onProgress?.call(i + 1, relPaths.length);
    }
    return totalImported;
  }

  /// Syncs a task update back to [relPath] using [hintByteOffset] first, then
  /// falling back to a full-file scan for `<!-- citrine:task=<taskId> -->`.
  /// Returns the updated byte offset, or `null` if the file or comment is
  /// missing.
  Future<int?> _syncTaskUpdateToMarkdown({
    required String taskId,
    required String relPath,
    required int? hintByteOffset,
    required TaskStateKind state,
    required String? newText,
  }) async {
    final file = _fileForRelPath(relPath);
    if (!await file.exists()) return null;

    final contents = await readVaultFile(file);
    final rawText = contents.text;
    final doc = MarkdownDocument.parse(rawText);
    final needle = 'citrine:task=$taskId';

    ParsedLine? targetLine;
    // 1. Check fast byte-offset hint first.
    if (hintByteOffset != null) {
      final hintCharStart = _charOffsetAtUtf8Byte(rawText, hintByteOffset);
      if (hintCharStart != null) {
        for (final line in doc.lines) {
          if (line.span.start == hintCharStart) {
            final lineStr = line.span.of(rawText);
            if (lineStr.contains(needle) &&
                extractCitrineTaskId(lineStr) == taskId) {
              targetLine = line;
            }
            break;
          }
        }
      }
    }

    // 2. Fallback: full-file scan for `<!-- citrine:task=<id> -->`.
    if (targetLine == null) {
      for (final line in doc.lines) {
        final lineStr = line.span.of(rawText);
        if (lineStr.contains(needle) &&
            extractCitrineTaskId(lineStr) == taskId) {
          targetLine = line;
          break;
        }
      }
    }

    if (targetLine == null) return null;

    final lineEnd = _lineEndIncludingNewline(rawText, targetLine.span.end);
    final rawLine = rawText.substring(targetLine.span.start, lineEnd);
    final spliced = spliceTaskLine(
      line: rawLine,
      state: state,
      newText: newText,
      taskId: taskId,
    );
    final updatedText = rawText.replaceRange(
      targetLine.span.start,
      lineEnd,
      spliced,
    );
    watcher?.suppressSelfWrite(VaultPath(file.path));
    await writeVaultFileAtomic(
      file,
      VaultFileContents(text: updatedText, hadBom: contents.hadBom),
    );
    return _utf8ByteOffsetAtChar(updatedText, targetLine.span.start);
  }

  Future<TaskRecord> _upsertTaskFromParsedLine({
    required String taskId,
    required String relPath,
    required int byteOffset,
    required ParsedLine line,
    required String rawText,
  }) async {
    final existing = await getTask(taskId);
    final now = _nowMs();
    final taskInfo = line.task!;
    final cleanText = stripCitrineTaskComment(
      taskInfo.contentSpan.of(rawText),
    ).trim();

    String? dueDate;
    String? dueTime;
    String? recurrenceRaw;
    final contexts = <String>[];
    final tags = <String>[];

    for (final m in line.metadata) {
      switch (m.kind) {
        case InlineMetadataKind.date:
          dueDate ??= m.value;
        case InlineMetadataKind.time:
          dueTime ??= m.value;
        case InlineMetadataKind.recurrence:
          recurrenceRaw ??= m.value;
        case InlineMetadataKind.context:
          contexts.add(m.value);
        case InlineMetadataKind.tag:
          tags.add(m.value);
        case InlineMetadataKind.blockId:
          break;
      }
    }

    await db.into(db.tasks).insertOnConflictUpdate(
      TasksCompanion.insert(
        taskId: taskId,
        sourceRelPath: Value(relPath),
        sourceByteOffset: Value(byteOffset),
        taskState: taskInfo.stateKind.name,
        textContent: cleanText,
        dueDate: Value(dueDate),
        dueTime: Value(dueTime),
        recurrenceRaw: Value(recurrenceRaw),
        contextsJson: Value(jsonEncode(contexts)),
        tagsJson: Value(jsonEncode(tags)),
        horizon: Value(existing?.horizon),
        createdAtMs: existing?.createdAtMs ?? now,
        updatedAtMs: now,
      ),
    );

    return (await getTask(taskId))!;
  }

  int _lineEndIncludingNewline(String text, int spanEnd) {
    if (spanEnd >= text.length) return spanEnd;
    if (text[spanEnd] == '\r') {
      if (spanEnd + 1 < text.length && text[spanEnd + 1] == '\n') {
        return spanEnd + 2;
      }
      return spanEnd + 1;
    }
    if (text[spanEnd] == '\n') return spanEnd + 1;
    return spanEnd;
  }

  int _utf8ByteOffsetAtChar(String text, int charOffset) {
    if (charOffset <= 0) return 0;
    final clamped = charOffset > text.length ? text.length : charOffset;
    return utf8.encode(text.substring(0, clamped)).length;
  }

  int? _charOffsetAtUtf8Byte(String text, int targetByteOffset) {
    if (targetByteOffset < 0) return null;
    if (targetByteOffset == 0) return 0;
    final bytes = utf8.encode(text);
    if (targetByteOffset > bytes.length) return null;
    try {
      final prefix = utf8.decode(bytes.sublist(0, targetByteOffset));
      return prefix.length;
    } catch (_) {
      return null;
    }
  }
}
