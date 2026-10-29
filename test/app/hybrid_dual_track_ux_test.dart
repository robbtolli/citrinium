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

        // Edit the task text in-place and click Save
        final editField = find.widgetWithText(
          TextField,
          'Edit task in-place (updates source .md file)',
        );
        await tester.enterText(editField, 'Send updated Q4 summary @computer');
        await tester.tap(find.text('Save'));
        await tester.pump();

        await _waitUntil(
          tester,
          () => File(p.join(vault.path, 'note.md'))
              .readAsStringSync()
              .contains('Send updated Q4 summary @computer'),
        );

        final updatedNoteContent =
            await File(p.join(vault.path, 'note.md')).readAsString();
        expect(
          updatedNoteContent,
          '# Meeting Notes\n\n- [ ] Send updated Q4 summary @computer\n',
        );

        // 3. Navigate to Horizons & Review pillar and verify Weekly cadence (B-02, B-12)
        await tester.tap(find.text('Horizons & Review'));
        await tester.pumpAndSettle();

        expect(find.text('Weekly'), findsWidgets);
        expect(find.textContaining('weekly/'), findsWidgets);
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
