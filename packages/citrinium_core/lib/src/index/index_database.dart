import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'index_database.g.dart';

/// The drift/SQLite index database, per `docs/milestones/m0.md` W3 /
/// `design.md` §4. Schema lives in `schema.drift` (see that file for the
/// full table-by-table rationale); this class is just the drift
/// boilerplate + connection setup. The actual read/write API
/// (`fullRebuild`, `upsertDocument`, watch streams, etc.) lives in
/// `index_operations.dart` as extension methods, kept separate from the
/// generated-code wiring here.
///
/// This is always a **derived, rebuildable cache** (P-11) -- see
/// `IndexService` for the full-scan/incremental-upsert/parser-version-
/// triggered-rebuild mechanics that keep it that way.
@DriftDatabase(include: {'schema.drift'})
class IndexDatabase extends _$IndexDatabase {
  IndexDatabase(super.executor);

  /// Opens (or creates) a SQLite file at [file].
  ///
  /// The Flutter app itself builds its `QueryExecutor` via `drift_flutter`
  /// instead, so the index file lands in the platform-appropriate
  /// `<appSupport>/index/<hash(vaultPath)>.sqlite` location (see
  /// `docs/milestones/m0.md`'s "Index location" decision) -- this
  /// constructor exists so `citrinium_core` (a pure-Dart package with no
  /// Flutter dependency) can still open a real file for its own tests and
  /// any future non-Flutter tooling.
  factory IndexDatabase.native(File file) =>
      IndexDatabase(NativeDatabase.createInBackground(file));

  /// In-memory database, for tests that don't need on-disk persistence.
  factory IndexDatabase.memory() => IndexDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // See `schema.drift`'s comment on why this isn't a `CREATE VIRTUAL
      // TABLE` declared through the normal drift-file/typed-table
      // mechanism.
      await customStatement(
        'CREATE VIRTUAL TABLE document_fts USING fts5(title, body);',
      );
    },
    beforeOpen: (details) async {
      // Required for `ON DELETE CASCADE` / `ON DELETE SET NULL` (schema.drift)
      // to actually take effect -- SQLite has this off by default per
      // connection.
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );
}
