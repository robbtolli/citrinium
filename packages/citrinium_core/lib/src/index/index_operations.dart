import 'package:crypto/crypto.dart' show sha256;
import 'package:drift/drift.dart';

import 'index_database.dart';
import 'scanned_document.dart';

/// Read/write API over [IndexDatabase], kept as extension methods (rather
/// than piling onto the generated-code-adjacent class in
/// `index_database.dart`) so the drift wiring and the actual index
/// mechanics are easy to tell apart at a glance.
///
/// Every method here treats a *whole document's* rows (its `entries`,
/// `entry_contexts`, `entry_tags`, outgoing `links`, and `document_fts`
/// row) as a single unit: on any change, the old rows for that document are
/// replaced wholesale rather than diffed line-by-line. Documents are small
/// enough (10MB scan cap, `vault_scanner.dart`) that this is simpler and
/// far less bug-prone than incremental line-level reconciliation, while
/// still being cheap enough for interactive use.
extension IndexDatabaseOperations on IndexDatabase {
  // -------------------------------------------------------------------
  // index_meta
  // -------------------------------------------------------------------

  Future<String?> getMeta(String key) async {
    final row = await (select(
      indexMeta,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setMeta(String key, String value) async {
    await into(
      indexMeta,
    ).insertOnConflictUpdate(IndexMetaCompanion.insert(key: key, value: value));
  }

  // -------------------------------------------------------------------
  // Full rebuild
  // -------------------------------------------------------------------

  /// Replaces the entire index with [docs] in one transaction: every
  /// existing `documents` row (and everything that cascades from it) is
  /// deleted first, so this always converges to the same state regardless
  /// of whatever was in the database before -- the mechanism behind
  /// `docs/milestones/m0.md` exit criterion #4 ("deleting the index
  /// database and relaunching reconstructs identical index state").
  Future<void> replaceAllDocuments(List<ScannedDocument> docs) async {
    await transaction(() async {
      await delete(documents).go();
      await customStatement('DELETE FROM document_fts;');
      for (final doc in docs) {
        await _insertDocument(doc);
      }
      await _resolveLinks();
    });
  }

  /// Incrementally applies an add/modify of the file at [relPath]: a no-op
  /// if [doc]'s `sha256` matches what's already indexed for that path
  /// (this is the "skip unchanged" mechanic `docs/milestones/m0.md` W3
  /// calls for), otherwise replaces that document's rows wholesale.
  Future<void> upsertDocument(ScannedDocument doc) async {
    await transaction(() async {
      final existing = await (select(
        documents,
      )..where((t) => t.relPath.equals(doc.relPath))).getSingleOrNull();
      if (existing != null && existing.sha256 == doc.sha256) {
        return; // unchanged content -- nothing to do.
      }
      if (existing != null) {
        await (delete(documents)..where((t) => t.id.equals(existing.id))).go();
        await customStatement('DELETE FROM document_fts WHERE rowid = ?;', [
          existing.id,
        ]);
      }
      await _insertDocument(doc);
      await _resolveLinks();
    });
  }

  /// Removes the document at [relPath] (and everything that cascades from
  /// it) from the index. A no-op if it isn't indexed.
  Future<void> removeDocument(String relPath) async {
    await transaction(() async {
      final existing = await (select(
        documents,
      )..where((t) => t.relPath.equals(relPath))).getSingleOrNull();
      if (existing == null) return;
      await (delete(documents)..where((t) => t.id.equals(existing.id))).go();
      await customStatement('DELETE FROM document_fts WHERE rowid = ?;', [
        existing.id,
      ]);
      // Links pointing *at* the removed document are set NULL by the
      // schema's `ON DELETE SET NULL` FK -- re-resolving isn't needed for
      // those (the target is genuinely gone), only for the (rare) case
      // where removing this document frees up a previously-ambiguous
      // basename match for some other still-unresolved link.
      await _resolveLinks();
    });
  }

  Future<void> _insertDocument(ScannedDocument doc) async {
    final documentId = await into(documents).insert(
      DocumentsCompanion.insert(
        relPath: doc.relPath,
        sha256: doc.sha256,
        mtimeMs: doc.mtimeMs,
        sizeBytes: doc.sizeBytes,
        docType: doc.docType,
        title: doc.title,
        frontmatterJson: Value(doc.frontmatterJson),
        indexedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    await customStatement(
      'INSERT INTO document_fts(rowid, title, body) VALUES (?, ?, ?);',
      [documentId, doc.title, doc.rawText],
    );

    // lineIndex -> inserted entry id, so ScannedLink.sourceLineIndex can be
    // resolved to a real `source_entry_id` below.
    final entryIdByLineIndex = <int, int>{};

    for (final entry in doc.entries) {
      final entryId = await into(entries).insert(
        EntriesCompanion.insert(
          documentId: documentId,
          lineIndex: entry.lineIndex,
          charStart: entry.charStart,
          charEnd: entry.charEnd,
          kind: entry.kind,
          textContent: entry.text,
          blockId: Value(entry.blockId),
          taskState: Value(entry.taskState),
          dueDate: Value(entry.dueDate),
          dueTime: Value(entry.dueTime),
          recurrenceRaw: Value(entry.recurrenceRaw),
        ),
      );
      entryIdByLineIndex[entry.lineIndex] = entryId;

      for (final context in entry.contexts) {
        await into(entryContexts).insert(
          EntryContextsCompanion.insert(entryId: entryId, context: context),
        );
      }
      for (final tag in entry.tags) {
        await into(
          entryTags,
        ).insert(EntryTagsCompanion.insert(entryId: entryId, tag: tag));
      }
    }

    for (final link in doc.links) {
      final sourceEntryId = link.sourceLineIndex == null
          ? null
          : entryIdByLineIndex[link.sourceLineIndex];
      await into(links).insert(
        LinksCompanion.insert(
          sourceDocumentId: documentId,
          sourceEntryId: Value(sourceEntryId),
          targetRaw: link.targetRaw,
          kind: link.kind,
        ),
      );
    }
  }

  // -------------------------------------------------------------------
  // Link resolution
  // -------------------------------------------------------------------

  /// Best-effort resolution of every `links` row with a NULL
  /// `target_document_id`: first by exact relative path (with or without a
  /// `.md` extension, so `[[Projects/Citrinium]]` matches
  /// `Projects/Citrinium.md`), then by a *unique* filename match anywhere
  /// in the vault (Obsidian-style shortest-path linking). Left NULL if
  /// there's no match or more than one candidate -- a dangling or
  /// ambiguous link is not an error, per `design.md` §3's "auto-created on
  /// first use" logs (a link can validly point at a note that doesn't
  /// exist yet).
  Future<void> _resolveLinks() async {
    final allDocs = await select(documents).get();
    final byRelPath = <String, int>{
      for (final d in allDocs) _normalizeTarget(d.relPath): d.id,
    };
    final byBasename = <String, List<int>>{};
    for (final d in allDocs) {
      final base = _basenameNoExt(d.relPath);
      byBasename.putIfAbsent(base, () => []).add(d.id);
    }

    final unresolved = await (select(
      links,
    )..where((t) => t.targetDocumentId.isNull())).get();

    for (final link in unresolved) {
      final resolved = _resolveTarget(link.targetRaw, byRelPath, byBasename);
      if (resolved == null) continue;
      await (update(links)..where((t) => t.id.equals(link.id))).write(
        LinksCompanion(targetDocumentId: Value(resolved)),
      );
    }
  }

  int? _resolveTarget(
    String targetRaw,
    Map<String, int> byRelPath,
    Map<String, List<int>> byBasename,
  ) {
    // Wikilinks never carry the `.md` extension by convention, but accept
    // it anyway (some tools/users include it).
    final normalized = _normalizeTarget(targetRaw);
    final byPath = byRelPath[normalized] ?? byRelPath['$normalized.md'];
    if (byPath != null) return byPath;

    final base = _basenameNoExt(targetRaw);
    final candidates = byBasename[base.toLowerCase()];
    if (candidates != null && candidates.length == 1) return candidates.single;
    return null;
  }

  String _normalizeTarget(String path) =>
      path.replaceAll('\\', '/').toLowerCase();

  String _basenameNoExt(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    final name = slash == -1 ? normalized : normalized.substring(slash + 1);
    return name.toLowerCase().endsWith('.md')
        ? name.substring(0, name.length - 3)
        : name;
  }

  // -------------------------------------------------------------------
  // Reads (the "boundary the state layer consumes", design.md §4)
  // -------------------------------------------------------------------

  Stream<List<Document>> watchAllDocuments() =>
      (select(documents)..orderBy([(t) => OrderingTerm.asc(t.relPath)])).watch();

  Future<Document?> documentByRelPath(String relPath) =>
      (select(documents)..where((t) => t.relPath.equals(relPath))).getSingleOrNull();

  Stream<List<Entry>> watchEntriesForDocument(int documentId) =>
      (select(entries)
            ..where((t) => t.documentId.equals(documentId))
            ..orderBy([(t) => OrderingTerm.asc(t.lineIndex)]))
          .watch();

  /// Streams every indexed [Entry] across the entire vault joined with its
  /// owning [Document], `@contexts`, and `#tags`. Used by Today's Focus Shelf,
  /// Next Actions, Inbox Clarify, Projects, Waiting For, Someday/Maybe, and
  /// Review rituals so any entry can be displayed and edited in-place (`D-19`).
  Stream<List<IndexedEntryWithDocument>> watchAllEntriesWithDocuments() {
    final entriesStream = (select(entries)
          ..orderBy([
            (t) => OrderingTerm.asc(t.documentId),
            (t) => OrderingTerm.asc(t.lineIndex),
          ]))
        .watch();

    return entriesStream.asyncMap((allEntries) async {
      if (allEntries.isEmpty) return const <IndexedEntryWithDocument>[];
      final allDocs = await select(documents).get();
      final docById = <int, Document>{for (final d in allDocs) d.id: d};

      final allContexts = await select(entryContexts).get();
      final contextsByEntry = <int, List<String>>{};
      for (final c in allContexts) {
        contextsByEntry.putIfAbsent(c.entryId, () => []).add(c.context);
      }

      final allTags = await select(entryTags).get();
      final tagsByEntry = <int, List<String>>{};
      for (final t in allTags) {
        tagsByEntry.putIfAbsent(t.entryId, () => []).add(t.tag);
      }

      final result = <IndexedEntryWithDocument>[];
      for (final entry in allEntries) {
        final doc = docById[entry.documentId];
        if (doc == null) continue;
        result.add(
          IndexedEntryWithDocument(
            entry: entry,
            document: doc,
            contexts: List.unmodifiable(contextsByEntry[entry.id] ?? const []),
            tags: List.unmodifiable(tagsByEntry[entry.id] ?? const []),
          ),
        );
      }
      return result;
    });
  }

  /// Watches incoming `[[wikilinks]]` pointing at [targetDocumentId], paired
  /// with the source [Document] (`N-02`, `D-12`).
  Stream<List<BacklinkItem>> watchBacklinksForDocument(int targetDocumentId) {
    final linkStream = (select(links)
          ..where((t) => t.targetDocumentId.equals(targetDocumentId)))
        .watch();
    return linkStream.asyncMap((rows) async {
      if (rows.isEmpty) return const <BacklinkItem>[];
      final allDocs = await select(documents).get();
      final docById = <int, Document>{for (final d in allDocs) d.id: d};
      return [
        for (final row in rows)
          if (docById[row.sourceDocumentId] != null)
            BacklinkItem(
              link: row,
              sourceDocument: docById[row.sourceDocumentId]!,
            ),
      ];
    });
  }

  /// Full-text search across `document_fts` (`N-03`, `FR-06`).
  Future<List<Document>> searchDocuments(String rawQuery) async {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) {
      return (select(documents)..orderBy([(t) => OrderingTerm.asc(t.relPath)])).get();
    }
    // Sanitize FTS5 query tokens into prefix matches
    final tokens = trimmed
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'[^\w\-]'), ''))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return const [];
    final ftsQuery = tokens.map((t) => '"$t"*').join(' AND ');
    try {
      final rows = await customSelect(
        'SELECT rowid FROM document_fts WHERE document_fts MATCH ? LIMIT 50;',
        variables: [Variable.withString(ftsQuery)],
      ).get();
      final ids = rows.map((r) => r.read<int>('rowid')).toSet();
      if (ids.isEmpty) return const [];
      return await (select(documents)
            ..where((t) => t.id.isIn(ids))
            ..orderBy([(t) => OrderingTerm.asc(t.relPath)]))
          .get();
    } on Object {
      // Fallback to case-insensitive substring match if FTS syntax is unusual
      final lower = trimmed.toLowerCase();
      final all = await select(documents).get();
      return all
          .where(
            (d) =>
                d.title.toLowerCase().contains(lower) ||
                d.relPath.toLowerCase().contains(lower),
          )
          .toList();
    }
  }

  /// Discovers unlinked mentions for [targetDoc] in other vault documents (`N-02`, `D-12`).
  ///
  /// Searches for occurrences of [targetDoc.title] (or [targetDoc.relPath] basename) in the text
  /// of other documents where the occurrence is NOT already enclosed in `[[...]]`.
  Future<List<UnlinkedMentionItem>> findUnlinkedMentionsForDocument(
    Document targetDoc,
  ) async {
    final keywords = <String>{};
    if (targetDoc.title.trim().length >= 3) {
      keywords.add(targetDoc.title.trim());
    }
    final base = _basenameNoExt(targetDoc.relPath);
    if (base.trim().length >= 3 &&
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(base) &&
        !RegExp(r'^\d{4}-w\d{2}$', caseSensitive: false).hasMatch(base)) {
      keywords.add(base.trim());
    }
    if (keywords.isEmpty) return const [];

    final allDocs = await select(documents).get();
    final docById = <int, Document>{for (final d in allDocs) d.id: d};

    final results = <UnlinkedMentionItem>[];
    final seen = <String>{};

    for (final kw in keywords) {
      final pattern = RegExp(
        r'\[\[([^\]]*?)\]\]|' + RegExp.escape(kw),
        caseSensitive: false,
      );

      final matchingEntries = await (select(entries)
            ..where((t) =>
                t.documentId.isNotValue(targetDoc.id) &
                t.textContent.like('%$kw%')))
          .get();

      for (final entry in matchingEntries) {
        final text = entry.textContent;
        for (final match in pattern.allMatches(text)) {
          final matchedStr = match.group(0)!;
          if (matchedStr.startsWith('[[') && matchedStr.endsWith(']]')) {
            continue; // Already a linked wikilink
          }
          final sourceDoc = docById[entry.documentId];
          if (sourceDoc == null) continue;

          final key = '${sourceDoc.relPath}:${entry.lineIndex}';
          if (seen.contains(key)) break;
          seen.add(key);

          final start = (match.start - 25).clamp(0, text.length);
          final end = (match.end + 25).clamp(0, text.length);
          var snippet = text.substring(start, end).trim();
          if (start > 0) snippet = '...$snippet';
          if (end < text.length) snippet = '$snippet...';

          results.add(
            UnlinkedMentionItem(
              sourceDocument: sourceDoc,
              matchedText: kw,
              snippet: snippet,
              lineIndex: entry.lineIndex,
            ),
          );
          break;
        }
      }
    }
    return results;
  }

  /// Full-text and faceted search across documents and tasks (`N-03`, `N-04`, `N-05`, `FR-06`).
  Future<List<SearchResultItem>> searchVault({
    required String query,
    String? docTypeFilter,
    String? tagFilter,
    String? contextFilter,
    bool tasksOnly = false,
  }) async {
    final trimmed = query.trim();
    final allDocs = await select(documents).get();
    final docById = <int, Document>{for (final d in allDocs) d.id: d};

    final rawEntries = await (select(entries)
          ..orderBy([
            (t) => OrderingTerm.asc(t.documentId),
            (t) => OrderingTerm.asc(t.lineIndex),
          ]))
        .get();

    final allContexts = await select(entryContexts).get();
    final contextsByEntry = <int, List<String>>{};
    for (final c in allContexts) {
      contextsByEntry.putIfAbsent(c.entryId, () => []).add(c.context);
    }

    final allTags = await select(entryTags).get();
    final tagsByEntry = <int, List<String>>{};
    for (final t in allTags) {
      tagsByEntry.putIfAbsent(t.entryId, () => []).add(t.tag);
    }

    final allEntries = <IndexedEntryWithDocument>[];
    for (final entry in rawEntries) {
      final doc = docById[entry.documentId];
      if (doc == null) continue;
      allEntries.add(
        IndexedEntryWithDocument(
          entry: entry,
          document: doc,
          contexts: List.unmodifiable(contextsByEntry[entry.id] ?? const []),
          tags: List.unmodifiable(tagsByEntry[entry.id] ?? const []),
        ),
      );
    }

    var filteredEntries = allEntries;
    if (tasksOnly) {
      filteredEntries = filteredEntries.where((e) => e.isTask).toList();
    }
    if (tagFilter != null && tagFilter.isNotEmpty) {
      final cleanTag =
          tagFilter.startsWith('#') ? tagFilter.substring(1) : tagFilter;
      filteredEntries = filteredEntries
          .where((e) =>
              e.tags.any((t) => t.toLowerCase() == cleanTag.toLowerCase()))
          .toList();
    }
    if (contextFilter != null && contextFilter.isNotEmpty) {
      final cleanCtx =
          contextFilter.startsWith('@') ? contextFilter.substring(1) : contextFilter;
      filteredEntries = filteredEntries
          .where((e) =>
              e.contexts.any((c) => c.toLowerCase() == cleanCtx.toLowerCase()))
          .toList();
    }
    if (docTypeFilter != null &&
        docTypeFilter.isNotEmpty &&
        docTypeFilter != 'all') {
      filteredEntries = filteredEntries.where((e) {
        if (docTypeFilter == 'note') return e.document.docType == 'note';
        if (docTypeFilter == 'project') {
          return e.document.docType == 'project' ||
              e.document.relPath.startsWith('projects/');
        }
        if (docTypeFilter == 'collection') {
          return e.document.docType == 'collection' ||
              e.document.relPath.startsWith('collections/');
        }
        if (docTypeFilter == 'log') {
          return e.document.docType.endsWith('Log') ||
              e.document.relPath.startsWith('daily/') ||
              e.document.relPath.startsWith('weekly/');
        }
        if (docTypeFilter == 'reference') {
          return e.document.docType == 'reference' ||
              e.document.relPath == 'reference.md';
        }
        return true;
      }).toList();
    }

    final results = <SearchResultItem>[];
    final seen = <String>{};

    final lowerQ = trimmed.toLowerCase();

    // 1. Entry matches
    for (final e in filteredEntries) {
      final matchesQuery = lowerQ.isEmpty ||
          e.entry.textContent.toLowerCase().contains(lowerQ) ||
          e.document.title.toLowerCase().contains(lowerQ) ||
          e.document.relPath.toLowerCase().contains(lowerQ);

      if (matchesQuery) {
        final key = 'entry:${e.uniqueKey}';
        if (!seen.contains(key)) {
          seen.add(key);
          results.add(
            SearchResultItem(
              document: e.document,
              entry: e.entry,
              snippet: e.entry.textContent,
              matchType: e.isTask ? 'task' : 'entry',
            ),
          );
        }
      }
    }

    // 2. Document matches
    if (!tasksOnly && tagFilter == null && contextFilter == null) {
      var candidateDocs = allDocs;
      if (docTypeFilter != null &&
          docTypeFilter.isNotEmpty &&
          docTypeFilter != 'all') {
        candidateDocs = candidateDocs.where((d) {
          if (docTypeFilter == 'note') return d.docType == 'note';
          if (docTypeFilter == 'project') {
            return d.docType == 'project' || d.relPath.startsWith('projects/');
          }
          if (docTypeFilter == 'collection') {
            return d.docType == 'collection' ||
                d.relPath.startsWith('collections/');
          }
          if (docTypeFilter == 'log') {
            return d.docType.endsWith('Log') ||
                d.relPath.startsWith('daily/') ||
                d.relPath.startsWith('weekly/');
          }
          if (docTypeFilter == 'reference') {
            return d.docType == 'reference' || d.relPath == 'reference.md';
          }
          return true;
        }).toList();
      }

      for (final doc in candidateDocs) {
        final docKey = 'doc:${doc.id}';
        if (seen.contains(docKey)) continue;

        if (lowerQ.isEmpty) {
          seen.add(docKey);
          results.add(
            SearchResultItem(
              document: doc,
              snippet: doc.title.isNotEmpty ? doc.title : doc.relPath,
              matchType: 'document',
            ),
          );
        } else if (doc.title.toLowerCase().contains(lowerQ) ||
            doc.relPath.toLowerCase().contains(lowerQ)) {
          seen.add(docKey);
          results.add(
            SearchResultItem(
              document: doc,
              snippet: doc.title.isNotEmpty ? doc.title : doc.relPath,
              matchType: 'title',
            ),
          );
        }
      }
    }

    return results;
  }

  /// Summary stats for the settings screen (W4).
  Future<IndexStats> stats() async {
    final documentCount =
        await (selectOnly(documents)..addColumns([documents.id.count()]))
            .map((row) => row.read(documents.id.count()) ?? 0)
            .getSingle();
    final entryCount =
        await (selectOnly(entries)..addColumns([entries.id.count()]))
            .map((row) => row.read(entries.id.count()) ?? 0)
            .getSingle();
    final lastIndexedAt =
        await (selectOnly(documents)
              ..addColumns([documents.indexedAtMs.max()]))
            .map((row) => row.read(documents.indexedAtMs.max()))
            .getSingle();
    final parserVersion = await getMeta('parserVersion');
    final vaultFingerprint = await getMeta('vaultFingerprint');
    return IndexStats(
      documentCount: documentCount,
      entryCount: entryCount,
      lastIndexedAtMs: lastIndexedAt,
      parserVersion: parserVersion,
      vaultFingerprint: vaultFingerprint,
    );
  }

  Stream<IndexStats> watchStats() {
    // `documents`/`entries` changes are what stats derive from; watching
    // both and remapping keeps this reactive without hand-rolled
    // invalidation.
    return watchAllDocuments().asyncMap((_) => stats());
  }

  /// A deterministic fingerprint of the current index content
  /// (`relPath:sha256` pairs, sorted, hashed) -- used both as
  /// `index_meta['vaultFingerprint']` and directly by the W6 rebuild-
  /// determinism test to assert that wiping and rescanning a vault
  /// converges to identical *content*, independent of autoincrement id
  /// churn or insertion order.
  Future<String> computeFingerprint() async {
    final rows =
        await (select(documents)
              ..orderBy([(t) => OrderingTerm.asc(t.relPath)]))
            .get();
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln('${row.relPath}:${row.sha256}');
    }
    return sha256.convert(buffer.toString().codeUnits).toString();
  }
}

