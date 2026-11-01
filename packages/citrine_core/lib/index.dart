/// Drift/SQLite index layer: a derived, rebuildable cache of
/// tasks/notes/links parsed out of the vault, plus full-text search.
///
/// This corresponds to `core/index/` in `design.md` §6.1 and
/// `docs/milestones/m0.md` W3. Nothing here is ever the sole record of
/// anything -- see `IndexService.fullRebuild` and `schema.drift`'s doc
/// comment.
library;

export 'src/index/document_indexer.dart';
export 'src/index/index_database.dart';
export 'src/index/index_operations.dart';
export 'src/index/index_service.dart';
export 'src/index/scanned_document.dart';
