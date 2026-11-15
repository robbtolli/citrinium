import 'dart:ui' show AppExitResponse;

import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/background/background_work_manager.dart';
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
    shortLabel: 'Today',
    icon: Icons.wb_sunny_outlined,
    selectedIcon: Icons.wb_sunny,
  ),
  actions(
    label: 'Actions & Inbox',
    shortLabel: 'Actions',
    icon: Icons.check_circle_outline,
    selectedIcon: Icons.check_circle,
  ),
  horizons(
    label: 'Plan & Review',
    shortLabel: 'Plan',
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
  ),
  notes(
    label: 'Notes & Index',
    shortLabel: 'Notes',
    icon: Icons.library_books_outlined,
    selectedIcon: Icons.library_books,
  );

  const AppPillar({
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String shortLabel;
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

class _AppShellScaffoldState extends ConsumerState<AppShellScaffold>
    with WidgetsBindingObserver {
  late AppPillar _pillar;
  bool _checkedTwoHourRestore = false;

  @override
  void initState() {
    super.initState();
    _pillar = widget.initialPillar;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    final bgWork = ref.read(backgroundWorkManagerProvider);
    if (!bgWork.isRunning || !mounted) {
      return AppExitResponse.exit;
    }
    final confirm = await _showExitWhileBusyDialog(context);
    return confirm ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  Future<bool> _showExitWhileBusyDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Background task in progress'),
        content: const Text(
          'Citrine is still importing tasks in the background. '
          'Closing now may leave some files unfinished. Close anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Working'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Close Anyway'),
          ),
        ],
      ),
    );
    return result ?? false;
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
                  Expanded(
                    child: Text(
                      'Recent Views & Documents (Pick up where you left off)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(ctx).pop(),
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
    final bgWork = ref.watch(backgroundWorkManagerProvider);
    final untaggedState = ref.watch(externalUntaggedTasksProvider);
    final allDocs = docsAsync.value ?? const [];

    if (docsAsync.hasValue) {
      _checkTwoHourSessionRestore(workspace, allDocs);
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 760;
    final isCompactPhone = screenWidth < 600;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    final bodyContent = switch (_pillar) {
      AppPillar.today => const TodayCombinedScreen(),
      AppPillar.actions => const ActionsInboxScreen(),
      AppPillar.horizons => const HorizonsReviewScreen(),
      AppPillar.notes => const DocumentListScreen(embeddedInShell: true),
    };

    return PopScope(
      canPop: !bgWork.isRunning,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !bgWork.isRunning) return;
        final confirm = await _showExitWhileBusyDialog(context);
        if (confirm && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      drawer: _buildDrawer(context, allDocs),
      appBar: AppBar(
        title: const Text('Citrine'),
        actions: [
          // Recent Views / Documents switcher (N-04, A-08)
          if (isCompactPhone)
            IconButton(
              icon: Badge(
                isLabelVisible: workspace.recentItems.isNotEmpty,
                label: Text('${workspace.recentItems.length}'),
                child: const Icon(Icons.history),
              ),
              tooltip: 'Recent Views & Documents',
              onPressed: () => _openRecentSwitcher(context, allDocs),
            )
          else
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
          if (!isCompactPhone) ...[
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
          if (untaggedState.shouldShowBanner)
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: isCompactPhone
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.task_alt_outlined,
                                size: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'New markdown tasks found in vault. Import them?',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSecondaryContainer,
                                      ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close, size: 16),
                                tooltip: 'Dismiss',
                                onPressed: () => ref
                                    .read(
                                      externalUntaggedTasksProvider.notifier,
                                    )
                                    .dismiss(),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => ref
                                    .read(
                                      externalUntaggedTasksProvider.notifier,
                                    )
                                    .dismiss(),
                                child: const Text('No'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => ref
                                    .read(
                                      externalUntaggedTasksProvider.notifier,
                                    )
                                    .acceptAndImport(),
                                child: const Text('Yes, Import'),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.task_alt_outlined,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Citrine has detected new markdown files in the vault '
                              'that contain tasks. Would you like to import them?',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                  ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(externalUntaggedTasksProvider.notifier)
                                .acceptAndImport(),
                            child: const Text('Yes'),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(externalUntaggedTasksProvider.notifier)
                                .dismiss(),
                            child: const Text('No'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            tooltip: 'Dismiss',
                            onPressed: () => ref
                                .read(externalUntaggedTasksProvider.notifier)
                                .dismiss(),
                          ),
                        ],
                      ),
              ),
            ),
          if (bgWork.isRunning)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: bgWork.progress, minHeight: 3),
                if (bgWork.currentLabel != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        bgWork.currentLabel!,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
              ],
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
          QuickCaptureBar(hideWhenExternalKeyboardOpen: !isWide),
        ],
      ),
      bottomNavigationBar: (isWide || keyboardOpen)
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
                    label: isCompactPhone ? p.shortLabel : p.label,
                    tooltip: p.label,
                  ),
              ],
            ),
      ),
    );
  }
}
