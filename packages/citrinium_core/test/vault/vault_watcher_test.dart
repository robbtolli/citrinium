import 'dart:async';
import 'dart:io';

import 'package:citrinium_core/vault.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Polling-tolerant wait: repeatedly checks [condition] until it's true or
/// [timeout] elapses, rather than assuming a single fixed delay is enough.
/// Native watchers (inotify/FSEvents) are fast, but CI environments and
/// polling fallbacks can be slow and flaky with a single fixed `sleep`.
Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  group('WatcherVaultWatcher', () {
    late Directory vault;
    late WatcherVaultWatcher watcher;
    late List<VaultChangeEvent> events;
    StreamSubscription<VaultChangeEvent>? sub;

    setUp(() async {
      vault = await Directory.systemTemp.createTemp('citrinium_watcher_test');
      watcher = WatcherVaultWatcher(
        vaultRootPath: vault.path,
        debounce: const Duration(milliseconds: 50),
      );
      events = [];
      sub = watcher.events.listen(events.add);
      await watcher.start();
    });

    tearDown(() async {
      await sub?.cancel();
      await watcher.stop();
      await vault.delete(recursive: true);
    });

    test('reports an add event for a new tracked file', () async {
      final file = File(p.join(vault.path, 'note.md'));
      await file.writeAsString('# Note\n');

      await _waitUntil(() => events.any((e) => e.path == VaultPath('note.md')));

      final event = events.firstWhere((e) => e.path == VaultPath('note.md'));
      expect(event.type, anyOf(VaultChangeType.add, VaultChangeType.modify));
    });

    test('ignores changes under ignored directories', () async {
      final file = File(p.join(vault.path, '.obsidian', 'workspace.md'));
      await file.parent.create(recursive: true);
      await file.writeAsString('{}');

      // Give the watcher a beat to (not) notice, then confirm nothing came
      // through -- there's no positive event to await here.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(events, isEmpty);
    });

    test('ignores non-markdown files', () async {
      final file = File(p.join(vault.path, 'image.png'));
      await file.writeAsString('not an image');

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(events, isEmpty);
    });

    test('debounces rapid successive writes to the same file into one event', () async {
      final file = File(p.join(vault.path, 'note.md'));
      for (var i = 0; i < 5; i++) {
        await file.writeAsString('revision $i\n');
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      await _waitUntil(() => events.isNotEmpty);
      // Let the debounce window fully settle to make sure no further
      // (duplicate) events trickle in afterwards.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final noteEvents = events.where((e) => e.path == VaultPath('note.md'));
      expect(noteEvents, hasLength(1));
    });

    test('reports a remove event when a tracked file is deleted', () async {
      final file = File(p.join(vault.path, 'note.md'));
      await file.writeAsString('# Note\n');
      await _waitUntil(() => events.isNotEmpty);
      events.clear();

      await file.delete();

      await _waitUntil(
        () => events.any(
          (e) => e.path == VaultPath('note.md') && e.type == VaultChangeType.remove,
        ),
      );
    });

    test('suppressSelfWrite swallows events for our own writes', () async {
      final path = VaultPath('note.md');
      final file = File(p.join(vault.path, 'note.md'));

      watcher.suppressSelfWrite(path);
      await file.writeAsString('# Note\n');

      // Confirm no event arrives for the whole suppression window (using a
      // short one for the test) plus a margin.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(events, isEmpty);
    });

    test('events resume normally after the suppression window expires', () async {
      final selfSuppressingWatcher = WatcherVaultWatcher(
        vaultRootPath: vault.path,
        debounce: const Duration(milliseconds: 50),
        selfWriteSuppressionWindow: const Duration(milliseconds: 100),
      );
      final localEvents = <VaultChangeEvent>[];
      final localSub = selfSuppressingWatcher.events.listen(localEvents.add);
      await selfSuppressingWatcher.start();
      addTearDown(() async {
        await localSub.cancel();
        await selfSuppressingWatcher.stop();
      });

      final path = VaultPath('note.md');
      selfSuppressingWatcher.suppressSelfWrite(path);

      // Wait out the suppression window before writing, so this write
      // should be reported normally.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await File(p.join(vault.path, 'note.md')).writeAsString('# Note\n');

      await _waitUntil(() => localEvents.any((e) => e.path == path));
    });
  });
}
