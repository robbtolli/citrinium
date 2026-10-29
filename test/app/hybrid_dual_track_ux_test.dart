import 'dart:io';

import 'package:citrinium/app/citrinium_app.dart';
import 'package:citrinium/core/vault/vault_path_provider.dart';
import 'package:citrinium/core/workspace/workspace_state.dart';
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
    vault = await Directory.systemTemp.createTemp('citrinium_ux_vault');
    appSupport = await Directory.systemTemp.createTemp(
      'citrinium_ux_appsupport',
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
    'Hybrid Dual-Track UX: Today Focus Shelf, In-Place Task Editing (D-19), '
    'and Configurable Cadences (B-12)',
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
            child: const CitriniumApp(),
          ),
        );
        await tester.pump();

        await _waitUntil(
          tester,
          () => find.textContaining('Today\'s Focus Shelf').evaluate().isNotEmpty &&
              find.text('Meeting Notes').evaluate().isNotEmpty,
        );

        // 1. Today's Combined View shows Today's Focus Shelf and Quick Capture Bar
        expect(find.textContaining('Today\'s Focus Shelf'), findsOneWidget);
        expect(find.text('Inbox'), findsWidgets);
        expect(find.text('Today'), findsWidgets);

        // 2. Navigate to Actions & Inbox pillar and edit a task in-place (D-19)
        // without navigating away to the containing note!
        await tester.tap(find.text('Actions & Inbox'));
        await tester.pumpAndSettle();

        expect(find.text('Send summary @computer'), findsOneWidget);

        // Tap the task row to expand the in-place editor
        await tester.tap(find.text('Send summary @computer'));
        await tester.pumpAndSettle();

        expect(
          find.text('Edit task in-place (updates source .md file)'),
          findsOneWidget,
        );

        // Edit the task text AND indented note/comment (D-14, D-18) in-place and click Save
        final editField = find.widgetWithText(
          TextField,
          'Edit task in-place (updates source .md file)',
        );
        final childNoteField = find.widgetWithText(
          TextField,
          'Indented note / comment (stored beneath line in .md)',
        );
        await tester.enterText(editField, 'Send updated Q4 summary @computer');
        await tester.enterText(childNoteField, 'Include slides link');
        await tester.tap(find.text('Save'));
        await tester.pump();

        await _waitUntil(
          tester,
          () => File(p.join(vault.path, 'note.md'))
              .readAsStringSync()
              .contains('Include slides link'),
        );

        final updatedNoteContent =
            await File(p.join(vault.path, 'note.md')).readAsString();
        expect(
          updatedNoteContent,
          '# Meeting Notes\n\n- [ ] Send updated Q4 summary @computer\n  Include slides link\n',
        );

        // 3. Verify Hard-Landscape Calendar tab (G-05) and Projects / Clarify (M2 & M3)
        await tester.tap(find.text('📅 Calendar'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Hard-Landscape Calendar'), findsOneWidget);

        // 4. Navigate to Horizons & Review pillar and verify Weekly cadence (B-02, B-12)
        await tester.tap(find.text('Horizons & Review'));
        await tester.pumpAndSettle();

        expect(find.text('Weekly'), findsWidgets);
        expect(find.textContaining('weekly/'), findsWidgets);
      });
    },
  );

  testWidgets(
    'M2 & M3: GTD Clarify Flow (G-01) files to Reference (D-07) and New Project dialog prompts for Outcome & Next Action (G-03)',
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
            child: const CitriniumApp(),
          ),
        );
        await tester.pump();

        await _waitUntil(
          tester,
          () =>
              find.textContaining('Today\'s Focus Shelf').evaluate().isNotEmpty &&
              find.text('Meeting Notes').evaluate().isNotEmpty,
        );

        await tester.tap(find.text('Actions & Inbox'));
        await tester.pumpAndSettle();

        // Open Inbox tab and launch Clarify Deck (G-01)
        await tester.tap(find.textContaining('📥 Inbox'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Clarify (1)'), findsOneWidget);
        await tester.tap(find.textContaining('Clarify (1)'));
        await tester.pumpAndSettle();

        expect(find.text('Call pharmacy @phone'), findsWidgets);
        expect(find.text('File to Reference (D-07)'), findsOneWidget);
        expect(find.text('Schedule on Calendar (G-05)'), findsOneWidget);

        // File the inbox item to Reference (D-07, G-06)
        await tester.ensureVisible(find.text('File to Reference (D-07)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('File to Reference (D-07)'));
        await tester.pump();

        await _waitUntil(
          tester,
          () => File(p.join(vault.path, 'reference.md')).existsSync(),
        );

        final refContent =
            await File(p.join(vault.path, 'reference.md')).readAsString();
        expect(refContent, contains('type: reference'));
        expect(refContent, contains('- – Call pharmacy @phone'));

        // Switch to Projects tab and verify G-03 skippable warning when Outcome/Next Action omitted
        await tester.pumpAndSettle();
        await tester.tap(find.text('📁 Projects'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('New Project'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Project Name'),
          'Launch Website',
        );
        // Click Create Project without Outcome or First Next Action -> shows G-03 warning
        await tester.tap(find.text('Create Project'));
        await tester.pumpAndSettle();

        expect(find.textContaining('GTD Tip (G-03 / D-04)'), findsOneWidget);
        expect(find.text('Create Anyway (Skip)'), findsOneWidget);

        // Click Create Anyway (Skip) to confirm skippable creation
        await tester.tap(find.text('Create Anyway (Skip)'));
        await tester.pump();

        await _waitUntil(
          tester,
          () => File(p.join(vault.path, 'projects', 'launch-website.md'))
              .existsSync(),
        );
      });
    },
  );

  test('WorkspaceState operational data export is human-readable (P-11, T-02)', () {
    final state = WorkspaceState.initial().copyWith(
      topThreePinnedKeys: const ['note.md:2'],
      habitCompletionsByDate: const {
        'daily/2026-10-28.md:1': ['2026-10-28'],
      },
      recentItems: const [
        RecentWorkspaceItem(
          relPath: 'note.md',
          title: 'Meeting Notes',
          docType: 'note',
          visitedAtMs: 1700000000000,
        ),
      ],
    );

    final md = state.exportToMarkdown();
    expect(md, contains('# Citrinium Operational Data Export'));
    expect(md, contains('note.md:2'));
    expect(md, contains('2026-10-28'));
    expect(md, contains('[[note.md|Meeting Notes]]'));

    final jsonStr = state.exportToJson();
    expect(jsonStr, contains('"topThreePinnedKeys"'));
    expect(jsonStr, contains('"habitCompletionsByDate"'));
  });
}
