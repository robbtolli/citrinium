import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart' show sha256;

import '../parser/markdown_document.dart';
import '../parser/parser_version.dart';
import '../vault/path_normalization.dart';
import '../vault/vault_file_io.dart';
import '../vault/vault_scanner.dart';
import '../vault/vault_watcher.dart';
import 'document_indexer.dart';
import 'index_database.dart';
import 'index_operations.dart';
import 'scanned_document.dart';

/// Counts returned by [IndexService.fullRebuild], surfaced by the W4
/// "Rebuild index" button.
class IndexRebuildStats {
  const IndexRebuildStats({
    required this.documentCount,
    required this.skippedCount,
  });

  final int documentCount;
  final int skippedCount;
}

/// Orchestrates keeping [IndexDatabase] in sync with the vault on disk, per
/// `docs/milestones/m0.md` W3: a full scan (on a background isolate) for
/// first-run/rebuild, incremental upsert on watcher events (skipping
/// unchanged files by `sha256`), and an automatic full rebuild whenever
/// `currentParserVersion` doesn't match what's stored in
/// `index_meta['parserVersion']`.
///
/// This is the only thing in `citrinium_core` that ties the vault (W1),
/// parser (W2), and index (W3) layers together; `IndexDatabaseOperations`
/// (the extension in `index_operations.dart`) never touches vault I/O, and
/// `VaultScanner`/`MarkdownDocument` never know the index exists.
class IndexService {
  IndexService({
    required IndexDatabase database,
    required this.vaultRootPath,
    this.scanOptions = const VaultScanOptions(),
  }) : _db = database;

  final IndexDatabase _db;
  final String vaultRootPath;
  final VaultScanOptions scanOptions;

  /// Reactive stats stream for the settings screen (W4).
  Stream<IndexStats> watchStats() => _db.watchStats();

  Stream<List<Document>> watchAllDocuments() => _db.watchAllDocuments();

  Stream<List<Entry>> watchEntriesForDocument(int documentId) =>
      _db.watchEntriesForDocument(documentId);

  Future<Document?> documentByRelPath(String relPath) =>
      _db.documentByRelPath(relPath);

  /// Ensures the index reflects the current `currentParserVersion` and, on
  /// a brand-new database, actually has content at all: triggers
  /// [fullRebuild] if `index_meta['parserVersion']` is missing or doesn't
  /// match. Call this once at startup before relying on any query/stream.
  Future<void> ensureUpToDate() async {
    final storedVersion = await _db.getMeta('parserVersion');
    if (storedVersion != currentParserVersion.toString()) {
      await fullRebuild();
    }
  }

  /// Full scan → parse → replace-all-rows rebuild. The scan + parse step
  /// runs on a background isolate ([Isolate.run]) so a large vault doesn't
  /// jank the UI thread; only the (comparatively cheap) SQLite writes
  /// happen back on the calling isolate, via [IndexDatabase].
  ///
  /// This is also exit criterion #4's mechanism made concrete: deleting the
  /// index database file and calling this again reconstructs the same
  /// content from the files alone, since nothing here reads prior index
  /// state.
  Future<IndexRebuildStats> fullRebuild() async {
    // Copy the (sendable) fields the isolate needs into locals first: a
    // closure over `vaultRootPath`/`scanOptions` directly would capture
    // `this` (and therefore `_db`, which holds a native SQLite handle that
    // can't cross an isolate boundary -- see `Isolate.run`'s "unsendable
    // object" restriction).
    final rootPath = vaultRootPath;
    final options = scanOptions;
    final scan = await Isolate.run(() => scanAndParseVault(rootPath, options));
    await _db.replaceAllDocuments(scan.documents);
    await _db.setMeta('schemaVersion', _db.schemaVersion.toString());
    await _db.setMeta('parserVersion', currentParserVersion.toString());
    await _db.setMeta(
      'vaultFingerprint',
      await _db.computeFingerprint(),
    );
    return IndexRebuildStats(
      documentCount: scan.documents.length,
      skippedCount: scan.skippedCount,
    );
  }

  /// Applies one debounced [VaultWatcher] event incrementally: reads +
  /// parses just the changed file (skipping the write entirely if its
  /// `sha256` matches what's already indexed) rather than rescanning the
  /// whole vault.
  Future<void> handleChange(VaultChangeEvent event) async {
    if (event.type == VaultChangeType.remove) {
      await _db.removeDocument(event.path.value);
      await _db.setMeta('vaultFingerprint', await _db.computeFingerprint());
      return;
    }

    final absolutePath = event.path.toAbsolute(vaultRootPath);
    final file = File(absolutePath);
    if (!file.existsSync()) {
      // Raced with a delete between the debounced event firing and us
      // reading the file -- treat it the same as an explicit remove.
      await _db.removeDocument(event.path.value);
      await _db.setMeta('vaultFingerprint', await _db.computeFingerprint());
      return;
    }

    final contents = readVaultFileSync(file);
    final stat = file.statSync();
    final scanned = buildScannedDocumentFromContents(
      relPath: event.path.value,
      contents: contents,
      mtimeMs: stat.modified.millisecondsSinceEpoch,
      sizeBytes: stat.size,
    );
    await _db.upsertDocument(scanned);
    await _db.setMeta('vaultFingerprint', await _db.computeFingerprint());
  }
}

/// The result of [scanAndParseVault]: every successfully-parsed document,
/// plus a count of files the scanner itself skipped (too large, unreadable,
/// unfollowed symlink -- see `VaultScanSkipReason`), for surfacing in the
/// W4 settings screen.
class VaultScanAndParseResult {
  const VaultScanAndParseResult({
    required this.documents,
    required this.skippedCount,
  });

  final List<ScannedDocument> documents;
  final int skippedCount;
}

/// Scans [vaultRootPath] and parses every discovered file into a
/// [ScannedDocument]. A top-level function (rather than an instance
/// method) so it can be handed directly to [Isolate.run] -- everything it
/// touches (`dart:io` file reads, the pure-Dart parser) works identically
/// on a background isolate, and its return value (plain data classes only,
/// per `scanned_document.dart`'s doc comment) is safely sendable back.
Future<VaultScanAndParseResult> scanAndParseVault(
  String vaultRootPath,
  VaultScanOptions options,
) async {
  final scanResult = await VaultScanner(options: options).scan(vaultRootPath);
  final docs = <ScannedDocument>[];
  for (final entry in scanResult.files) {
    final contents = readVaultFileSync(File(entry.absolutePath));
    docs.add(
      buildScannedDocumentFromContents(
        relPath: entry.path.value,
        contents: contents,
        mtimeMs: entry.modifiedTime.millisecondsSinceEpoch,
        sizeBytes: entry.sizeBytes,
      ),
    );
  }
  return VaultScanAndParseResult(
    documents: docs,
    skippedCount: scanResult.skipped.length,
  );
}

/// Parses [contents] and maps it into a [ScannedDocument], computing the
/// content-hash key ([ScannedDocument.sha256]) that lets incremental
/// updates skip unchanged files.
ScannedDocument buildScannedDocumentFromContents({
  required String relPath,
  required VaultFileContents contents,
  required int mtimeMs,
  required int sizeBytes,
}) {
  final doc = MarkdownDocument.parse(contents.text);
  final hash = sha256.convert(utf8.encode(contents.text)).toString();
  return buildScannedDocument(
    relPath: VaultPath(relPath).value,
    sha256: hash,
    mtimeMs: mtimeMs,
    sizeBytes: sizeBytes,
    doc: doc,
  );
}
