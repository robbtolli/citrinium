import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/citrine_data_view.dart';
import '../domain/snapshot_exporter.dart';
import '../index/index_database.dart';
import '../index/index_operations.dart';
import '../index/index_service.dart';
import '../index/task_sync_service.dart';
import '../parser/task_state.dart';
import '../vault/path_normalization.dart';
import '../vault/vault_file_io.dart';
import 'citrine_cli.dart';

/// Model Context Protocol (`citrine-mcp`) stdio JSON-RPC 2.0 server (`FR-13`).
class CitrineMcpServer {
  CitrineMcpServer({
    required this.vaultPath,
    this.dbPath,
    DateTime Function()? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now;

  final String vaultPath;
  final String? dbPath;
  final DateTime Function() _nowProvider;

  late IndexDatabase _db;
  late IndexService _indexService;
  late TaskSyncService _taskSync;

  Future<void> open() async {
    final dbFile = dbPath != null
        ? File(dbPath!)
        : CitrineCliRunner.resolveDefaultDbFile(vaultPath);
    await dbFile.parent.create(recursive: true);
    _db = IndexDatabase.native(dbFile);
    _indexService = IndexService(database: _db, vaultRootPath: vaultPath);
    await _indexService.ensureUpToDate();
    _taskSync = TaskSyncService(
      db: _db,
      vaultRootPath: vaultPath,
      nowProvider: _nowProvider,
    );
  }

  Future<void> close() => _db.close();

  /// Processes a single JSON-RPC 2.0 request object and returns the response
  /// map (or `null` for notifications with no `id`).
  Future<Map<String, Object?>?> handleMessage(
    Map<String, Object?> request,
  ) async {
    final id = request['id'];
    final method = request['method'] as String?;
    final params = (request['params'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};

    if (method == null) {
      if (id == null) return null;
      return _error(id, -32600, 'Invalid Request: missing method');
    }

    // Notifications without an id do not expect a response.
    if (id == null && method.startsWith('notifications/')) {
      return null;
    }

    try {
      final result = switch (method) {
        'initialize' => _handleInitialize(),
        'ping' => <String, Object?>{},
        'tools/list' => _handleToolsList(),
        'tools/call' => await _handleToolsCall(params),
        'resources/list' => _handleResourcesList(),
        'resources/read' => await _handleResourcesRead(params),
        _ => null,
      };

      if (result == null) {
        return id == null ? null : _error(id, -32601, 'Method not found: $method');
      }
      return id == null
          ? null
          : <String, Object?>{'jsonrpc': '2.0', 'id': id, 'result': result};
    } catch (e) {
      return id == null ? null : _error(id, -32000, e.toString());
    }
  }

  /// Serves newline-delimited JSON-RPC 2.0 messages over [input] -> [output].
  Future<void> serveStdio({
    required Stream<List<int>> input,
    required IOSink output,
  }) async {
    final lines = input.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      Map<String, Object?>? decoded;
      try {
        decoded = (jsonDecode(trimmed) as Map).cast<String, Object?>();
      } catch (e) {
        output.writeln(jsonEncode(_error(null, -32700, 'Parse error: $e')));
        continue;
      }
      final response = await handleMessage(decoded);
      if (response != null) {
        output.writeln(jsonEncode(response));
      }
    }
  }

  Map<String, Object?> _handleInitialize() => {
    'protocolVersion': '2024-11-05',
    'capabilities': {
      'tools': <String, Object?>{},
      'resources': <String, Object?>{},
    },
    'serverInfo': {'name': 'citrine-mcp', 'version': '0.1.0'},
  };

  Map<String, Object?> _handleToolsList() => {
    'tools': [
      {
        'name': 'list_tasks',
        'description': 'List canonical Citrine tasks from SQLite.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'state': {'type': 'string'},
            'horizon': {'type': 'string'},
            'due_date': {'type': 'string'},
          },
        },
      },
      {
        'name': 'create_task',
        'description': 'Create a database-backed Citrine task.',
        'inputSchema': {
          'type': 'object',
          'required': ['text'],
          'properties': {
            'text': {'type': 'string'},
            'due_date': {'type': 'string'},
            'horizon': {'type': 'string'},
          },
        },
      },
      {
        'name': 'update_task',
        'description':
            'Update a Citrine task in SQLite and sync back to its Markdown file if linked.',
        'inputSchema': {
          'type': 'object',
          'required': ['task_id'],
          'properties': {
            'task_id': {'type': 'string'},
            'state': {'type': 'string'},
            'text': {'type': 'string'},
            'due_date': {'type': 'string'},
            'horizon': {'type': 'string'},
          },
        },
      },
      {
        'name': 'list_notes',
        'description': 'List Markdown notes indexed in the Citrine vault.',
        'inputSchema': {'type': 'object', 'properties': <String, Object?>{}},
      },
      {
        'name': 'read_note',
        'description': 'Read a Markdown note from the vault by relative path.',
        'inputSchema': {
          'type': 'object',
          'required': ['rel_path'],
          'properties': {
            'rel_path': {'type': 'string'},
          },
        },
      },
      {
        'name': 'query_dataview',
        'description': 'Query a Citrine data view preset.',
        'inputSchema': {
          'type': 'object',
          'required': ['view'],
          'properties': {
            'view': {'type': 'string'},
            'date': {'type': 'string'},
            'format': {'type': 'string'},
          },
        },
      },
    ],
  };

