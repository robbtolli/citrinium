import 'dart:io';

import 'package:citrine_core/citrine_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../clock/app_clock.dart';
import '../workspace/workspace_state.dart';
import 'app_services.dart';

/// The full document list, per `docs/milestones/m0.md` W4's "document list
/// stream" -- reactive over `IndexDatabase` (see `IndexService.
/// watchAllDocuments`), which is itself kept current by the vault watcher
/// wired up in `openAppServices`. Empty (not an error) while no vault is
/// chosen yet.
final documentListProvider = StreamProvider<List<Document>>((ref) async* {
  final services = await ref.watch(appServicesProvider.future);
  if (services == null) {
    yield const [];
    return;
  }
  yield* services.indexService.watchAllDocuments();
});

/// The entries indexed for one document (`docs/milestones/m0.md` W4's
/// "entries stream"), keyed by `documents.id`.
final entriesForDocumentProvider = StreamProvider.family<List<Entry>, int>((
  ref,
  documentId,
) async* {
  final services = await ref.watch(appServicesProvider.future);
  if (services == null) {
    yield const [];
    return;
  }
  yield* services.indexService.watchEntriesForDocument(documentId);
});

/// All indexed entries across the vault joined with their owning [Document],
/// `@contexts`, and `#tags` (`D-01`, `D-19`).
final allEntriesWithDocumentsProvider =
    StreamProvider<List<IndexedEntryWithDocument>>((ref) async* {
  final services = await ref.watch(appServicesProvider.future);
  if (services == null) {
    yield const [];
    return;
  }
  yield* services.indexService.watchAllEntriesWithDocuments();
});

/// Incoming wikilinks pointing to a target `documentId` (`N-02`, `D-12`).
final backlinksForDocumentProvider =
    StreamProvider.family<List<BacklinkItem>, int>((
  ref,
  targetDocumentId,
) async* {
  final services = await ref.watch(appServicesProvider.future);
  if (services == null) {
    yield const [];
    return;
  }
  yield* services.indexService.watchBacklinksForDocument(targetDocumentId);
});

/// Unlinked mentions of a document's title or basename across other vault notes (`N-02`, `D-12`).
final unlinkedMentionsProvider =
    FutureProvider.family<List<UnlinkedMentionItem>, Document>((
  ref,
  document,
) async {
  final services = await ref.watch(appServicesProvider.future);
  if (services == null) return const [];
  return services.indexService.findUnlinkedMentionsForDocument(document);
});

/// Summary counts for the settings screen.
final indexStatsProvider = StreamProvider<IndexStats?>((ref) async* {
  final services = await ref.watch(appServicesProvider.future);
  if (services == null) {
    yield null;
    return;
  }
  yield* services.indexService.watchStats();
});

/// Stream of literal file content for [relPath], yielding initial text from disk
/// and subsequent updates whenever the vault watcher detects an external change to [relPath].
final documentRawTextProvider =
    StreamProvider.autoDispose.family<String, String>((
  ref,
  relPath,
) async* {
  final services = await ref.watch(appServicesProvider.future);
  if (services == null) {
    throw StateError('No vault selected');
  }

  final absolutePath = VaultPath(relPath).toAbsolute(services.vaultPath);
  final file = File(absolutePath);

  try {
    if (await file.exists()) {
      final contents = await readVaultFile(file);
      yield contents.text;
    }
  } on FileSystemException {
    // Handled gracefully if file is concurrently modified or deleted
  }

  final targetNormalized = VaultPath(relPath).value;

  await for (final event in services.watcher.events) {
    if (event.path.value == relPath || event.path.value == targetNormalized) {
      try {
        if (await file.exists()) {
          final contents = await readVaultFile(file);
          yield contents.text;
        }
      } on FileSystemException {
        // Handled gracefully if file is deleted concurrently
      }
    }
  }
});

/// Triggers a full index rebuild (the W4 "Rebuild index" button) and
/// returns its stats; throws if no vault is open.
Future<IndexRebuildStats> rebuildIndex(WidgetRef ref) async {
  final services = await ref.read(appServicesProvider.future);
  if (services == null) {
    throw StateError('No vault selected');
  }
  return services.indexService.fullRebuild();
}

