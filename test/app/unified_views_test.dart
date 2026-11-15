import 'dart:io';

import 'package:citrine/app/citrine_app.dart';
import 'package:citrine/core/vault/vault_path_provider.dart';
import 'package:citrine/core/workspace/workspace_state.dart';
import 'package:citrine/shared/widgets/citrine_data_view_card.dart';
import 'package:citrine/shared/widgets/embedded_markdown_editor.dart';
import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this._dir);

  final Directory _dir;

  @override
  Future<String?> getApplicationSupportPath() async => _dir.path;

  @override
  Future<String?> getTemporaryPath() async => _dir.path;
}

void main() {
  group('Unified Today & Pure Data-View Plan & Review (M15 — B-01, B-02)', () {
    late Directory tempDir;
    late Directory supportDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('citrine_m15_test_');
      supportDir = await Directory.systemTemp.createTemp('citrine_m15_sup_');
      PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir);
      await Directory(p.join(tempDir.path, 'daily')).create(recursive: true);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      if (await supportDir.exists()) {
        await supportDir.delete(recursive: true);
      }
    });

    Future<void> waitUntil(
      WidgetTester tester,
      bool Function() condition, {
      Duration timeout = const Duration(seconds: 10),
    }) async {
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        if (condition()) return;
      }
      fail('condition not met within $timeout');
    }

    testWidgets(
      'Today supports past-day date navigation, Back to Today, and inline citrine data views (B-01)',
      (tester) async {
        await tester.runAsync(() async {
          final now = DateTime.now();
          final todayIso = NlDateParser.formatIsoDate(now);
          final yesterday = DateTime(now.year, now.month, now.day - 1);
          final yesterdayIso = NlDateParser.formatIsoDate(yesterday);

          // Seed yesterday's daily note and today's daily note with a citrine block
          await File(p.join(tempDir.path, 'daily', '$yesterdayIso.md'))
              .writeAsString(
            '# $yesterdayIso\n\n- [x] Finished yesterday task\n',
          );
          await File(p.join(tempDir.path, 'daily', '$todayIso.md'))
              .writeAsString(
            '# $todayIso\n\n'
            '```citrine\n'
            'view: top-focus\n'
            '```\n\n'
            '```citrine\n'
            'view: tasks\n'
            'filter: due-today\n'
            'include-overdue: true\n'
            '```\n\n'
            '- [ ] Finish unified today view 📅 $todayIso\n',
          );

          SharedPreferences.setMockInitialValues({'vaultPath': tempDir.path});
          final prefs = await SharedPreferences.getInstance();
          final container = ProviderContainer(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const CitrineApp(),
            ),
          );
          await waitUntil(
            tester,
            () =>
                find.text('Today · $todayIso').evaluate().isNotEmpty &&
                find.byType(CitrineDataViewCard).evaluate().isNotEmpty,
          );

          // Embedded citrine data view blocks render inline without raw fenced text
          expect(find.byType(CitrineDataViewCard), findsAtLeastNWidgets(2));
          expect(find.text("Today's Top Focus"), findsAtLeastNWidgets(1));
          expect(find.text('Tasks Due Today'), findsAtLeastNWidgets(1));
          for (final et in tester.widgetList<EditableText>(
            find.byType(EditableText),
          )) {
            expect(et.controller.text, isNot(contains('view: top-focus')));
            expect(et.controller.text, isNot(contains('include-overdue: true')));
          }
          expect(
            find.byKey(const Key('editor-insert-data-view')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('today-back-to-today')), findsNothing);

          // Navigate to yesterday
          await tester.tap(find.byKey(const Key('today-date-prev')));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();

          expect(
            find.descendant(
              of: find.byKey(const Key('today-date-picker')),
              matching: find.text(yesterdayIso),
            ),
            findsOneWidget,
          );
          expect(
            find.text('Daily Log (daily/$yesterdayIso.md)'),
            findsOneWidget,
          );
          expect(find.byKey(const Key('today-back-to-today')), findsOneWidget);

          // Navigate two days back to an empty day
          await tester.tap(find.byKey(const Key('today-date-prev')));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          expect(find.text('Create Note for This Day'), findsOneWidget);

          // Return to Today via Back to Today
          await tester.tap(find.byKey(const Key('today-back-to-today')));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          expect(find.text('Today · $todayIso'), findsOneWidget);
          expect(find.byKey(const Key('today-back-to-today')), findsNothing);
        });
      },
    );

    testWidgets(
      'Plan & Review renders pure database-driven data views without backing markdown editors (B-02)',
      (tester) async {
        await tester.runAsync(() async {
          final now = DateTime.now();
          final todayIso = NlDateParser.formatIsoDate(now);
          await File(p.join(tempDir.path, 'daily', '$todayIso.md'))
              .writeAsString(
            '# $todayIso\n\n- [ ] Weekly milestone task 📅 $todayIso\n',
          );

          SharedPreferences.setMockInitialValues({'vaultPath': tempDir.path});
          final prefs = await SharedPreferences.getInstance();
          final container = ProviderContainer(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const CitrineApp(),
            ),
          );
          await waitUntil(
            tester,
            () => find.text('Plan & Review').evaluate().isNotEmpty,
          );

          await tester.tap(find.text('Plan & Review').first);
          await waitUntil(
            tester,
            () => find
                .text('Weekly Plan & Review · Pure Data View')
                .evaluate()
                .isNotEmpty,
          );

          expect(
            find.text('Weekly Plan & Review · Pure Data View'),
            findsOneWidget,
          );
          expect(find.byType(CitrineDataViewCard), findsAtLeastNWidgets(2));
          expect(find.byType(EmbeddedMarkdownEditor), findsNothing);
          expect(find.textContaining('Create weekly/'), findsNothing);

          // Switch to Monthly pure data view
          await tester.tap(find.text('Monthly').first);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          expect(
            find.text('Monthly Plan & Review · Pure Data View'),
            findsOneWidget,
          );
          expect(find.byType(EmbeddedMarkdownEditor), findsNothing);
        });
      },
    );

    testWidgets(
      'Rendered data views in markdown documents have a Source Mode button and can be dragged to reorder',
      (tester) async {
        await tester.runAsync(() async {
          final now = DateTime.now();
          final todayIso = NlDateParser.formatIsoDate(now);
          final dailyFile = File(p.join(tempDir.path, 'daily', '$todayIso.md'));
          await dailyFile.writeAsString(
            '# $todayIso\n\n'
            '```citrine\n'
            'view: top-focus\n'
            '```\n\n'
            '```citrine\n'
            'view: tasks\n'
            'filter: due-today\n'
            '```\n\n'
            '- [ ] Test task 📅 $todayIso\n',
          );

          SharedPreferences.setMockInitialValues({'vaultPath': tempDir.path});
          final prefs = await SharedPreferences.getInstance();
          final container = ProviderContainer(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const CitrineApp(),
            ),
          );
          await waitUntil(
            tester,
            () => find.byType(CitrineDataViewCard).evaluate().length >= 2,
          );

          // Each rendered data view card has a Source Mode button in the top right
          final sourceButtons = find.byTooltip('Source Mode');
          expect(sourceButtons, findsNWidgets(2));
          await tester.ensureVisible(sourceButtons.first);
          await tester.pumpAndSettle();
          final firstCardRect = tester.getRect(
            find.byType(CitrineDataViewCard).first,
          );
          final firstSourceBtnRect = tester.getRect(sourceButtons.first);
          expect(
            firstSourceBtnRect.center.dx,
            greaterThan(firstCardRect.center.dx),
          );
          expect(
            firstSourceBtnRect.center.dy,
            lessThan(firstCardRect.center.dy),
          );

          // Switch the first data view into source mode and edit its citrine block
          await tester.tap(sourceButtons.first);
          await tester.pumpAndSettle();
          expect(find.text('Citrine Data View (Source)'), findsOneWidget);

          final sourceEditable = find.byWidgetPredicate(
            (w) => w is EditableText && w.controller.text.contains('view: top-focus'),
          );
          expect(sourceEditable, findsOneWidget);
          final editableWidget = tester.widget<EditableText>(sourceEditable);
          editableWidget.controller.text =
              '```citrine\nview: top-focus\ntitle: My Custom Focus\n```';
          await tester.pump();

          // Switch back to rendered preview mode
          await tester.ensureVisible(find.byTooltip('Preview Data View'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Preview Data View'));
          await tester.pumpAndSettle();
          expect(find.text('Citrine Data View (Source)'), findsNothing);
          expect(find.text('My Custom Focus'), findsOneWidget);

          // Drag the second data view up above the first data view
          final dragHandles = find.byTooltip('Drag to reorder');
          expect(dragHandles, findsNWidgets(2));
          await tester.ensureVisible(dragHandles.at(1));
          await tester.pumpAndSettle();
          final firstHandleCenter = tester.getCenter(dragHandles.first);
          final secondHandleCenter = tester.getCenter(dragHandles.at(1));
          await tester.timedDragFrom(
            secondHandleCenter,
            Offset(0, firstHandleCenter.dy - secondHandleCenter.dy - 20),
            const Duration(milliseconds: 300),
          );
          await tester.pumpAndSettle();

          final cardsAfter = tester
              .widgetList<CitrineDataViewCard>(find.byType(CitrineDataViewCard))
              .toList();
          expect(cardsAfter.length, 2);
          expect(cardsAfter[0].query.resolvedTitle, 'Tasks Due Today');
          expect(cardsAfter[1].query.resolvedTitle, 'My Custom Focus');
        });
      },
    );

    testWidgets(
      'UI data views in Plan & Review can be dragged to reorder and persist',
      (tester) async {
        await tester.runAsync(() async {
          final now = DateTime.now();
          final todayIso = NlDateParser.formatIsoDate(now);
          await File(p.join(tempDir.path, 'daily', '$todayIso.md'))
              .writeAsString('# $todayIso\n\n- [ ] Weekly task 📅 $todayIso\n');

          SharedPreferences.setMockInitialValues({'vaultPath': tempDir.path});
          final prefs = await SharedPreferences.getInstance();
          final container = ProviderContainer(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const CitrineApp(),
            ),
          );
          await waitUntil(
            tester,
            () => find.text('Plan & Review').evaluate().isNotEmpty,
          );

          await tester.tap(find.text('Plan & Review').first);
          await waitUntil(
            tester,
            () =>
                find
                    .text('Weekly Plan & Review · Pure Data View')
                    .evaluate()
                    .isNotEmpty &&
                find.byType(CitrineDataViewCard).evaluate().length >= 2,
          );

          // Pure UI data views have drag handles, but no markdown Source Mode button
          expect(find.byTooltip('Source Mode'), findsNothing);
          final dragHandles = find.byTooltip('Drag to reorder');
          expect(dragHandles, findsAtLeastNWidgets(2));

          final cardsBefore = tester
              .widgetList<CitrineDataViewCard>(find.byType(CitrineDataViewCard))
              .toList();
          final firstTitleBefore = cardsBefore[0].query.resolvedTitle;
          final secondTitleBefore = cardsBefore[1].query.resolvedTitle;

          await tester.ensureVisible(dragHandles.at(1));
          await tester.pumpAndSettle();
          final firstHandleCenter = tester.getCenter(dragHandles.first);
          final secondHandleCenter = tester.getCenter(dragHandles.at(1));
          await tester.timedDragFrom(
            secondHandleCenter,
            Offset(0, firstHandleCenter.dy - secondHandleCenter.dy - 20),
            const Duration(milliseconds: 300),
          );
          await tester.pumpAndSettle();

          final cardsAfter = tester
              .widgetList<CitrineDataViewCard>(find.byType(CitrineDataViewCard))
              .toList();
          expect(cardsAfter[0].query.resolvedTitle, secondTitleBefore);
          expect(cardsAfter[1].query.resolvedTitle, firstTitleBefore);

          final savedOrder =
              container.read(workspaceStateProvider).cadenceDataViewOrder['weekly'];
          expect(savedOrder, isNotNull);
          expect(savedOrder!.first, contains(secondTitleBefore));
        });
      },
    );
  });
}
