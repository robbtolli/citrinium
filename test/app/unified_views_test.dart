import 'dart:io';

import 'package:citrine/app/citrine_app.dart';
import 'package:citrine/core/vault/vault_path_provider.dart';
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
            '- [ ] Finish unified today view 📅 $todayIso\n\n'
            '```citrine\n'
            'view: tasks\n'
            'filter: due-today\n'
            'include_overdue: true\n'
            '```\n',
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

          // Embedded citrine data view block and Insert Data View button render inline
          expect(find.byType(CitrineDataViewCard), findsAtLeastNWidgets(1));
          expect(find.text('Tasks Due Today'), findsAtLeastNWidgets(1));
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
  });
}