/// High-level vault mutation service for Quick Capture (`C-01`–`C-04`),
/// In-Place Task Editing (`D-19`, `B-05`), Migration (`B-06`), Clarify (`G-01`),
/// and Note/Collection promotion (`B-10`).
///
/// Every method writes atomically to the underlying `.md` file on disk,
/// suppresses watcher echo, and immediately refreshes that file in
/// `IndexService` + invalidates `documentRawTextProvider` so open editors and
/// task lists stay in sync instantaneously.
class VaultMutationService {
  VaultMutationService(this._ref);

  final Ref _ref;

  Future<AppServices> _requireServices() async {
    final services = await _ref.read(appServicesProvider.future);
    if (services == null) {
      throw StateError('No vault selected');
    }
    return services;
  }

  Future<void> _notifyFileUpdated(AppServices services, String relPath) async {
    await services.indexService.refreshFile(relPath);
    if (!_ref.mounted) return;
    _ref.invalidate(documentRawTextProvider(relPath));
  }

  /// Appends a captured rapid-log line to either Today's Daily Log
  /// (`daily/YYYY-MM-DD.md`) or `inbox.md` (`C-01`, `C-02`, `C-03`).
  Future<String> captureLine({
    required String rawInput,
    required bool toTodayLog,
    String defaultPrefix = '- [ ] ',
    DateTime? now,
  }) async {
    final services = await _requireServices();
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return '';

    final hasBulletPrefix = RegExp(r'^[-*+]\s+').hasMatch(trimmed);
    final formattedLine = hasBulletPrefix ? trimmed : '$defaultPrefix$trimmed';

    final effectiveNow = now ?? _ref.read(appClockProvider).now();
    final relPath = toTodayLog
        ? CadenceFiles.dailyRelPath(effectiveNow)
        : CadenceFiles.inboxRelPath;
    final initialContent = toTodayLog
        ? CadenceFiles.defaultContentForCadence(
            CadenceKind.daily,
            effectiveNow,
            vaultRootPath: services.vaultPath,
          )
        : CadenceFiles.defaultInboxContent();

    await CadenceFiles.appendLineToVaultFile(
      vaultRootPath: services.vaultPath,
      relPath: relPath,
      lineText: formattedLine,
      initialContentIfMissing: initialContent,
      watcher: services.watcher,
    );
    await _notifyFileUpdated(services, relPath);
    return relPath;
  }

  /// Appends [lineText] directly to an existing or new [relPath] document.
  Future<void> appendLineToDocument({
    required String relPath,
    required String lineText,
    String initialContentIfMissing = '',
  }) async {
    final services = await _requireServices();
    await CadenceFiles.appendLineToVaultFile(
      vaultRootPath: services.vaultPath,
      relPath: relPath,
      lineText: lineText,
      initialContentIfMissing: initialContentIfMissing,
      watcher: services.watcher,
    );
    await _notifyFileUpdated(services, relPath);
  }

  /// Lazily ensures the cadence file for [cadence] at [date] exists on disk and
  /// returns its relative path (`B-09`, `D-11`).
  Future<String> ensureCadenceDocument(
    CadenceKind cadence,
    DateTime date, {
    bool includeStarterTutorial = false,
  }) async {
    final services = await _requireServices();
    final enabledCadences = _ref.read(workspaceStateProvider).enabledCadences;
    final relPath = CadenceFiles.relPathForCadence(cadence, date);
    final initialContent = CadenceFiles.defaultContentForCadence(
      cadence,
      date,
      vaultRootPath: services.vaultPath,
      enabledCadences: enabledCadences,
      includeStarterTutorial: includeStarterTutorial,
    );
    await CadenceFiles.ensureVaultFile(
      vaultRootPath: services.vaultPath,
      relPath: relPath,
      initialContent: initialContent,
      watcher: services.watcher,
    );
    await _notifyFileUpdated(services, relPath);
    return relPath;
  }

