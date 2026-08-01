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
