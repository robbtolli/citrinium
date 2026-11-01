import 'package:citrine/core/plugins/plugin_sandbox.dart';
import 'package:citrine_core/citrine_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PluginSandbox & Security Enforcement (PL-01, PL-02, PL-05)', () {
    test('executes operations when granted required permission', () async {
      var tasksQueried = false;
      var toastShown = false;

      final callbacks = PluginHostBridgeCallbacks(
        tasksList: (filter) async {
          tasksQueried = true;
          return [
            {
              'relPath': 'daily/2026-10-31.md',
              'lineIndex': 5,
              'content': 'Write plugin sandbox test',
              'state': 'open',
              'isCompleted': false,
            }
          ];
        },
        tasksSetState: (_, _, _) async => true,
        tasksAppend: (_, _) async => true,
        notesRead: (_) async => '# Notes content',
        notesWrite: (_, _) async => true,
        notesList: () async => ['daily/2026-10-31.md'],
        filesCreate: (_, _) async => true,
        filesDelete: (_) async => true,
        netFetch: (_, _) async => {'status': 200},
        showToast: (msg) {
          toastShown = true;
        },
      );

      final manifest = const PluginManifest(
        id: 'com.example.task-reader',
        name: 'Task Reader',
        version: '1.0.0',
        description: 'Reads tasks',
        permissions: {PluginPermission.tasksRead},
      );

      final sandbox = PluginSandbox(
        manifest: manifest,
        grantedPermissions: {PluginPermission.tasksRead},
        callbacks: callbacks,
      );

      await sandbox.initialize();

      final result = await sandbox.executeScript('''
        const tasks = citrine.tasks.list({});
        citrine.ui.showToast('Tasks found: ' + tasks.length);
        tasks.length;
      ''');

      expect(result.success, isTrue);
      expect(tasksQueried, isTrue);
      expect(toastShown, isTrue);

      sandbox.dispose();
    });

    test('strictly denies operations when permission is not granted (PL-02, PL-05)',
        () async {
      final callbacks = PluginHostBridgeCallbacks(
        tasksList: (_) async => [],
        tasksSetState: (_, _, _) async => true,
        tasksAppend: (_, _) async => true,
        notesRead: (_) async => '',
        notesWrite: (_, _) async => true,
        notesList: () async => [],
        filesCreate: (_, _) async => true,
        filesDelete: (_) async => true,
        netFetch: (_, _) async => {'status': 200},
        showToast: (_) {},
      );

      // Plugin only requests notesRead, but script attempts to modify a task (tasks:write)
      final manifest = const PluginManifest(
        id: 'com.example.unauthorized-writer',
        name: 'Unauthorized Writer',
        version: '1.0.0',
        description: 'Attempts unauthorized task modification',
        permissions: {PluginPermission.notesRead},
      );

      final sandbox = PluginSandbox(
        manifest: manifest,
        grantedPermissions: {PluginPermission.notesRead}, // tasksWrite NOT granted!
        callbacks: callbacks,
      );

      await sandbox.initialize();

      final result = await sandbox.executeScript('''
        citrine.tasks.append('daily/2026-10-31.md', 'Malicious task insertion');
      ''');

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('SecurityException'));
      expect(result.errorMessage, contains('tasks:write'));

      sandbox.dispose();
    });

    test('denies network access when network:fetch is not granted', () async {
      final callbacks = PluginHostBridgeCallbacks(
        tasksList: (_) async => [],
        tasksSetState: (_, _, _) async => true,
        tasksAppend: (_, _) async => true,
        notesRead: (_) async => '',
        notesWrite: (_, _) async => true,
        notesList: () async => [],
        filesCreate: (_, _) async => true,
        filesDelete: (_) async => true,
        netFetch: (_, _) async => {'status': 200},
        showToast: (_) {},
      );

      final manifest = const PluginManifest(
        id: 'com.example.offline-plugin',
        name: 'Offline Plugin',
        version: '1.0.0',
        description: 'Offline plugin',
        permissions: {PluginPermission.tasksRead},
      );

      final sandbox = PluginSandbox(
        manifest: manifest,
        grantedPermissions: {PluginPermission.tasksRead}, // network:fetch NOT granted
        callbacks: callbacks,
      );

      await sandbox.initialize();

      final result = await sandbox.executeScript('''
        citrine.net.fetch('https://example.com/api', {});
      ''');

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('SecurityException'));
      expect(result.errorMessage, contains('network:fetch'));

      sandbox.dispose();
    });
  });
}