  /// Reads the current template (custom or built-in default) for [cadence] (`B-11`).
  Future<({String text, bool isCustom})> readCadenceTemplate(
    CadenceKind cadence,
  ) async {
    final services = await _requireServices();
    final enabledCadences = _ref.read(workspaceStateProvider).enabledCadences;
    final isCustom = CadenceFiles.hasCustomTemplate(
      vaultRootPath: services.vaultPath,
      cadence: cadence,
    );
    final text = CadenceFiles.readTemplateForCadence(
      vaultRootPath: services.vaultPath,
      cadence: cadence,
      enabledCadences: enabledCadences,
    );
    return (text: text, isCustom: isCustom);
  }

  /// Saves a user-customized template for [cadence] (`B-11`).
  Future<void> saveCadenceTemplate(
    CadenceKind cadence,
    String templateText,
  ) async {
    final services = await _requireServices();
    await CadenceFiles.saveCustomTemplateForCadence(
      vaultRootPath: services.vaultPath,
      cadence: cadence,
      templateText: templateText,
      watcher: services.watcher,
    );
  }

  /// Resets the template for [cadence] back to the built-in default (`B-11`).
  Future<void> resetCadenceTemplate(CadenceKind cadence) async {
    final services = await _requireServices();
    await CadenceFiles.resetTemplateForCadence(
      vaultRootPath: services.vaultPath,
      cadence: cadence,
    );
  }

  /// Updates a task's checkbox state in-place inside its owning `.md` file (`D-19`, `B-05`).
  Future<void> setTaskStateInPlace(
    IndexedEntryWithDocument item,
    TaskStateKind newState,
  ) async {
    final services = await _requireServices();
    final relPath = item.document.relPath;
    await CadenceFiles.editVaultFileInPlace(
      vaultRootPath: services.vaultPath,
      relPath: relPath,
      watcher: services.watcher,
      transform: (doc) {
        if (item.entry.lineIndex >= doc.lines.length) return doc;
        final line = doc.lines[item.entry.lineIndex];
        if (line.kind == LineKind.task) {
          return doc.setTaskState(item.entry.lineIndex, newState);
        }
        return doc.convertToTask(item.entry.lineIndex, state: newState);
      },
    );
    await _notifyFileUpdated(services, relPath);
  }

  /// Completes a task in-place (`D-02`, `D-19`), or if the task is a recurring
  /// task/habit (`D-16`, `D-17`), logs habit completion and/or advances its
  /// `📅` date to the next scheduled occurrence without polluting the Markdown
  /// file with duplicate cloned rows (`D-15`).
  Future<String?> completeOrAdvanceTask(
    IndexedEntryWithDocument item, {
    DateTime? now,
  }) async {
    final currentNow = now ?? _ref.read(appClockProvider).now();
    final todayIso = NlDateParser.formatIsoDate(currentNow);
    final rule = RecurrenceRule.tryParse(item.entry.recurrenceRaw);

    if (item.isHabit) {
      await _ref
          .read(workspaceStateProvider.notifier)
          .toggleHabitCompletion(item.uniqueKey, todayIso);
    }

    if (rule != null && !item.isCompletedTask) {
      DateTime baseDate = currentNow;
      if (item.entry.dueDate != null) {
        final parts = item.entry.dueDate!.split('-');
        if (parts.length == 3) {
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final d = int.tryParse(parts[2]);
          if (y != null && m != null && d != null) {
            baseDate = DateTime(y, m, d);
          }
        }
      }
      final nextDate = rule.nextOccurrenceAfter(
        baseDate.isBefore(currentNow) ? currentNow : baseDate,
        anchorDate: baseDate,
      );
      final nextIso = NlDateParser.formatIsoDate(nextDate);
      await updateEntryInPlace(
        item,
        newState: TaskStateKind.open,
        dueDate: nextIso,
      );
      await _ref.read(workspaceStateProvider.notifier).clearSnooze(
        item.uniqueKey,
      );
      return nextIso;
    }

    final isDone = item.isCompletedTask;
    await setTaskStateInPlace(
      item,
      isDone ? TaskStateKind.open : TaskStateKind.completed,
    );
    if (!isDone) {
      await _ref.read(workspaceStateProvider.notifier).clearSnooze(
        item.uniqueKey,
      );
    }
    return null;
  }

