import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:path/path.dart' as p;

import '../domain/citrine_data_view.dart';
import '../domain/snapshot_exporter.dart';
import '../index/index_database.dart';
import '../index/index_operations.dart';
import '../index/index_service.dart';
import '../index/task_sync_service.dart';
import '../parser/nl_date_parser.dart';
import '../parser/task_state.dart';
import '../vault/path_normalization.dart';
import '../vault/vault_file_io.dart';

/// Pure-Dart implementation of the `citrine` CLI (`FR-12`).
class CitrineCliRunner {
  CitrineCliRunner({
    required this.vaultPath,
    this.dbPath,
    DateTime Function()? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now;

  final String vaultPath;
  final String? dbPath;
  final DateTime Function() _nowProvider;

  static File resolveDefaultDbFile(String vaultPath) {
    final hash = sha256.convert(utf8.encode(vaultPath)).toString();
    return File(p.join(vaultPath, '.citrine', '$hash.sqlite'));
  }

  Future<int> run(
    List<String> args, {
    required StringSink out,
    required StringSink err,
  }) async {
    if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
      out.writeln(_usage);
      return 0;
    }

    final dbFile = dbPath != null
        ? File(dbPath!)
        : resolveDefaultDbFile(vaultPath);
    await dbFile.parent.create(recursive: true);

    final db = IndexDatabase.native(dbFile);
    final indexService = IndexService(database: db, vaultRootPath: vaultPath);
    await indexService.ensureUpToDate();
    final taskSync = TaskSyncService(
      db: db,
      vaultRootPath: vaultPath,
      nowProvider: _nowProvider,
    );

    try {
      final command = args.first;
      final rest = args.sublist(1);
      final format = _option(rest, '--format') ?? 'json';

      switch (command) {
        case 'schema':
          return _handleSchema(format: format, out: out);
        case 'tasks':
          return await _handleTasks(
            rest,
            taskSync: taskSync,
            format: format,
            out: out,
            err: err,
          );
        case 'notes':
          return await _handleNotes(
            rest,
            db: db,
            format: format,
            out: out,
            err: err,
          );
        case 'dataview':
          return await _handleDataView(
            rest,
            db: db,
            indexService: indexService,
            format: format,
            out: out,
            err: err,
          );
        default:
          err.writeln('Unknown command: $command');
          out.writeln(_usage);
          return 2;
      }
    } finally {
      await db.close();
    }
  }

  int _handleSchema({required String format, required StringSink out}) {
    final schemaMap = {
      'schemaVersion': 2,
      'tables': {
        'tasks': [
          'task_id (TEXT PK)',
          'source_rel_path (TEXT NULL)',
          'source_byte_offset (INTEGER NULL)',
          'task_state (TEXT)',
          'text (TEXT)',
          'due_date (TEXT NULL)',
          'due_time (TEXT NULL)',
          'recurrence_raw (TEXT NULL)',
          'contexts_json (TEXT)',
          'tags_json (TEXT)',
          'horizon (TEXT NULL)',
          'created_at_ms (INTEGER)',
          'updated_at_ms (INTEGER)',
        ],
        'documents': [
          'id',
          'rel_path',
          'sha256',
          'mtime_ms',
          'size_bytes',
          'doc_type',
          'title',
          'frontmatter_json',
          'indexed_at_ms',
        ],
        'entries': [
          'id',
          'document_id',
          'line_index',
          'char_start',
          'char_end',
          'block_id',
          'kind',
          'task_state',
          'text',
          'due_date',
          'due_time',
          'recurrence_raw',
          'signifier',
        ],
      },
    };
    if (format == 'markdown') {
      out.writeln('# Citrine SQLite Schema (v2)');
      for (final entry in (schemaMap['tables'] as Map).entries) {
        out.writeln('\n## ${entry.key}');
        for (final col in entry.value as List) {
          out.writeln('- `$col`');
        }
      }
    } else {
      out.writeln(const JsonEncoder.withIndent('  ').convert(schemaMap));
    }
    return 0;
  }

  Future<int> _handleTasks(
    List<String> args, {
    required TaskSyncService taskSync,
    required String format,
    required StringSink out,
    required StringSink err,
  }) async {
    if (args.isEmpty) {
      err.writeln('Missing tasks subcommand (list|create|update)');
      return 2;
    }
    final sub = args.first;
    final opts = args.sublist(1);

    switch (sub) {
      case 'list':
        final tasks = await taskSync.listTasks(
          state: _option(opts, '--state'),
          horizon: _option(opts, '--horizon'),
          dueDate: _option(opts, '--due'),
        );
        if (format == 'markdown') {
          for (final t in tasks) {
            final mark = t.taskState == TaskStateKind.completed.name ? 'x' : ' ';
            out.writeln('- [$mark] ${t.textContent} <!-- citrine:task=${t.taskId} -->');
          }
        } else {
          out.writeln(
            const JsonEncoder.withIndent('  ')
                .convert(tasks.map(_taskToJson).toList()),
          );
        }
        return 0;

      case 'create':
        final text = _option(opts, '--text');
        if (text == null || text.trim().isEmpty) {
          err.writeln('Missing --text');
          return 2;
        }
        final created = await taskSync.createDatabaseTask(
          text: text,
          dueDate: _option(opts, '--due'),
          horizon: _option(opts, '--horizon'),
        );
        out.writeln(
          const JsonEncoder.withIndent('  ').convert(_taskToJson(created)),
        );
        return 0;

      case 'update':
        final id = _option(opts, '--id');
        if (id == null || id.isEmpty) {
          err.writeln('Missing --id');
          return 2;
        }
        final stateRaw = _option(opts, '--state');
        final state = stateRaw == null ? null : taskStateKindFromValue(stateRaw);
        final updated = await taskSync.updateTask(
          taskId: id,
          state: state,
          text: _option(opts, '--text'),
          dueDate: _option(opts, '--due'),
          horizon: _option(opts, '--horizon'),
        );
        if (updated == null) {
          err.writeln('Task not found: $id');
          return 1;
        }
        out.writeln(
          const JsonEncoder.withIndent('  ').convert(_taskToJson(updated)),
        );
        return 0;

      default:
        err.writeln('Unknown tasks subcommand: $sub');
        return 2;
    }
  }

  Future<int> _handleNotes(
    List<String> args, {
    required IndexDatabase db,
    required String format,
    required StringSink out,
    required StringSink err,
  }) async {
    if (args.isEmpty) {
      err.writeln('Missing notes subcommand (list|read)');
      return 2;
    }
    final sub = args.first;
    final opts = args.sublist(1);

    switch (sub) {
      case 'list':
        final docs = await db.select(db.documents).get();
        if (format == 'markdown') {
          for (final d in docs) {
            out.writeln('- ${d.relPath} (${d.title})');
          }
        } else {
          out.writeln(
            const JsonEncoder.withIndent('  ').convert(
              docs
                  .map(
                    (d) => {
                      'relPath': d.relPath,
                      'title': d.title,
                      'docType': d.docType,
                    },
                  )
                  .toList(),
            ),
          );
        }
        return 0;
      case 'read':
        final relPath = _option(opts, '--path');
        if (relPath == null || relPath.isEmpty) {
          err.writeln('Missing --path');
          return 2;
        }
        final file = File(VaultPath(relPath).toAbsolute(vaultPath));
        if (!await file.exists()) {
          err.writeln('Note not found: $relPath');
          return 1;
        }
        final contents = await readVaultFile(file);
        if (format == 'json') {
          out.writeln(jsonEncode({'relPath': relPath, 'content': contents.text}));
        } else {
          out.write(contents.text);
        }
        return 0;
      default:
        err.writeln('Unknown notes subcommand: $sub');
        return 2;
    }
  }

  Future<int> _handleDataView(
    List<String> args, {
    required IndexDatabase db,
    required IndexService indexService,
    required String format,
    required StringSink out,
    required StringSink err,
  }) async {
    if (args.isEmpty) {
      err.writeln('Missing dataview subcommand (query|export)');
      return 2;
    }
    final sub = args.first;
    final opts = args.sublist(1);
    final viewName = _option(opts, '--view') ?? 'dueToday';
    final preset = CitrineDataViewPreset.values.firstWhere(
      (p) => p.name == viewName,
      orElse: () => CitrineDataViewPreset.dueToday,
    );
    final dateStr = _option(opts, '--date');
    final refDate = dateStr != null
        ? DateTime.tryParse(dateStr) ?? _nowProvider()
        : _nowProvider();
    final query = CitrineDataViewQuery(view: preset);
    final allEntries = await db.watchAllEntriesWithDocuments().first;
    final items = evaluateCitrineDataView(
      query: query,
      allEntries: allEntries,
      referenceDate: refDate,
    );

    if (sub == 'export') {
      final outRelPath =
          _option(opts, '--out') ??
          'exports/${preset.name}-${NlDateParser.formatIsoDate(refDate)}.md';
      final md = renderDataViewSnapshotMarkdown(
        title: query.resolvedTitle,
        entries: items,
        generatedAt: _nowProvider(),
      );
      final file = File(VaultPath(outRelPath).toAbsolute(vaultPath));
      await file.parent.create(recursive: true);
      await writeVaultFileAtomic(
        file,
        VaultFileContents(text: md, hadBom: false),
      );
      await indexService.refreshFile(outRelPath);
      out.writeln(
        jsonEncode({
          'exported': outRelPath,
          'snapshotNotice':
              'Static snapshot; will not auto-update when Citrine data changes.',
        }),
      );
      return 0;
    }

    if (sub == 'query') {
      if (format == 'markdown') {
        out.write(
          renderDataViewSnapshotMarkdown(
            title: query.resolvedTitle,
            entries: items,
            generatedAt: _nowProvider(),
          ),
        );
      } else {
        out.writeln(
          const JsonEncoder.withIndent('  ').convert({
            'view': preset.name,
            'title': query.resolvedTitle,
            'count': items.length,
            'entries': items
                .map(
                  (e) => {
                    'relPath': e.document.relPath,
                    'lineIndex': e.entry.lineIndex,
                    'kind': e.entry.kind,
                    'taskState': e.entry.taskState,
                    'text': e.entry.textContent,
                    'dueDate': e.entry.dueDate,
                  },
                )
                .toList(),
          }),
        );
      }
      return 0;
    }

    err.writeln('Unknown dataview subcommand: $sub');
    return 2;
  }

  Map<String, Object?> _taskToJson(TaskRecord t) => {
    'taskId': t.taskId,
    'sourceRelPath': t.sourceRelPath,
    'sourceByteOffset': t.sourceByteOffset,
    'state': t.taskState,
    'text': t.textContent,
    'dueDate': t.dueDate,
    'dueTime': t.dueTime,
    'recurrenceRaw': t.recurrenceRaw,
    'horizon': t.horizon,
    'createdAtMs': t.createdAtMs,
    'updatedAtMs': t.updatedAtMs,
  };

  String? _option(List<String> args, String flag) {
    for (var i = 0; i < args.length - 1; i++) {
      if (args[i] == flag) return args[i + 1];
    }
    return null;
  }

  static const String _usage = '''
citrine CLI (FR-12)
Usage: citrine --vault <vault_path> [--db <sqlite_path>] <command>

Commands:
  tasks list [--state open|completed] [--horizon ...] [--due YYYY-MM-DD] [--format json|markdown]
  tasks create --text "..." [--due YYYY-MM-DD] [--horizon ...]
  tasks update --id <task_id> [--state open|completed] [--text "..."] [--due YYYY-MM-DD]
  notes list [--format json|markdown]
  notes read --path <rel_path> [--format json|markdown]
  dataview query --view <preset> [--date YYYY-MM-DD] [--format json|markdown]
  dataview export --view <preset> --out <rel_path> [--date YYYY-MM-DD]
  schema [--format json|markdown]
''';
}
