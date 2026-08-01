import 'dart:async';

import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Continuous File Watcher & Stream Provider Tests', () {
    test('Multiple successive VaultChangeEvents for a file are processed correctly',
        () async {
      final controller = StreamController<VaultChangeEvent>.broadcast();
      final targetPath = 'test/Markdown test.md';
      final targetNormalized = VaultPath(targetPath).value;

      final eventsStream = controller.stream.where((event) {
        return event.path.value == targetPath || event.path.value == targetNormalized;
      });

      final received = <VaultChangeEvent>[];
      eventsStream.listen((event) {
        received.add(event);
      });

      // Emit 1st external change
      controller.add(VaultChangeEvent(
        type: VaultChangeType.modify,
        path: VaultPath(targetPath),
      ));
      await Future<void>.delayed(Duration.zero);
      expect(received.length, equals(1));

      // Emit 2nd external change
      controller.add(VaultChangeEvent(
        type: VaultChangeType.modify,
        path: VaultPath(targetPath),
      ));
      await Future<void>.delayed(Duration.zero);
      expect(received.length, equals(2));

      // Emit 3rd external change
      controller.add(VaultChangeEvent(
        type: VaultChangeType.modify,
        path: VaultPath(targetPath),
      ));
      await Future<void>.delayed(Duration.zero);
      expect(received.length, equals(3));

      await controller.close();
    });
  });
}
