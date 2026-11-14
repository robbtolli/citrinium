import 'dart:io';

import 'package:citrine/app/citrine_app.dart';
import 'package:citrine/core/vault/vault_path_provider.dart';
import 'package:citrine/core/workspace/workspace_state.dart';
import 'package:citrine_core/citrine_core.dart';
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

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late Directory vault;
  late Directory appSupport;

  setUp(() async {
    vault = await Directory.systemTemp.createTemp('citrine_plan_review_vault');
    appSupport = await Directory.systemTemp.createTemp(
      'citrine_plan_review_appsupport',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(appSupport);

    await File(
      p.join(vault.path, 'inbox.md'),
    ).writeAsString('- [ ] Call pharmacy @phone\n');
    await File(
      p.join(vault.path, 'note.md'),
    ).writeAsString('# Meeting Notes\n\n- [ ] Send summary @computer\n');
  });

  tearDown(() async {
    await vault.delete(recursive: true);
    await appSupport.delete(recursive: true);
  });

  testWidgets(
    'Daily Bookends bar on Today supports Stage 1->2 Progressive Learning, Rule of 1 Floor Day, Morning Plan (Full & Minimal), and 1-click Disable Guidance',
    (tester) async {
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({'vaultPath': vault.path});
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
        await tester.pump();

        await _waitUntil(
          tester,
          () =>
              find.textContaining('Today\'s Focus Shelf').evaluate().isNotEmpty &&
              find.text('Meeting Notes').evaluate().isNotEmpty &&
              find.text('🌅 Morning Plan').evaluate().isNotEmpty,
        );

        // In Stage 1 (Capture & Morning Top-3 Launch), Morning Plan, Express Plan,
        // and Rule of 1 are visible while Evening Shutdown awaits Stage 2 unlock.
        expect(find.text('🌅 Morning Plan'), findsOneWidget);
        expect(find.text('⚡ 2m Express Plan'), findsOneWidget);
        expect(find.text('🛟 Low-Energy Day (Just 1 Thing)'), findsOneWidget);
        expect(find.text('🌇 Evening Shutdown'), findsNothing);

        // Toggle Rule of 1 (Floor Day) on Today
        await tester.tap(find.text('🛟 Low-Energy Day (Just 1 Thing)'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.textContaining('Low-Energy Day'), findsWidgets);

        // Launch Morning Plan ritual modal
        await tester.tap(find.text('🌅 Morning Plan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.textContaining('Daily Morning Plan · Step 1 of 4'),
          findsOneWidget,
        );
        expect(find.textContaining('Why this works:'), findsOneWidget);

        // Switch between Full and ⚡ Minimal inside the ritual modal
        await tester.tap(find.textContaining('⚡ Minimal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        // In Minimal mode for Citrine Morning Plan, there is 1 essential step
        expect(
          find.textContaining('Daily Morning Plan · Step 1 of 1'),
          findsOneWidget,
        );

        await tester.tap(find.text('Complete Morning Plan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        await _waitUntil(
          tester,
          () => find.text('🌅 Morning Plan ✓').evaluate().isNotEmpty,
        );
        expect(find.text('🌅 Morning Plan ✓'), findsOneWidget);
        // Completing Morning Plan unlocks Stage 2 (Evening Shutdown)!
        expect(find.text('🌇 Evening Shutdown'), findsOneWidget);

        // Verify 1-click Disable Guidance hides the coaching banner
        final disableBtn = find.text('Disable Guidance');
        await tester.ensureVisible(disableBtn);
        await tester.pump();
        await tester.tap(disableBtn);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await tester.pump();
        expect(find.text('Disable Guidance'), findsNothing);
      });
    },
  );

  testWidgets(
    'Process Studio supports switching Presets, Custom Steps, and Freeform Markdown mode',
    (tester) async {
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({'vaultPath': vault.path});
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
        await tester.pump();

        await _waitUntil(
          tester,
          () =>
              find.text('Meeting Notes').evaluate().isNotEmpty &&
              find.text('Customize / Own Process').evaluate().isNotEmpty,
        );

        // Open Process Studio from Today
        await tester.tap(find.text('Customize / Own Process'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.text('Planning & Review Process Studio'),
          findsOneWidget,
        );

        // Select Ivy Lee preset
        final ivyFinder = find.text('Ivy Lee 6-Task Sequential Method');
        await tester.ensureVisible(ivyFinder);
        await tester.pump();
        await tester.tap(ivyFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Switch execution mode to Freeform Markdown
        final freeformFinder = find.text('Freeform Markdown');
        await tester.ensureVisible(freeformFinder);
        await tester.pump();
        await tester.tap(freeformFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          find.text('Freeform Markdown Mode Enabled'),
          findsOneWidget,
        );

        // Close Process Studio
        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Verify WorkspaceState updated to Freeform Markdown for Daily Morning Plan
        final config = container
            .read(workspaceStateProvider)
            .configForRitual(RitualKind.dailyMorningPlan);
        expect(config.executionMode, CadenceExecutionMode.freeformMarkdown);
        expect(config.selectedPresetId, 'ivy_lee_morning');
      });
    },
  );
}