  /// Edits an entry's text content, inline metadata (`📅`, `⏰`, `🔁`, `@context`,
  /// `#tag`), and/or indented child note/comment block (`D-14`, `D-18`) in-place
  /// inside its source `.md` file without navigating away (`D-19`).
  Future<void> updateEntryInPlace(
    IndexedEntryWithDocument item, {
    String? newContent,
    String? newChildNoteBody,
    TaskStateKind? newState,
    String? dueDate,
    bool clearDueDate = false,
    String? dueTime,
    bool clearDueTime = false,
    String? recurrence,
    bool clearRecurrence = false,
    String? addContext,
    String? removeContext,
    String? addTag,
    String? removeTag,
  }) async {
    final services = await _requireServices();
    final relPath = item.document.relPath;
    await CadenceFiles.editVaultFileInPlace(
      vaultRootPath: services.vaultPath,
      relPath: relPath,
      watcher: services.watcher,
      transform: (doc) {
        final idx = item.entry.lineIndex;
        if (idx < 0 || idx >= doc.lines.length) return doc;
        var updated = doc;

        if (newContent != null) {
          updated = updated.replaceEntryContent(idx, newContent);
        }
        if (newState != null) {
          if (updated.lines[idx].kind == LineKind.task) {
            updated = updated.setTaskState(idx, newState);
          } else {
            updated = updated.convertToTask(idx, state: newState);
          }
        }
        if (clearDueDate) {
          updated = updated.removeInlineField(idx, InlineMetadataKind.date);
        } else if (dueDate != null && dueDate.trim().isNotEmpty) {
          updated = updated.upsertInlineField(
            idx,
            InlineMetadataKind.date,
            dueDate.trim(),
          );
        }
        if (clearDueTime) {
          updated = updated.removeInlineField(idx, InlineMetadataKind.time);
        } else if (dueTime != null && dueTime.trim().isNotEmpty) {
          updated = updated.upsertInlineField(
            idx,
            InlineMetadataKind.time,
            dueTime.trim(),
          );
        }
        if (clearRecurrence) {
          updated = updated.removeInlineField(
            idx,
            InlineMetadataKind.recurrence,
          );
        } else if (recurrence != null && recurrence.trim().isNotEmpty) {
          final cleanRec =
              recurrence.trim().replaceFirst(RegExp(r'^🔁\s*'), '').trim();
          if (cleanRec.isNotEmpty) {
            updated = updated.upsertInlineField(
              idx,
              InlineMetadataKind.recurrence,
              cleanRec,
            );
          }
        }
        if (removeContext != null) {
          updated = updated.removeInlineField(
            idx,
            InlineMetadataKind.context,
            value: removeContext,
          );
        }
        if (addContext != null && addContext.trim().isNotEmpty) {
          final clean = addContext.trim().replaceFirst(RegExp(r'^@+'), '');
          if (clean.isNotEmpty) {
            updated = updated.upsertInlineField(
              idx,
              InlineMetadataKind.context,
              clean,
            );
          }
        }
        if (removeTag != null) {
          updated = updated.removeInlineField(
            idx,
            InlineMetadataKind.tag,
            value: removeTag,
          );
        }
        if (addTag != null && addTag.trim().isNotEmpty) {
          final clean = addTag.trim().replaceFirst(RegExp(r'^#+'), '');
          if (clean.isNotEmpty) {
            updated = updated.upsertInlineField(
              idx,
              InlineMetadataKind.tag,
              clean,
            );
          }
        }
        if (newChildNoteBody != null) {
          updated = updated.replaceChildBlockText(idx, newChildNoteBody);
        }
        return updated;
      },
    );
    await _notifyFileUpdated(services, relPath);
  }

