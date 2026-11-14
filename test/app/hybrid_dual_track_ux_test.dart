import 'dart:io';

import 'package:citrine/app/citrine_app.dart';
import 'package:citrine/core/plugins/plugin_providers.dart';
import 'package:citrine/core/vault/vault_path_provider.dart';
import 'package:citrine/core/vault/vault_setup.dart';
import 'package:citrine/core/workspace/workspace_state.dart';
import 'package:citrine/features/plugins/plugin_consent_dialog.dart';
import 'package:citrine/features/plugins/plugins_screen.dart';
import 'package:citrine/features/settings/settings_screen.dart';
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
    vault = await Directory.systemTemp.createTemp('citrine_ux_vault');
    appSupport = await Directory.systemTemp.createTemp(
      'citrine_ux_appsupport',
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
            child: const CitrineApp(),
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
        expect(find.textContaining('Schedule & Events'), findsOneWidget);

        // 4. Navigate to Horizons & Review pillar and verify Weekly cadence (B-02, B-12)
        await tester.tap(find.text('Plan & Review'));
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
            child: const CitrineApp(),
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
        expect(find.text('File to Reference'), findsOneWidget);
        expect(find.text('Schedule on Calendar'), findsOneWidget);

        // File the inbox item to Reference
        await tester.ensureVisible(find.text('File to Reference'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('File to Reference'));
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

        expect(find.textContaining('Projects move faster when they have a clear Outcome'), findsOneWidget);
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

  testWidgets(
    'M4 & M5: Daily Migration (B-06, R-02), Cadence Templates (B-11), and On-Demand Collections (B-04, B-10)',
    (tester) async {
      await tester.runAsync(() async {
        final dailyDir = Directory(p.join(vault.path, 'daily'));
        await dailyDir.create(recursive: true);
        await File(p.join(dailyDir.path, '2020-01-01.md')).writeAsString(
          '---\ncitrine:\n  type: dailyLog\n---\n# Old Day\n- [ ] Carry forward tax receipt @home\n',
        );

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

        // Wait for past daily migration banner (B-06, B-09)
        await _waitUntil(
          tester,
          () => find.text('Review & Migrate').evaluate().isNotEmpty,
        );

        await tester.tap(find.text('Review & Migrate'));
        await tester.pumpAndSettle();

        expect(find.text('Carry forward tax receipt @home'), findsWidgets);
        expect(find.text('Move to Today'), findsOneWidget);

        await tester.tap(find.text('Move to Today'));
        await tester.pump();

        final todayRel = CadenceFiles.dailyRelPath(DateTime.now());
        await _waitUntil(
          tester,
          () => File(p.join(vault.path, todayRel)).existsSync(),
        );

        final oldDayContent =
            await File(p.join(vault.path, 'daily', '2020-01-01.md'))
                .readAsString();
        expect(oldDayContent, isNot(contains('Carry forward tax receipt @home')));

        // Switch to Notes & Index (B-04) and create an on-demand Collection (B-10)
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Notes & Index'));
        await tester.pump(const Duration(milliseconds: 400));

        await _waitUntil(
          tester,
          () => find.textContaining('Index:').evaluate().isNotEmpty,
        );
        await tester.tap(find.text('+ Collection'));
        await tester.pump(const Duration(milliseconds: 400));

        await tester.enterText(
          find.widgetWithText(TextField, 'Title'),
          'Reading List',
        );
        await tester.tap(find.text('Create'));
        await tester.pump();

        await _waitUntil(
          tester,
          () => File(p.join(vault.path, 'collections', 'reading-list.md'))
              .existsSync(),
        );

        // Switch to Horizons & Review and open Templates dialog (B-11)
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Plan & Review'));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Templates'), findsOneWidget);
        await tester.tap(find.text('Templates'));
        await _waitUntil(
          tester,
          () => find.text('Save Template').evaluate().isNotEmpty,
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Planning Templates'), findsOneWidget);
        await tester.tap(find.text('Save Template'));
        await tester.pump();

        await _waitUntil(
          tester,
          () => File(p.join(vault.path, '.citrine', 'templates', 'weekly.md'))
              .existsSync(),
        );
      });
    },
  );

  testWidgets(
    'M7 & M8: Recurrence & Habit Tracking (D-16, D-17) and Contextual Reminders & Snooze (E-08, E-10, E-11, E-12)',
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
          () => find.text('Meeting Notes').evaluate().isNotEmpty,
        );

        await tester.tap(find.text('Actions & Inbox'));
        await tester.pumpAndSettle();

        // Expand "Send summary @computer" in-place editor
        await tester.tap(find.text('Send summary @computer'));
        await tester.pumpAndSettle();

        // Set 🔁 Weekday recurrence in-place (D-16)
        await tester.ensureVisible(find.text('🔁 Weekday'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('🔁 Weekday'));
        await tester.pump();

        await _waitUntil(
          tester,
          () => File(p.join(vault.path, 'note.md'))
              .readAsStringSync()
              .contains('🔁 every weekday'),
        );

        // Tap ⏰ Snooze / Remind -> triggers contextual permission prompt (E-11)
        await tester.ensureVisible(find.text('⏰ Snooze / Remind'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('⏰ Snooze / Remind'));
        await tester.pumpAndSettle();

        expect(find.text('Enable Gentle Reminders?'), findsOneWidget);
        await tester.tap(find.text('Enable Notifications'));
        await tester.pumpAndSettle();

        // Now inside Reminder & Snooze dialog (E-08, E-10, E-12)
        expect(find.text('Reminder & Snooze'), findsOneWidget);
        await tester.tap(find.text('Snooze +15m'));
        await tester.pumpAndSettle();

        // Open 🔔 Reminders center from AppBar and verify snoozed reminder with direct actions
        await tester.tap(find.byTooltip('Reminders & Snooze'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('/64 rolling window)'),
          findsOneWidget,
        );
        expect(find.text('Snoozed'), findsOneWidget);
        expect(find.text('Tomorrow'), findsWidgets);
      });
    },
  );

  testWidgets(
    'NUX: First-launch "Get Started" provisions Starter Vault with sample tasks, Top-3 Focus Shelf pin, and Getting Started banner',
    (tester) async {
      await tester.runAsync(() async {
        final starterTemp = await Directory.systemTemp.createTemp(
          'citrine_nux_starter',
        );
        addTearDown(() => starterTemp.delete(recursive: true));
        debugSetDefaultStarterVaultPath(starterTemp.path);
        addTearDown(() => debugSetDefaultStarterVaultPath(null));

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final starterContainer = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(starterContainer.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: starterContainer,
            child: const CitrineApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Intro screen verification: 4 pillars
        expect(find.text('Welcome to Citrine'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Actions & Inbox'), findsOneWidget);
        expect(find.text('Plan & Review'), findsOneWidget);
        expect(find.text('Notes & Index'), findsOneWidget);

        // Tap "Get Started"
        await tester.ensureVisible(find.text('Get Started'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Get Started'));
        await tester.pump();

        // Wait for indexer and Today screen to mount
        await _waitUntil(
          tester,
          () =>
              find
                  .textContaining('Today\'s Focus Shelf (1/3 Top Focus)')
                  .evaluate()
                  .isNotEmpty,
        );

        // Today's Focus Shelf has the pre-pinned tutorial task
        expect(find.textContaining('Today\'s Focus Shelf (1/3 Top Focus)'), findsOneWidget);
        expect(find.textContaining('Tap this task to edit it in-place'), findsOneWidget);

        // Getting Started checklist banner is visible
        expect(find.textContaining('Getting Started with Citrine'), findsOneWidget);

        // Tap Field Guide button in banner
        await tester.tap(find.text('Field Guide'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Citrine Field Guide & Help'), findsOneWidget);
        expect(find.text('Hands-On Learning Checklist'), findsOneWidget);
        expect(find.text('4 Pillars & Recipes'), findsOneWidget);
        expect(find.text('Syntax Cheat Sheet'), findsOneWidget);

        // Close Field Guide
        await tester.tap(find.byTooltip('Close'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
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
    expect(md, contains('# Citrine Operational Data Export'));
    expect(md, contains('note.md:2'));
    expect(md, contains('2026-10-28'));
    expect(md, contains('[[note.md|Meeting Notes]]'));

    final jsonStr = state.exportToJson();
    expect(jsonStr, contains('"topThreePinnedKeys"'));
    expect(jsonStr, contains('"habitCompletionsByDate"'));
    expect(jsonStr, contains('"weeklyReviewStep"'));
  });

  testWidgets(
    'M9: Notes Linking (N-02, D-12) and Full-Text Faceted Search (N-03, N-04, FR-06)',
    (tester) async {
      await tester.runAsync(() async {
        // Seed note referencing Meeting Notes without [[...]] (unlinked mention)
        await File(p.join(vault.path, 'project-a.md')).writeAsString(
          '# Project Alpha\n\n- [ ] Discuss Meeting Notes with team\n',
        );

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
          () => find.text('Meeting Notes').evaluate().isNotEmpty,
        );

        // 1. Open Search & Quick Switcher Dialog via AppBar search icon (N-04)
        await tester.tap(find.byIcon(Icons.search).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Search & Quick Switcher'), findsOneWidget);
        expect(find.text('All'), findsOneWidget);
        expect(find.text('Notes'), findsOneWidget);

        // Filter by Notes
        await tester.tap(find.text('Notes'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Close search dialog
        await tester.tap(find.text('Close'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 2. Open "Meeting Notes" document
        final meetingNotesTile = find.text('Meeting Notes').first;
        await tester.ensureVisible(meetingNotesTile);
        await tester.tap(meetingNotesTile);
        await _waitUntil(
          tester,
          () => find.textContaining('Backlinks').evaluate().isNotEmpty,
        );

        // Expand Backlinks panel
        final backlinksTile = find.textContaining('Backlinks');
        expect(backlinksTile, findsOneWidget);
        await tester.tap(backlinksTile);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Verify Unlinked Mentions section is surfaced (N-02, D-12)
        expect(find.textContaining('UNLINKED MENTIONS'), findsOneWidget);
        expect(find.text('Link'), findsOneWidget);

        // Tap "Link" button to wrap the mention in [[Meeting Notes]]
        await tester.tap(find.text('Link'));
        await _waitUntil(
          tester,
          () => File(p.join(vault.path, 'project-a.md'))
              .readAsStringSync()
              .contains('[[Meeting Notes]]'),
        );

        // Verify the source file on disk was updated to [[Meeting Notes]]
        final updatedProjectFile = await File(p.join(vault.path, 'project-a.md')).readAsString();
        expect(updatedProjectFile, contains('[[Meeting Notes]]'));
      });
    },
  );

  testWidgets(
    'M10: Guided Weekly Review (R-01, R-03), Resumable Progress (R-04), and Reminder (R-05)',
    (tester) async {
      await tester.runAsync(() async {
        // Seed zombie project (zero open tasks) and stale task (old file)
        final projectsDir = Directory(p.join(vault.path, 'projects'));
        await projectsDir.create(recursive: true);
        await File(p.join(projectsDir.path, 'zombie.md')).writeAsString(
          '---\ntitle: Zombie Project\n---\n# Zombie Project\nProse description with no open tasks.\n',
        );

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
          () => find.text('Meeting Notes').evaluate().isNotEmpty,
        );

        // 1. Navigate to Horizons & Review
        await tester.tap(find.text('Plan & Review').first);
        await tester.pumpAndSettle();

        // Tap Weekly Review button
        final reviewButton = find.text('Start Weekly Review').first;
        await tester.ensureVisible(reviewButton);
        await tester.tap(reviewButton);
        await tester.pumpAndSettle();

        // Step 1: Get Clear (Inbox Zero)
        expect(find.textContaining('1. Get Clear (Inbox Zero)'), findsOneWidget);
        expect(find.text('Call pharmacy @phone'), findsOneWidget);

        // Clarify inbox item by clicking "Next Action"
        await tester.tap(find.text('Next Action').first);
        await _waitUntil(
          tester,
          () => find.textContaining('Inbox Zero Achieved!').evaluate().isNotEmpty,
        );

        // Proceed to Step 2: Get Current
        await tester.tap(find.text('Next Step →'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('2. Get Current'), findsOneWidget);

        // Test Resumability (R-04): Save & Close mid-session
        await tester.tap(find.text('Save & Close'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Reopen Weekly Review
        final reopenButton = find.text('Start Weekly Review').first;
        await tester.ensureVisible(reopenButton);
        await tester.tap(reopenButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verifies it resumes at Step 2!
        expect(find.textContaining('Resumed review at Step 2'), findsOneWidget);

        // Proceed to Step 3: Get Creative & Stale Review (R-03)
        await tester.tap(find.text('Next Step →'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('3. Get Creative & Stale Review'), findsOneWidget);
        expect(find.textContaining('No guilt here — life evolves!'), findsOneWidget);

        // Proceed to Step 4: Choose Outcomes & Intentions
        await tester.tap(find.text('Next Step →'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('4. Choose Outcomes & Intentions'), findsOneWidget);

        // Enter key outcome and finish
        await tester.enterText(
          find.byType(TextField).last,
          'Ship Citrine M9 & M10 @computer',
        );
        await tester.tap(find.textContaining('Finish Weekly Review'));
        await _waitUntil(
          tester,
          () => find.textContaining('Weekly Review complete!').evaluate().isNotEmpty,
        );
        // Wait for modal bottom sheet dismiss animation to finish
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        // 2. Check Settings for Weekly Review Reminder (R-05)
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await _waitUntil(
          tester,
          () => find.text('Settings').evaluate().isNotEmpty,
        );

        final settingsScrollable = find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        );

        final reminderSwitch = find.widgetWithText(
          SwitchListTile,
          'Weekly Review Reminder',
        );
        await tester.scrollUntilVisible(
          reminderSwitch,
          200,
          scrollable: settingsScrollable,
        );
        expect(reminderSwitch, findsOneWidget);
        await tester.tap(reminderSwitch);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final scheduleSection = find.text('Reminder Schedule');
        await tester.scrollUntilVisible(
          scheduleSection,
          100,
          scrollable: settingsScrollable,
        );
        expect(scheduleSection, findsOneWidget);
      });
    },
  );

  testWidgets(
    'M11: Plugin Architecture (PL-01), Consent (PL-02, PL-03), Revocation (PL-04), and Core Plugins (PL-08)',
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

        // 1. Navigate to Settings
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await _waitUntil(
          tester,
          () => find.text('Settings').evaluate().isNotEmpty,
        );

          final settingsScrollable = find.descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          );

          final pluginsTile = find.text('Plugin Manager (QuickJS Sandbox)');
          await tester.scrollUntilVisible(
            pluginsTile,
            200,
            scrollable: settingsScrollable,
          );
          expect(pluginsTile, findsOneWidget);

          // 2. Open Plugins Screen (PL-01)
          await tester.tap(pluginsTile);
          await _waitUntil(
            tester,
            () => find.text('Core Built-In Plugins').evaluate().isNotEmpty,
          );

          // 3. Verify Built-In Core Plugins (PL-08)
          expect(find.text('Core Built-In Plugins'), findsOneWidget);
          expect(find.text('Daily Rapid Logging'), findsOneWidget);
          expect(find.text('Cadence Templates'), findsOneWidget);
          expect(find.text('GTD Clarify Flow'), findsOneWidget);
          expect(find.text('Schedule & Events Calendar'), findsOneWidget);

          // 4. Verify Discovered Community Plugins & Install Consent (PL-02, PL-03)
          final pluginsScrollable = find.descendant(
            of: find.byType(PluginsScreen),
            matching: find.byType(Scrollable),
          );

          final communityHeader = find.text('Community Plugins');
          await tester.scrollUntilVisible(
            communityHeader,
            150,
            scrollable: pluginsScrollable,
          );
          expect(communityHeader, findsOneWidget);

          // Wait for community plugins async discovery to finish
          await _waitUntil(
            tester,
            () => container.read(installedPluginsProvider).hasValue &&
                  container.read(installedPluginsProvider).value!.isNotEmpty,
          );
          await tester.pumpAndSettle();

          final installWordCounterBtn =
              find.byKey(const ValueKey('install_btn_com.citrine.word-counter'));
          await tester.scrollUntilVisible(
            installWordCounterBtn,
            150,
            scrollable: pluginsScrollable,
          );
          await tester.ensureVisible(installWordCounterBtn);
          await tester.pumpAndSettle();
          await tester.tap(installWordCounterBtn);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // 5. Verify All-or-Nothing Install Consent Dialog (PL-03)
          expect(find.byType(PluginConsentDialog), findsOneWidget);
          expect(find.textContaining('Requested Permissions'), findsOneWidget);

          // Grant all and install
          await tester.tap(find.text('Grant All & Install'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          // 6. Verify plugin is now installed and has Run & Revoke actions (PL-04)
          await _waitUntil(
            tester,
            () => find.byKey(const ValueKey('run_btn_com.citrine.word-counter')).evaluate().isNotEmpty,
          );
          expect(find.byKey(const ValueKey('run_btn_com.citrine.word-counter')), findsOneWidget);
          expect(find.byKey(const ValueKey('revoke_btn_com.citrine.word-counter')), findsOneWidget);

          // Clear any active SnackBars so they don't intercept hit tests
          ScaffoldMessenger.of(tester.element(find.byType(PluginsScreen))).clearSnackBars();
          await tester.pumpAndSettle();

          // 7. Revoke plugin (PL-04)
          final revokeBtn =
              find.byKey(const ValueKey('revoke_btn_com.citrine.word-counter'));
          await tester.ensureVisible(revokeBtn);
          await tester.pumpAndSettle();
          await tester.tap(revokeBtn);
          await tester.pumpAndSettle();

          // Confirm revocation in dialog
          final confirmRevoke = find.widgetWithText(FilledButton, 'Revoke & Uninstall');
          expect(confirmRevoke, findsOneWidget);
          await tester.tap(confirmRevoke);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await _waitUntil(
            tester,
            () => find.textContaining('Revoked and uninstalled').evaluate().isNotEmpty,
          );
          expect(find.textContaining('Revoked and uninstalled'), findsOneWidget);
        });
      },
    );
}