  Future<Map<String, Object?>> _handleToolsCall(
    Map<String, Object?> params,
  ) async {
    final name = params['name'] as String?;
    final args = (params['arguments'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};

    switch (name) {
      case 'list_tasks':
        final tasks = await _taskSync.listTasks(
          state: args['state'] as String?,
          horizon: args['horizon'] as String?,
          dueDate: args['due_date'] as String?,
        );
        return _textToolResult(
          jsonEncode(tasks.map(_taskToJson).toList()),
        );

      case 'create_task':
        final text = (args['text'] as String?) ?? '';
        if (text.trim().isEmpty) {
          return _textToolResult('Error: text is required', isError: true);
        }
        final created = await _taskSync.createDatabaseTask(
          text: text,
          dueDate: args['due_date'] as String?,
          horizon: args['horizon'] as String?,
        );
        return _textToolResult(jsonEncode(_taskToJson(created)));

      case 'update_task':
        final taskId = args['task_id'] as String?;
        if (taskId == null || taskId.isEmpty) {
          return _textToolResult('Error: task_id is required', isError: true);
        }
        final stateStr = args['state'] as String?;
        final updated = await _taskSync.updateTask(
          taskId: taskId,
          state: stateStr == null ? null : taskStateKindFromValue(stateStr),
          text: args['text'] as String?,
          dueDate: args['due_date'] as String?,
          horizon: args['horizon'] as String?,
        );
        if (updated == null) {
          return _textToolResult('Task not found: $taskId', isError: true);
        }
        return _textToolResult(jsonEncode(_taskToJson(updated)));

      case 'list_notes':
        final docs = await _db.select(_db.documents).get();
        return _textToolResult(
          jsonEncode(
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

      case 'read_note':
        final relPath = args['rel_path'] as String?;
        if (relPath == null || relPath.isEmpty) {
          return _textToolResult('Error: rel_path is required', isError: true);
        }
        final file = File(VaultPath(relPath).toAbsolute(vaultPath));
        if (!await file.exists()) {
          return _textToolResult('Note not found: $relPath', isError: true);
        }
        final contents = await readVaultFile(file);
        return _textToolResult(contents.text);

      case 'query_dataview':
        final viewName = (args['view'] as String?) ?? 'dueToday';
        final preset = CitrineDataViewPreset.values.firstWhere(
          (p) => p.name == viewName,
          orElse: () => CitrineDataViewPreset.dueToday,
        );
        final dateStr = args['date'] as String?;
        final refDate = dateStr != null
            ? DateTime.tryParse(dateStr) ?? _nowProvider()
            : _nowProvider();
        final query = CitrineDataViewQuery(view: preset);
        final allEntries = await _db.watchAllEntriesWithDocuments().first;
        final items = evaluateCitrineDataView(
          query: query,
          allEntries: allEntries,
          referenceDate: refDate,
        );
        if (args['format'] == 'markdown') {
          return _textToolResult(
            renderDataViewSnapshotMarkdown(
              title: query.resolvedTitle,
              entries: items,
              generatedAt: _nowProvider(),
            ),
          );
        }
        return _textToolResult(
          jsonEncode({
            'view': preset.name,
            'title': query.resolvedTitle,
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

      default:
        return _textToolResult('Unknown tool: $name', isError: true);
    }
  }

  Map<String, Object?> _handleResourcesList() => {
    'resources': [
      {
        'uri': 'citrine://schema',
        'name': 'Citrine SQLite & Markdown Schema',
        'mimeType': 'application/json',
      },
      {
        'uri': 'citrine://tasks',
        'name': 'All Citrine Tasks',
        'mimeType': 'application/json',
      },
    ],
  };

  Future<Map<String, Object?>> _handleResourcesRead(
    Map<String, Object?> params,
  ) async {
    final uri = params['uri'] as String?;
    switch (uri) {
      case 'citrine://schema':
        return {
          'contents': [
            {
              'uri': uri,
              'mimeType': 'application/json',
              'text': jsonEncode({
                'schemaVersion': 2,
                'taskCommentFormat': '<!-- citrine:task=<id> -->',
                'tables': ['tasks', 'documents', 'entries', 'links', 'document_fts'],
              }),
            },
          ],
        };
      case 'citrine://tasks':
        final tasks = await _taskSync.listTasks();
        return {
          'contents': [
            {
              'uri': uri,
              'mimeType': 'application/json',
              'text': jsonEncode(tasks.map(_taskToJson).toList()),
            },
          ],
        };
      default:
        throw StateError('Unknown resource URI: $uri');
    }
  }

  Map<String, Object?> _textToolResult(String text, {bool isError = false}) => {
    'content': [
      {'type': 'text', 'text': text},
    ],
    if (isError) 'isError': true,
  };

  Map<String, Object?> _taskToJson(TaskRecord t) => {
    'taskId': t.taskId,
    'sourceRelPath': t.sourceRelPath,
    'sourceByteOffset': t.sourceByteOffset,
    'state': t.taskState,
    'text': t.textContent,
    'dueDate': t.dueDate,
    'horizon': t.horizon,
  };

  Map<String, Object?> _error(Object? id, int code, String message) => {
    'jsonrpc': '2.0',
    'id': id,
    'error': {'code': code, 'message': message},
  };
}