  /// Moves or schedules [item] into [targetRelPath]:
  /// removes or cancels the line in the source file, and appends a fresh `- [ ] ...` line to
  /// [targetRelPath] with the scheduled date if applicable.
  Future<void> migrateOrScheduleEntry(
    IndexedEntryWithDocument item, {
    required String targetRelPath,
    required String targetInitialContent,
    TaskStateKind sourceMarker = TaskStateKind.cancelled,
    String? overrideDueDate,
  }) async {
    final services = await _requireServices();
    final sourceRelPath = item.document.relPath;

    // 1. If moving to another file, remove the line from the source file
    if (sourceRelPath != targetRelPath) {
      await CadenceFiles.editVaultFileInPlace(
        vaultRootPath: services.vaultPath,
        relPath: sourceRelPath,
        watcher: services.watcher,
        transform: (doc) => doc.removeLine(item.entry.lineIndex),
      );
      await _notifyFileUpdated(services, sourceRelPath);

      // 2. Append clean open task line to target file
      var textToCopy = item.entry.textContent.trim();
      var tempDoc = MarkdownDocument.parse('- [ ] $textToCopy');
      if (overrideDueDate != null && overrideDueDate.isNotEmpty) {
        tempDoc = tempDoc.upsertInlineField(
          0,
          InlineMetadataKind.date,
          overrideDueDate,
        );
      }
      await CadenceFiles.appendLineToVaultFile(
        vaultRootPath: services.vaultPath,
        relPath: targetRelPath,
        lineText: tempDoc.rawText.trimRight(),
        initialContentIfMissing: targetInitialContent,
        watcher: services.watcher,
      );
      await _notifyFileUpdated(services, targetRelPath);
    } else if (overrideDueDate != null && overrideDueDate.isNotEmpty) {
      // Same file: simply update due date
      await updateEntryInPlace(item, dueDate: overrideDueDate);
    }
  }

  /// Creates a new standalone Note, Collection, or Project file (`N-01`, `D-03`,
  /// `D-10`, `G-03`) and optionally promotes [sourceEntry] into a `[[Wikilink]]`
  /// pointing to the new file (`B-10`).
  Future<String> createNoteOrProject({
    required String title,
    required String docType, // 'note' | 'project' | 'collection' | 'areaOfFocus'
    String? folder,
    String? outcome,
    String? firstNextAction,
    String? initialBody,
    IndexedEntryWithDocument? promoteFromEntry,
  }) async {
    final services = await _requireServices();
    final safeSlug = CadenceFiles.slugifyTitle(title);
    final dirPrefix = (folder != null && folder.trim().isNotEmpty)
        ? '${folder.trim()}/'
        : (docType == 'project'
              ? 'projects/'
              : docType == 'collection'
              ? 'collections/'
              : '');
    final relPath = '$dirPrefix$safeSlug.md';

    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('title: "${title.replaceAll('"', '\\"')}"');
    buffer.writeln('citrine:');
    buffer.writeln('  type: $docType');
    if (docType == 'project') {
      buffer.writeln('  status: active');
      if (outcome != null && outcome.trim().isNotEmpty) {
        buffer.writeln('  outcome: "${outcome.trim().replaceAll('"', '\\"')}"');
      }
    }
    buffer.writeln('---');
    buffer.writeln('# $title\n');
    if (outcome != null && outcome.trim().isNotEmpty) {
      buffer.writeln('> **Outcome:** ${outcome.trim()}\n');
    }
    if (firstNextAction != null && firstNextAction.trim().isNotEmpty) {
      buffer.writeln('## Next Actions');
      buffer.writeln('- [ ] ${firstNextAction.trim()}\n');
    }
    if (initialBody != null && initialBody.trim().isNotEmpty) {
      buffer.writeln(initialBody.trim());
    }

    await CadenceFiles.ensureVaultFile(
      vaultRootPath: services.vaultPath,
      relPath: relPath,
      initialContent: buffer.toString(),
      watcher: services.watcher,
    );
    await _notifyFileUpdated(services, relPath);

    if (promoteFromEntry != null) {
      await updateEntryInPlace(
        promoteFromEntry,
        newContent: '[[$safeSlug]] — ${promoteFromEntry.entry.textContent}',
      );
    }

    return relPath;
  }

