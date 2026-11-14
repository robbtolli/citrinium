import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/clock/app_clock.dart';
import '../core/index/index_providers.dart';
import '../core/notifications/notification_service.dart';
import '../core/workspace/workspace_state.dart';
import '../features/actions/actions_inbox_screen.dart';
import '../features/documents/document_list_screen.dart';
import '../features/horizons/horizons_review_screen.dart';
import '../features/search/search_dialog.dart';
import '../features/today/today_combined_screen.dart';
import '../shared/widgets/citrine_emblem.dart';
import '../shared/widgets/citrine_help_sheet.dart';
import '../shared/widgets/debug_date_override_dialog.dart';
import '../shared/widgets/planning_review_ritual_sheet.dart';
import '../shared/widgets/quick_capture_bar.dart';

enum AppPillar {
  today(
    label: 'Today',
    icon: Icons.wb_sunny_outlined,
    selectedIcon: Icons.wb_sunny,
  ),
  actions(
    label: 'Actions & Inbox',
    icon: Icons.check_circle_outline,
    selectedIcon: Icons.check_circle,
  ),
  horizons(
    label: 'Horizons & Review',
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
  ),
  notes(
    label: 'Notes & Index',
    icon: Icons.library_books_outlined,
    selectedIcon: Icons.library_books,
  );

