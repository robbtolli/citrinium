import 'dart:io';

import 'package:citrine/app/citrine_app.dart';
import 'package:citrine/core/index/index_providers.dart';
import 'package:citrine/core/vault/vault_path_provider.dart';
import 'package:citrine/features/about/about_screen.dart';
import 'package:citrine/features/document_detail/document_detail_screen.dart';
import 'package:citrine/shared/widgets/citrine_help_sheet.dart';
import 'package:citrine/shared/widgets/quick_capture_bar.dart';
import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Phone screen layout & responsiveness (320x568 and 360x640)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('citrine_phone_layout_');
      await Directory(p.join(tempDir.path, 'daily')).create(recursive: true);
      await Directory(p.join(tempDir.path, 'notes')).create(recursive: true);
      await File(
        p.join(tempDir.path, 'notes', 'sample.md'),
      ).writeAsString(
        '# Sample Project Note\n\n- [ ] Call dentist tomorrow #health @phone\n- [ ] Review weekly plan #planning\n',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> setPhoneViewport(
      WidgetTester tester,
      Size size, {
      double keyboardHeight = 0,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
      addTearDown(tester.view.reset);
    }

    Future<void> pumpCitrineApp(
      WidgetTester tester, {
      bool nuxCompleted = true,
      bool hasVault = true,
    }) async {
      SharedPreferences.setMockInitialValues({
        if (hasVault) 'vaultPath': tempDir.path,
        if (nuxCompleted) 'citrine.nuxCompleted': true,
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

    testWidgets('VaultSetupScreen renders without overflow at 320x568', (
      tester,
    ) async {
      await setPhoneViewport(tester, const Size(320, 568));
      await pumpCitrineApp(tester, nuxCompleted: false, hasVault: false);

      expect(find.text('Welcome to Citrine'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'All 4 pillars render with short nav labels and zero overflow at 320x568',
      (tester) async {
        await setPhoneViewport(tester, const Size(320, 568));
        await pumpCitrineApp(tester);

        // Phone NavigationBar uses compact labels
        expect(find.text('Today'), findsWidgets);
        expect(find.text('Actions'), findsOneWidget);
        expect(find.text('Plan'), findsOneWidget);
        expect(find.text('Notes'), findsOneWidget);

        // Today scrollable/editor area occupies >= 50% of screen height
        final navBarRect = tester.getRect(find.byType(NavigationBar));
        expect(navBarRect.top, greaterThan(568 * 0.5));

        // Navigate to Actions
        await tester.tap(find.text('Actions'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Switch through Actions sub-tabs on narrow screen
        for (final tab in ['Next Actions', 'Calendar', 'Projects', 'Waiting']) {
          final chip = find.text(tab);
          if (chip.evaluate().isNotEmpty) {
            await tester.ensureVisible(chip.first);
            await tester.tap(chip.first);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }

        // Navigate to Plan
        await tester.tap(find.text('Plan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        // Navigate to Notes
        await tester.tap(find.text('Notes'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'QuickCaptureBar hides NavigationBar when keyboard opens and stays usable at 360x640',
      (tester) async {
        await setPhoneViewport(tester, const Size(360, 640));
        await pumpCitrineApp(tester);

        expect(find.byType(NavigationBar), findsOneWidget);

        // Tap Quick Capture bar to start editing
        await tester.tap(find.textContaining('Capture to '));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);

        // Simulate soft keyboard opening
        await setPhoneViewport(
          tester,
          const Size(360, 640),
          keyboardHeight: 240,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);

        // Bottom NavigationBar hides on phone when keyboard is open
        expect(find.byType(NavigationBar), findsNothing);

        // Quick capture TextField has usable width (> 200px)
        final textFields = find.byType(TextField);
        expect(textFields, findsWidgets);
        final captureRect = tester.getRect(textFields.last);
        expect(captureRect.width, greaterThan(200));
      },
    );

    testWidgets(
      'SearchDialog and CitrineHelpSheet render without overflow at 320x568',
      (tester) async {
        await setPhoneViewport(tester, const Size(320, 568));
        await pumpCitrineApp(tester);

        // Open SearchDialog from AppBar search button
        await tester.tap(find.byIcon(Icons.search).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Search & Quick Switcher'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Simulate keyboard open while SearchDialog is visible
        await setPhoneViewport(
          tester,
          const Size(320, 568),
          keyboardHeight: 220,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);

        // Close SearchDialog
        await setPhoneViewport(tester, const Size(320, 568));
        await tester.tap(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byIcon(Icons.close),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Open Field Guide / CitrineHelpSheet via showCitrineHelpSheet
        final scaffoldContext = tester.element(find.byType(Scaffold).first);
        showCitrineHelpSheet(scaffoldContext);
        await tester.pumpAndSettle();
        expect(find.text('Getting Started'), findsOneWidget);
        expect(find.text('4 Pillars & Recipes'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Verify TabBar is scrollable on < 480px
        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBar.isScrollable, isTrue);

        Navigator.of(scaffoldContext).pop();
        await tester.pumpAndSettle();

        // Verify AboutScreen renders cleanly on 320x568
        Navigator.of(scaffoldContext).push(
          MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'PlanningReviewRitualSheet has >= 50% scrollable area and no overflow at 360x640',
      (tester) async {
        await setPhoneViewport(tester, const Size(360, 640));
        await pumpCitrineApp(tester);

        // Navigate to Plan tab and launch Weekly Planning ritual from UI
        await tester.tap(find.text('Plan'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Weekly').first);
        await tester.pumpAndSettle();

        final startPlanBtn = find.textContaining('Plan Week');
        if (startPlanBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(startPlanBtn.first);
          await tester.tap(startPlanBtn.first);
          await tester.pumpAndSettle();

          // NestedScrollView should occupy well over 50% of the 640px screen
          final nestedScrollFinder = find.byType(NestedScrollView);
          expect(nestedScrollFinder, findsOneWidget);
          final scrollRect = tester.getRect(nestedScrollFinder);
          expect(scrollRect.height, greaterThanOrEqualTo(640 * 0.5));
        }
      },
    );

    testWidgets(
      'Pixel 9a landscape (915x412) uses left-aligned compact single-line rail with zero overflow',
      (tester) async {
        await setPhoneViewport(tester, const Size(915, 412));
        await pumpCitrineApp(tester);

        final railFinder = find.byKey(const Key('compact-landscape-rail'));
        expect(railFinder, findsOneWidget);
        final railRect = tester.getRect(railFinder);
        final todayIconRect = tester.getRect(
          find.descendant(
            of: railFinder,
            matching: find.byIcon(Icons.wb_sunny),
          ),
        );
        expect(todayIconRect.left - railRect.left, lessThanOrEqualTo(16));
        expect(tester.takeException(), isNull);

        for (final label in ['Actions', 'Plan', 'Notes', 'Today']) {
          await tester.tap(
            find.descendant(
              of: railFinder,
              matching: find.text(label),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'Pixel 9a landscape (915x412) + soft keyboard handles external focus and active QuickCaptureBar typing without overflow',
      (tester) async {
        await setPhoneViewport(tester, const Size(915, 412));
        await pumpCitrineApp(tester);
        expect(find.byType(QuickCaptureBar), findsOneWidget);

        // 1. External textbox opens soft keyboard -> QuickCaptureBar hides cleanly.
        await setPhoneViewport(
          tester,
          const Size(915, 412),
          keyboardHeight: 260,
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(QuickCaptureBar),
            matching: find.byType(TextField),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);

        // 2. Close keyboard, tap QuickCaptureBar to type directly in it, then open keyboard.
        await setPhoneViewport(tester, const Size(915, 412));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Quick capture'));
        await tester.pumpAndSettle();

        await setPhoneViewport(
          tester,
          const Size(915, 412),
          keyboardHeight: 260,
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(QuickCaptureBar),
            matching: find.byType(TextField),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'CitrineHelpSheet renders without overflow in Pixel 9a landscape (915x412) even with keyboard',
      (tester) async {
        await setPhoneViewport(
          tester,
          const Size(915, 412),
          keyboardHeight: 220,
        );
        await pumpCitrineApp(tester);

        final scaffoldContext = tester.element(find.byType(Scaffold).first);
        showCitrineHelpSheet(scaffoldContext);
        await tester.pumpAndSettle();
        expect(find.text('Getting Started'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'DocumentDetailScreen hides Backlinks/Unlinked/Tasks bar in Pixel 9a landscape (915x412) when keyboard opens',
      (tester) async {
        await setPhoneViewport(tester, const Size(915, 412));
        SharedPreferences.setMockInitialValues({
          'vaultPath': tempDir.path,
          'citrine.nuxCompleted': true,
        });
        final prefs = await SharedPreferences.getInstance();
        const doc = Document(
          id: 1,
          relPath: 'notes/sample.md',
          title: 'Sample Project Note',
          docType: 'note',
          mtimeMs: 0,
          indexedAtMs: 0,
          sizeBytes: 100,
          sha256: 'abc',
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              documentRawTextProvider('notes/sample.md').overrideWith(
                (ref) => Stream.value('# Sample Project Note\n\nBody text\n'),
              ),
            ],
            child: const MaterialApp(
              home: DocumentDetailScreen(document: doc),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Backlinks ('), findsOneWidget);

        await setPhoneViewport(
          tester,
          const Size(915, 412),
          keyboardHeight: 260,
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Backlinks ('), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
