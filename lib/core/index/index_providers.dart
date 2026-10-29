import 'dart:io';

import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  if (await file.exists()) {
    final contents = await readVaultFile(file);
    yield contents.text;
  }

  final targetNormalized = VaultPath(relPath).value;

  await for (final event in services.watcher.events) {
    if (event.path.value == relPath || event.path.value == targetNormalized) {
      if (await file.exists()) {
        final contents = await readVaultFile(file);
        yield contents.text;
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

    final effectiveNow = now ?? DateTime.now();
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
    final relPath = CadenceFiles.relPathForCadence(cadence, date);
    final initialContent = CadenceFiles.defaultContentForCadence(
      cadence,
      date,
      vaultRootPath: services.vaultPath,
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

  /// Edits an entry's text content, inline metadata (`📅`, `⏰`, `@context`,
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

  /// Migrates or schedules [item] into [targetRelPath] (`B-06`, `B-07`, `G-01`):
  /// marks the original line as [sourceMarker] (`[>]` migrated or `[<]`
  /// scheduled) in its source file, and appends a fresh `- [ ] ...` line to
  /// [targetRelPath].
  Future<void> migrateOrScheduleEntry(
    IndexedEntryWithDocument item, {
    required String targetRelPath,
    required String targetInitialContent,
    TaskStateKind sourceMarker = TaskStateKind.migrated,
    String? overrideDueDate,
  }) async {
    final services = await _requireServices();
    final sourceRelPath = item.document.relPath;

    // 1. Mark original line as migrated (>) or scheduled (<)
    await setTaskStateInPlace(item, sourceMarker);

    // 2. Append clean open task line to target file (if different file)
    if (sourceRelPath != targetRelPath) {
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
    buffer.writeln('citrinium:');
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
        newState: docType == 'project' ? TaskStateKind.migrated : null,
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
      await setTaskStateInPlace(item, TaskStateKind.migrated);
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
}

final vaultMutationProvider = Provider<VaultMutationService>((ref) {
  return VaultMutationService(ref);
});
