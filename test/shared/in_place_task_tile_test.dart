import 'package:citrine/core/vault/vault_path_provider.dart';
import 'package:citrine/shared/widgets/in_place_task_tile.dart';
import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'InPlaceTaskTile renders source file chip below the task description',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(380, 700);
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      const item = IndexedEntryWithDocument(
        entry: Entry(
          id: 1,
          documentId: 1,
          lineIndex: 0,
          charStart: 0,
          charEnd: 42,
          kind: 'task',
          taskState: 'open',
          textContent: 'Draft quarterly roadmap review notes',
        ),
        document: Document(
          id: 1,
          relPath: 'projects/very-long-project-document-name.md',
          title: 'Very Long Project Document Name',
          docType: 'project',
          mtimeMs: 0,
          indexedAtMs: 0,
          sizeBytes: 100,
          sha256: 'abc',
        ),
        contexts: [],
        tags: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(8),
                child: InPlaceTaskTile(item: item, showSourceBadge: true),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final taskTextFinder = find.text('Draft quarterly roadmap review notes');
      final sourceChipFinder = find.byType(ActionChip);

      expect(taskTextFinder, findsOneWidget);
      expect(sourceChipFinder, findsOneWidget);

      final taskRect = tester.getRect(taskTextFinder);
      final chipRect = tester.getRect(sourceChipFinder);

      expect(chipRect.top, greaterThanOrEqualTo(taskRect.bottom));
      expect(taskRect.width, greaterThan(220));
    },
  );
}