  /// Files a non-actionable inbox item to Reference (`reference.md`, `D-07`,
  /// `G-01`, `G-06`) as a clean BuJo note line (`- – ...`) without converting
  /// it into a task, and marks the original inbox line as migrated (`[>]`).
  Future<String> fileToReference(
    IndexedEntryWithDocument item, {
    String targetRelPath = CadenceFiles.referenceRelPath,
  }) async {
    final services = await _requireServices();
    final cleanText = item.entry.textContent.trim();

    await CadenceFiles.appendLineToVaultFile(
      vaultRootPath: services.vaultPath,
      relPath: targetRelPath,
      lineText: '- – $cleanText',
      initialContentIfMissing: CadenceFiles.defaultReferenceContent(),
      watcher: services.watcher,
    );
    await _notifyFileUpdated(services, targetRelPath);

    if (item.document.relPath != targetRelPath) {
      await CadenceFiles.editVaultFileInPlace(
        vaultRootPath: services.vaultPath,
        relPath: item.document.relPath,
        watcher: services.watcher,
        transform: (doc) => doc.removeLine(item.entry.lineIndex),
      );
      await _notifyFileUpdated(services, item.document.relPath);
    }
    return targetRelPath;
  }

  /// Delegates an item to Waiting For (`- [w] ...`, `D-06`, `G-01`) with a
  /// person/system name and an optional follow-up date (`📅 YYYY-MM-DD`).
  Future<void> delegateToWaitingFor(
    IndexedEntryWithDocument item, {
    required String delegateTo,
    String? followUpDate,
  }) async {
    final cleanWho = delegateTo.trim();
    var updatedContent = item.entry.textContent.trim();
    if (cleanWho.isNotEmpty && !updatedContent.contains('Waiting on:')) {
      updatedContent = '$updatedContent (Waiting on: $cleanWho)';
    }
    await updateEntryInPlace(
      item,
      newState: TaskStateKind.waitingFor,
      newContent: updatedContent,
      dueDate: (followUpDate != null && followUpDate.trim().isNotEmpty)
          ? followUpDate.trim()
          : null,
    );
  }

  /// Rewrites the line at [lineIndex] in [sourceRelPath] by wrapping [keyword] in `[[targetTitleOrPath|keyword]]`
  /// (or `[[targetTitleOrPath]]` if same), saving atomically to disk (`N-02`, `D-12`).
  Future<void> linkMention({
    required String sourceRelPath,
    required int lineIndex,
    required String keyword,
    required String targetTitleOrPath,
  }) async {
    final services = await _requireServices();
    final file = File(VaultPath(sourceRelPath).toAbsolute(services.vaultPath));
    if (!await file.exists()) return;

    final contents = await readVaultFile(file);
    final lines = contents.text.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return;

    final targetName = targetTitleOrPath.replaceAll('.md', '');
    final replacement = targetName.toLowerCase() == keyword.toLowerCase()
        ? '[[$targetName]]'
        : '[[$targetName|$keyword]]';

    final line = lines[lineIndex];
    final pattern = RegExp(
      r'\[\[([^\]]*?)\]\]|' + RegExp.escape(keyword),
      caseSensitive: false,
    );

    var replaced = false;
    final updatedLine = line.replaceAllMapped(pattern, (match) {
      if (replaced) return match.group(0)!;
      final m = match.group(0)!;
      if (m.startsWith('[[') && m.endsWith(']]')) return m;
      replaced = true;
      return replacement;
    });

    lines[lineIndex] = updatedLine;
    services.watcher.suppressSelfWrite(VaultPath(file.path));
    await writeVaultFileAtomic(
      file,
      VaultFileContents(text: lines.join('\n'), hadBom: contents.hadBom),
    );
    await _notifyFileUpdated(services, sourceRelPath);
  }