  const AppPillar({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The Hybrid Dual-Track application shell (`design.md` §6.2):
/// - 4 Primary Pillars: Today, Actions & Inbox, Horizons & Review, Notes & Index
/// - Responsive layout (NavigationRail on wide desktop, NavigationBar on narrow/mobile)
/// - `🕒 Recent` Views & Documents switcher (`N-04`, `A-08`)
/// - `🔍 Quick Switcher` (`N-04`, `N-03`)
/// - Persistent bottom `QuickCaptureBar` with sticky `[ Inbox | Today ]` toggle (`C-01`)
class AppShellScaffold extends ConsumerStatefulWidget {
  const AppShellScaffold({
    this.initialPillar = AppPillar.today,
    super.key,
  });

  final AppPillar initialPillar;

  @override
  ConsumerState<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends ConsumerState<AppShellScaffold> {
  late AppPillar _pillar;
  bool _checkedTwoHourRestore = false;

  @override
  void initState() {
    super.initState();
    _pillar = widget.initialPillar;
  }

  void _checkTwoHourSessionRestore(
    WorkspaceState workspace,
    List<Document> docs,
  ) {
    if (_checkedTwoHourRestore) return;
    _checkedTwoHourRestore = true;

    final now = ref.read(appClockProvider).now();
    final recent = workspace.mostRecentItem;
    if (recent != null && workspace.isWithinTwoHourWindow(now)) {
      final doc = docs.where((d) => d.relPath == recent.relPath).firstOrNull;
      if (doc != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Session active (<2h ago): ${recent.displayLabel}',
              ),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () {
                  context.push('/documents/${doc.id}', extra: doc);
                },
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        });
      }
    }
  }

  void _openRecentSwitcher(BuildContext context, List<Document> allDocs) {
    final workspace = ref.read(workspaceStateProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Views & Documents (Pick up where you left off)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (workspace.recentItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No recently opened documents yet.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: workspace.recentItems.length,
                    itemBuilder: (context, index) {
                      final r = workspace.recentItems[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.description_outlined),
                        title: Text(r.displayLabel),
                        subtitle: Text('${r.relPath} · ${r.docType}'),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          final target = allDocs
                              .where((d) => d.relPath == r.relPath)
                              .firstOrNull;
                          if (target != null) {
                            context.push(
                              '/documents/${target.id}',
                              extra: target,
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openQuickSwitcherDialog(BuildContext context, List<Document> allDocs) {
    SearchDialog.show(context);
  }

  Widget _buildDrawer(BuildContext context, List<Document> allDocs) {
    final debugEnabled = ref.watch(debugModeProvider);
    final clock = ref.watch(appClockProvider);
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/icons/citrine_icon.png',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const CitrineEmblem(size: 52),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Citrine',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Calm planning & notes',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Recent Views & Documents'),
              onTap: () {
                Navigator.of(context).pop();
                _openRecentSwitcher(context, allDocs);
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Planning Process Setup'),
              onTap: () {
                Navigator.of(context).pop();
                showProcessCustomizerDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Field Guide & Help'),
              onTap: () {
                Navigator.of(context).pop();
                showCitrineHelpSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About Citrine'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/about');
              },
            ),
            if (debugEnabled) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'DEBUG',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              ListTile(
                key: const Key('drawer-debug-override-date'),
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Override Current Date'),
                subtitle: Text(
                  clock.isOverridden
                      ? 'Active: ${clock.todayIso}'
                      : 'Using real system date',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  showDebugDateOverrideDialog(context, ref);
                },
              ),
              ListTile(
                key: const Key('drawer-debug-disable'),
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Disable Debug Mode'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref.read(debugModeProvider.notifier).setEnabled(false);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceStateProvider);
    final docsAsync = ref.watch(documentListProvider);
    final reminders = ref.watch(rollingReminderWindowProvider);
    final clock = ref.watch(appClockProvider);
    final allDocs = docsAsync.value ?? const [];

    if (docsAsync.hasValue) {
      _checkTwoHourSessionRestore(workspace, allDocs);
    }

    final isWide = MediaQuery.of(context).size.width >= 760;

    final bodyContent = switch (_pillar) {
      AppPillar.today => const TodayCombinedScreen(),
      AppPillar.actions => const ActionsInboxScreen(),
      AppPillar.horizons => const HorizonsReviewScreen(),
      AppPillar.notes => const DocumentListScreen(embeddedInShell: true),
    };

    return Scaffold(
      drawer: _buildDrawer(context, allDocs),
      appBar: AppBar(
        title: const Text('Citrine'),
        actions: [
          // Recent Views / Documents switcher (N-04, A-08)
          TextButton.icon(
            onPressed: () => _openRecentSwitcher(context, allDocs),
            icon: const Icon(Icons.history, size: 18),
            label: Text(
              workspace.recentItems.isEmpty
                  ? 'Recent'
                  : 'Recent (${workspace.recentItems.length})',
            ),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: reminders.isNotEmpty,
              label: Text('${reminders.length}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Reminders & Snooze',
            onPressed: () => showRemindersCenterSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Quick Switcher & Search',
            onPressed: () => _openQuickSwitcherDialog(context, allDocs),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Field Guide & Help',
            onPressed: () => showCitrineHelpSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (clock.isOverridden)
            Material(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        onTap: () => showDebugDateOverrideDialog(context, ref),
                        child: Text(
                          'Debug Date: ${clock.todayIso}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onTertiaryContainer,
                              ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(appClockProvider.notifier).stepDays(-1),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 28),
                      ),
                      child: const Text('-1d'),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(appClockProvider.notifier).stepDays(1),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 28),
                      ),
                      child: const Text('+1d'),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(appClockProvider.notifier).reset(),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 28),
                      ),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: isWide
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _pillar.index,
                        labelType: NavigationRailLabelType.all,
                        onDestinationSelected: (idx) {
                          setState(() => _pillar = AppPillar.values[idx]);
                        },
                        destinations: [
                          for (final p in AppPillar.values)
                            NavigationRailDestination(
                              icon: Icon(p.icon),
                              selectedIcon: Icon(p.selectedIcon),
                              label: Text(p.label),
                            ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: bodyContent),
                    ],
                  )
                : bodyContent,
          ),
          const QuickCaptureBar(),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _pillar.index,
              onDestinationSelected: (idx) {
                setState(() => _pillar = AppPillar.values[idx]);
              },
              destinations: [
                for (final p in AppPillar.values)
                  NavigationDestination(
                    icon: Icon(p.icon),
                    selectedIcon: Icon(p.selectedIcon),
                    label: p.label,
                  ),
              ],
            ),
    );
  }
}