/// Summary counts/timestamps surfaced on the settings screen (W4).
class IndexStats {
  const IndexStats({
    required this.documentCount,
    required this.entryCount,
    required this.lastIndexedAtMs,
    required this.parserVersion,
    required this.vaultFingerprint,
  });

  final int documentCount;
  final int entryCount;
  final int? lastIndexedAtMs;
  final String? parserVersion;
  final String? vaultFingerprint;
}

/// An indexed [Entry] paired with its owning [Document], `@contexts`, and
/// `#tags` for aggregated views and in-place task editing (`D-19`).
class IndexedEntryWithDocument {
  const IndexedEntryWithDocument({
    required this.entry,
    required this.document,
    required this.contexts,
    required this.tags,
  });

  final Entry entry;
  final Document document;
  final List<String> contexts;
  final List<String> tags;

  /// Stable key across UI lists (`relPath:lineIndex`).
  String get uniqueKey => '${document.relPath}:${entry.lineIndex}';

  bool get isTask => entry.kind == 'task';
  bool get isEvent => entry.kind == 'event';
  bool get isNote => entry.kind == 'note';
  bool get isUntyped => entry.kind == 'untyped';

  bool get isOpenTask =>
      isTask && (entry.taskState == 'open' || entry.taskState == 'inProgress');
  bool get isCompletedTask => isTask && entry.taskState == 'completed';
  bool get isWaitingTask =>
      isTask &&
      (entry.taskState == 'waitingFor' ||
          tags.any((t) => t.startsWith('waiting-for')) ||
          contexts.contains('waiting-for'));
  bool get isSomedayTask =>
      document.relPath == 'someday.md' ||
      document.docType == 'someday' ||
      tags.contains('someday');
  bool get isHabit =>
      tags.contains('habit') ||
      (entry.recurrenceRaw != null && entry.recurrenceRaw!.trim().isNotEmpty);
}

/// An incoming wikilink paired with the source [Document] (`N-02`, `D-12`).
class BacklinkItem {
  const BacklinkItem({
    required this.link,
    required this.sourceDocument,
  });

  final LinkRow link;
  final Document sourceDocument;
}

/// An unlinked mention of a note's title or basename found in another note (`N-02`, `D-12`).
class UnlinkedMentionItem {
  const UnlinkedMentionItem({
    required this.sourceDocument,
    required this.matchedText,
    required this.snippet,
    required this.lineIndex,
  });

  final Document sourceDocument;
  final String matchedText;
  final String snippet;
  final int lineIndex;
}

/// A search result item covering documents, tasks, and snippets (`N-03`, `FR-06`).
class SearchResultItem {
  const SearchResultItem({
    required this.document,
    this.entry,
    required this.snippet,
    required this.matchType,
  });

  final Document document;
  final Entry? entry;
  final String snippet;
  final String matchType; // 'task' | 'entry' | 'document' | 'title'
}