  /// Writes all user-authored plans, priorities, and reflections from a
  /// completed [RitualSessionOutput] as clean Markdown sections directly into
  /// the cadence's `.md` log file (`P-11`, `D-15`), plus any tomorrow/next-horizon
  /// bridge task if specified.
  Future<String> commitRitualSessionOutput({
    required RitualSessionOutput output,
    required DateTime now,
    String? overrideTargetRelPath,
  }) async {
    final services = await _requireServices();
    final cadence = output.ritualKind.cadence;
    final enabledCadences = _ref.read(workspaceStateProvider).enabledCadences;
    final targetRelPath =
        overrideTargetRelPath ?? CadenceFiles.relPathForCadence(cadence, now);
    final initialContent = CadenceFiles.defaultContentForCadence(
      cadence,
      now,
      vaultRootPath: services.vaultPath,
      enabledCadences: enabledCadences,
    );

    await CadenceFiles.ensureVaultFile(
      vaultRootPath: services.vaultPath,
      relPath: targetRelPath,
      initialContent: initialContent,
      watcher: services.watcher,
    );

    final mdLines = output.toMarkdownLines();
    for (final line in mdLines) {
      await CadenceFiles.appendLineToVaultFile(
        vaultRootPath: services.vaultPath,
        relPath: targetRelPath,
        lineText: line,
        initialContentIfMissing: initialContent,
        watcher: services.watcher,
      );
    }
    await _notifyFileUpdated(services, targetRelPath);

    // If Evening Shutdown specified Tomorrow's #1 Priority Lock, also seed it
    // into tomorrow's Daily Log so it greets the user in the morning!
    if (output.tomorrowTopPriority.trim().isNotEmpty) {
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowRel = CadenceFiles.dailyRelPath(tomorrow);
      final tomorrowInit = CadenceFiles.defaultContentForCadence(
        CadenceKind.daily,
        tomorrow,
        vaultRootPath: services.vaultPath,
        enabledCadences: enabledCadences,
      );
      final raw = output.tomorrowTopPriority.trim();
      final prefix = RegExp(r'^[-*+]\s+').hasMatch(raw) ? raw : '- [ ] $raw';
      await CadenceFiles.appendLineToVaultFile(
        vaultRootPath: services.vaultPath,
        relPath: tomorrowRel,
        lineText: prefix,
        initialContentIfMissing: tomorrowInit,
        watcher: services.watcher,
      );
      await _notifyFileUpdated(services, tomorrowRel);
    }

    // If a higher-horizon review defined a bridge action for the next lower
    // cadence (e.g. Yearly -> Quarterly, or Quarterly -> Weekly), append it
    // there too (`QY-04`).
    if (output.bridgeActionForNextLowerCadence.trim().isNotEmpty) {
      final idx = CadenceFiles.datedHierarchy.indexOf(cadence);
      if (idx > 0) {
        CadenceKind? lowerTarget;
        for (var i = idx - 1; i >= 0; i--) {
          final candidate = CadenceFiles.datedHierarchy[i];
          if (enabledCadences.contains(candidate)) {
            lowerTarget = candidate;
            break;
          }
        }
        lowerTarget ??= CadenceFiles.datedHierarchy[idx - 1];
        final lowerRel = CadenceFiles.relPathForCadence(lowerTarget, now);
        final lowerInit = CadenceFiles.defaultContentForCadence(
          lowerTarget,
          now,
          vaultRootPath: services.vaultPath,
          enabledCadences: enabledCadences,
        );
        final rawBridge = output.bridgeActionForNextLowerCadence.trim();
        final line = RegExp(r'^[-*+]\s+').hasMatch(rawBridge)
            ? rawBridge
            : '- [ ] $rawBridge';
        await CadenceFiles.appendLineToVaultFile(
          vaultRootPath: services.vaultPath,
          relPath: lowerRel,
          lineText: line,
          initialContentIfMissing: lowerInit,
          watcher: services.watcher,
        );
        await _notifyFileUpdated(services, lowerRel);
      }
    }

    return targetRelPath;
  }

  /// Writes `.citrine/process_config.json` into the active vault so custom
  /// process configurations travel with the vault (`P-11`, `T-02`).
  Future<void> syncPortableProcessConfigToVault() async {
    final services = await _ref.read(appServicesProvider.future);
    if (services == null) return;
    final ws = _ref.read(workspaceStateProvider);
    await PlanningPresetCatalog.savePortableConfigToVault(
      vaultRootPath: services.vaultPath,
      configs: {
        for (final r in RitualKind.values) r: ws.configForRitual(r),
      },
      guidanceEnabled: ws.guidanceEnabled,
      learningStage: ws.learningStage,
      watcher: services.watcher,
    );
  }
}

final vaultMutationProvider = Provider<VaultMutationService>((ref) {
  return VaultMutationService(ref);
});
