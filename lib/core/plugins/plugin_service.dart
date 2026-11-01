import 'dart:convert';
import 'dart:io';

import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../index/index_providers.dart';
import '../workspace/workspace_state.dart';
import 'plugin_models.dart';
import 'plugin_sandbox.dart';

/// Service managing discovery, installation, and sandboxed execution of Citrine plugins (PL-01–PL-08).
class PluginService {
  PluginService({
    required this.vaultDir,
    required this.workspaceStateNotifier,
    required this.vaultMutationService,
    required this.indexService,
    required this.showToastCallback,
  });

  final Directory vaultDir;
  final WorkspaceStateNotifier workspaceStateNotifier;
  final VaultMutationService vaultMutationService;
  final IndexService indexService;
  final void Function(String message) showToastCallback;

  Directory get _pluginsDir =>
      Directory(p.join(vaultDir.path, '.citrine', 'plugins'));

  /// Discovers all community plugins located in `<vault>/.citrine/plugins/`.
  Future<List<PluginInfo>> discoverPlugins(WorkspaceState state) async {
    final results = <PluginInfo>[];
    if (!await _pluginsDir.exists()) {
      await _pluginsDir.create(recursive: true);
      await seedStarterCommunityPlugins();
    } else if (_pluginsDir.listSync().isEmpty) {
      await seedStarterCommunityPlugins();
    }

    final entities = _pluginsDir.listSync(followLinks: false);
    for (final entity in entities) {
      if (entity is Directory) {
        final manifestFile = File(p.join(entity.path, 'plugin.json'));
        if (manifestFile.existsSync()) {
          try {
            final json = jsonDecode(manifestFile.readAsStringSync())
                as Map<String, dynamic>;
            final manifest = PluginManifest.fromJson(json);

            // Cross-reference with operational workspace state (PL-02, PL-03, PL-04)
            final installRecord = state.installedPlugins[manifest.id];
            final isEnabled = installRecord?.isEnabled ?? false;
            final grantedPermissions = installRecord != null
                ? installRecord.grantedPermissions
                    .map((s) => PluginPermission.tryParse(s))
                    .whereType<PluginPermission>()
                    .toSet()
                : <PluginPermission>{};

            results.add(
              PluginInfo(
                manifest: manifest,
                dirPath: entity.path,
                isEnabled: isEnabled,
                isCore: false,
                grantedPermissions: grantedPermissions,
                installedAtMs: installRecord?.installedAtMs ?? 0,
              ),
            );
          } catch (e) {
            debugPrint('Failed to load plugin manifest at ${manifestFile.path}: $e');
          }
        }
      }
    }
    return results;
  }

  /// Installs a community plugin from a directory containing `plugin.json` (PL-02, PL-03).
  Future<PluginInfo> installPluginFromDirectory({
    required Directory sourceDir,
    required Set<PluginPermission> grantedPermissions,
  }) async {
    final manifestFile = File(p.join(sourceDir.path, 'plugin.json'));
    if (!manifestFile.existsSync()) {
      throw const FormatException('Missing plugin.json in source directory');
    }

    final json =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final manifest = PluginManifest.fromJson(json);

    final targetDir = Directory(p.join(_pluginsDir.path, manifest.id));
    final isSameDir =
        p.canonicalize(sourceDir.path) == p.canonicalize(targetDir.path);
    if (!isSameDir) {
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }

      // Copy directory files
      for (final file in sourceDir.listSync(recursive: true)) {
        if (file is File) {
          final rel = p.relative(file.path, from: sourceDir.path);
          final dest = File(p.join(targetDir.path, rel));
          dest.parent.createSync(recursive: true);
          file.copySync(dest.path);
        }
      }
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final record = PluginInstallRecord(
      pluginId: manifest.id,
      grantedPermissions: grantedPermissions.map((p) => p.id).toSet(),
      isEnabled: true,
      installedAtMs: nowMs,
      isCore: false,
    );

    await workspaceStateNotifier.registerInstalledPlugin(record);

    return PluginInfo(
      manifest: manifest,
      dirPath: targetDir.path,
      isEnabled: true,
      isCore: false,
      grantedPermissions: grantedPermissions,
      installedAtMs: nowMs,
    );
  }

  /// Revokes and deletes a community plugin completely from disk and state (PL-04).
  Future<void> revokePlugin(String pluginId) async {
    await workspaceStateNotifier.revokePlugin(pluginId);
    final targetDir = Directory(p.join(_pluginsDir.path, pluginId));
    if (targetDir.existsSync()) {
      try {
        targetDir.deleteSync(recursive: true);
      } catch (e) {
        debugPrint('Failed to delete plugin dir for $pluginId: $e');
      }
    }
  }

