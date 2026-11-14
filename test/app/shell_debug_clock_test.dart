import 'dart:io';

import 'package:citrine/app/citrine_app.dart';
import 'package:citrine/core/clock/app_clock.dart';
import 'package:citrine/core/vault/vault_path_provider.dart';
import 'package:citrine/features/about/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppClock & DebugMode providers (FR-14)', () {
    test('override date persists, steps days, and resets on disable', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(debugModeProvider), isFalse);
      expect(container.read(appClockProvider).isOverridden, isFalse);

      await container.read(debugModeProvider.notifier).setEnabled(true);
      expect(container.read(debugModeProvider), isTrue);

      await container
          .read(appClockProvider.notifier)
          .setOverrideDate(DateTime(2026, 5, 10));
      expect(container.read(appClockProvider).isOverridden, isTrue);
      expect(container.read(appClockProvider).todayIso, '2026-05-10');

      await container.read(appClockProvider.notifier).stepDays(2);
      expect(container.read(appClockProvider).todayIso, '2026-05-12');

      await container.read(appClockProvider.notifier).stepDays(-1);
      expect(container.read(appClockProvider).todayIso, '2026-05-11');

      // Disabling Debug Mode resets the overridden date back to real time.
      await container.read(debugModeProvider.notifier).setEnabled(false);
      expect(container.read(debugModeProvider), isFalse);
      expect(container.read(appClockProvider).isOverridden, isFalse);
    });
  });

  group('Hamburger Menu, About Screen & 7-Tap Debug Mode (FR-14)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('citrine_m13_test_');
      final dailyDir = Directory(p.join(tempDir.path, 'daily'));
      await dailyDir.create(recursive: true);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> pumpApp(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'vaultPath': tempDir.path,
        'citrine.nuxCompleted': true,
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const CitrineApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      '7 taps on About version unlocks Debug section and Override Current Date',
      (tester) async {
        await pumpApp(tester);

        // Open Hamburger Menu
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();

        expect(find.text('About Citrine'), findsOneWidget);
        expect(find.text('DEBUG'), findsNothing);
        expect(find.byKey(const Key('drawer-debug-override-date')), findsNothing);

        // Navigate to About Citrine
        await tester.tap(find.text('About Citrine'));
        await tester.pumpAndSettle();

        expect(find.text(citrineAppVersion), findsOneWidget);

        // Tap version 6 times -> Debug Mode still not active
        final versionTile = find.byKey(const Key('about-version-tile'));
        for (var i = 0; i < 6; i++) {
          await tester.tap(versionTile);
          await tester.pump();
        }
        expect(find.text('Debug Active'), findsNothing);

        // 7th tap enables Debug Mode
        await tester.tap(versionTile);
        await tester.pumpAndSettle();
        expect(find.text('Debug Active'), findsOneWidget);

        // Navigate back to shell and open Hamburger Menu again
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();

        expect(find.text('DEBUG'), findsOneWidget);
        expect(
          find.byKey(const Key('drawer-debug-override-date')),
          findsOneWidget,
        );

        // Open Override Current Date dialog and step +1 Day
        await tester.tap(find.byKey(const Key('drawer-debug-override-date')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('debug-date-next-day')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // Top-bar Debug Date indicator should be visible with Reset button
        expect(find.textContaining('Debug Date:'), findsOneWidget);
        expect(find.text('Reset'), findsOneWidget);

        // Tapping Reset clears the override bar
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Debug Date:'), findsNothing);
      },
    );
  });
}