  /// Executes a community plugin in its isolated QuickJS sandbox (PL-01, PL-05).
  Future<PluginExecutionResult> executePlugin(PluginInfo plugin) async {
    if (!plugin.isEnabled) {
      return PluginExecutionResult(
        pluginId: plugin.id,
        success: false,
        errorMessage: 'Plugin is disabled',
      );
    }

    final entryFile = File(p.join(plugin.dirPath, plugin.manifest.entry));
    if (!entryFile.existsSync()) {
      return PluginExecutionResult(
        pluginId: plugin.id,
        success: false,
        errorMessage: 'Plugin entry point not found: ${plugin.manifest.entry}',
      );
    }

    final jsCode = await entryFile.readAsString();

    final callbacks = PluginHostBridgeCallbacks(
      tasksList: (filter) async {
        final entriesWithDocs =
            await indexService.watchAllEntriesWithDocuments().first;
        final list = <Map<String, dynamic>>[];
        for (final item in entriesWithDocs) {
          if (item.entry.kind == 'task') {
            list.add({
              'relPath': item.document.relPath,
              'lineIndex': item.entry.lineIndex,
              'content': item.entry.textContent,
              'state': item.entry.taskState,
              'isCompleted':
                  item.entry.taskState == TaskStateKind.completed.name,
            });
          }
        }
        return list;
      },
      tasksSetState: (relPath, lineIndex, stateStr) async {
        final entriesWithDocs =
            await indexService.watchAllEntriesWithDocuments().first;
        final item = entriesWithDocs
            .where((e) =>
                e.document.relPath == relPath &&
                e.entry.lineIndex == lineIndex)
            .firstOrNull;
        if (item == null) return false;

        TaskStateKind newState = TaskStateKind.completed;
        for (final k in TaskStateKind.values) {
          if (k.name.toLowerCase() == stateStr.toLowerCase()) {
            newState = k;
            break;
          }
        }
        await vaultMutationService.setTaskStateInPlace(item, newState);
        return true;
      },
      tasksAppend: (relPath, text) async {
        await vaultMutationService.appendLineToDocument(
          relPath: relPath,
          lineText: '- [ ] $text',
        );
        return true;
      },
      notesRead: (relPath) async {
        final file = File(p.join(vaultDir.path, relPath));
        if (file.existsSync()) return file.readAsStringSync();
        return '';
      },
      notesWrite: (relPath, content) async {
        final file = File(p.join(vaultDir.path, relPath));
        if (!file.existsSync()) return false;
        await file.writeAsString(content);
        await indexService.refreshFile(relPath);
        return true;
      },
      notesList: () async {
        final docs = await indexService.watchAllDocuments().first;
        return docs.map((d) => d.relPath).toList();
      },
      filesCreate: (relPath, content) async {
        final file = File(p.join(vaultDir.path, relPath));
        if (file.existsSync()) return false;
        file.parent.createSync(recursive: true);
        await file.writeAsString(content);
        await indexService.refreshFile(relPath);
        return true;
      },
      filesDelete: (relPath) async {
        final file = File(p.join(vaultDir.path, relPath));
        if (!file.existsSync()) return false;
        await file.delete();
        await indexService.handleChange(
          VaultChangeEvent(
            type: VaultChangeType.remove,
            path: VaultPath(relPath),
          ),
        );
        return true;
      },
      netFetch: (url, options) async {
        // Safe mock fetch payload returned to JS sandbox
        return {'status': 200, 'url': url};
      },
      showToast: (msg) {
        showToastCallback(msg);
      },
    );

    final sandbox = PluginSandbox(
      manifest: plugin.manifest,
      grantedPermissions: plugin.grantedPermissions,
      callbacks: callbacks,
    );

    try {
      await sandbox.initialize();
      return await sandbox.executeScript(jsCode);
    } finally {
      sandbox.dispose();
    }
  }

  /// Seeds two real, practical community plugins for user exploration.
  Future<void> seedStarterCommunityPlugins() async {
    // 1. Document Stats & Word Counter (requires notes:read)
    final wordCounterDir =
        Directory(p.join(_pluginsDir.path, 'com.citrine.word-counter'));
    if (!wordCounterDir.existsSync()) {
      wordCounterDir.createSync(recursive: true);
      final manifest = {
        'id': 'com.citrine.word-counter',
        'name': 'Document Stats & Word Counter',
        'version': '1.0.0',
        'description':
            'Counts indexed notes and calculates total vault words across all Markdown files.',
        'author': 'Citrine Team',
        'permissions': ['notes:read'],
        'entry': 'main.js',
      };
      File(p.join(wordCounterDir.path, 'plugin.json'))
          .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
      File(p.join(wordCounterDir.path, 'main.js')).writeAsStringSync('''
      (function() {
        var notes = citrine.notes.list();
        var count = notes ? notes.length : 0;
        citrine.ui.showToast('Vault contains ' + count + ' Markdown notes indexed.');
        return 'Found ' + count + ' notes.';
      })();
      ''');
    }

    // 2. Task Hygiene Sweeper (requires tasks:read and tasks:write)
    final taskSweeperDir =
        Directory(p.join(_pluginsDir.path, 'com.citrine.task-hygiene'));
    if (!taskSweeperDir.existsSync()) {
      taskSweeperDir.createSync(recursive: true);
      final manifest = {
        'id': 'com.citrine.task-hygiene',
        'name': 'Task Hygiene Sweeper',
        'version': '1.0.0',
        'description':
            'Audits active vault tasks and reports rapid open/completed statistics.',
        'author': 'Citrine Team',
        'permissions': ['tasks:read', 'tasks:write'],
        'entry': 'main.js',
      };
      File(p.join(taskSweeperDir.path, 'plugin.json'))
          .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
      File(p.join(taskSweeperDir.path, 'main.js')).writeAsStringSync('''
      (function() {
        var tasks = citrine.tasks.list({});
        var count = tasks ? tasks.length : 0;
        citrine.ui.showToast('Task Hygiene: ' + count + ' active tasks in vault.');
        return count + ' tasks evaluated.';
      })();
      ''');
    }
  }
}
