import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/index/index_providers.dart';
import '../../core/workspace/workspace_state.dart';
import '../../shared/widgets/embedded_markdown_editor.dart';
import '../../shared/widgets/in_place_task_tile.dart';

/// Default Home surface in the Hybrid Dual-Track UX (`design.md` §6.2, `B-01`,
/// `E-02`, `A-08`, `B-09`):
/// - Session Continuity / Resume chip (`A-08`)
/// - Existing-vault 14-day historical task safeguard (`A-06`)
/// - Calm Daily Migration / Fresh Start banner (`B-06`, `B-09`, `P-04`)
/// - Collapsible **Today's Focus Shelf** (Hard events + Top 3 pinned tasks +
///   Habits `D-17`)
/// - Live **Daily Log** (`daily/YYYY-MM-DD.md`, created lazily on first use).
class TodayCombinedScreen extends ConsumerWidget {
  const TodayCombinedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final todayIso = NlDateParser.formatIsoDate(now);
    final todayRelPath = CadenceFiles.dailyRelPath(now);

    final docsAsync = ref.watch(documentListProvider);
    final entriesAsync = ref.watch(allEntriesWithDocumentsProvider);
    final workspace = ref.watch(workspaceStateProvider);

    final docs = docsAsync.value ?? const [];
    final allEntries = entriesAsync.value ?? const [];

    final todayDoc = docs.where((d) => d.relPath == todayRelPath).firstOrNull;

    // 1. Identify open tasks from past Daily Logs (`daily/*.md` where relPath < todayRelPath)
    // and open tasks in Today's Daily Log for Guided Daily Review / Migration (`B-06`, `B-07`, `R-02`)
    final pastDailyOpenTasks = allEntries.where((e) {
      return e.isOpenTask &&
          e.document.relPath.startsWith('daily/') &&
          e.document.relPath.compareTo(todayRelPath) < 0;
    }).toList();
    final todayOpenTasks = allEntries.where((e) {
      return e.isOpenTask && e.document.relPath == todayRelPath;
    }).toList();
    final dailyReviewCandidates = [
      ...pastDailyOpenTasks,
      ...todayOpenTasks,
    ];

    // 2. Check existing-vault 14-day historical task safeguard (A-06)
    final cutoffMs =
        now.subtract(Duration(days: workspace.historicalTaskCutoffDays)).millisecondsSinceEpoch;
    final oldUndatedOpenTasks = allEntries.where((e) {
      return e.isOpenTask &&
          e.entry.dueDate == null &&
          e.document.mtimeMs < cutoffMs;
    }).toList();

    // 3. Today's Focus Shelf items: pinned Top 3 + tasks/events due today
    final pinnedTasks = allEntries
        .where((e) => workspace.isPinnedToday(e.uniqueKey))
        .toList();
    final dueTodayTasks = allEntries.where((e) {
      return e.isTask &&
          e.entry.dueDate == todayIso &&
          !workspace.isPinnedToday(e.uniqueKey);
    }).toList();
    final todayEvents = allEntries.where((e) {
      return e.isEvent &&
          (e.document.relPath == todayRelPath || e.entry.dueDate == todayIso);
    }).toList();
    final habits = allEntries.where((e) => e.isHabit).toList();

    final recentDoc = workspace.mostRecentItem;

    final topSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Resume chip for session continuity (A-08 / N-04)
        if (recentDoc != null && recentDoc.relPath != todayRelPath)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ActionChip(
              avatar: const Icon(Icons.restore, size: 16),
              label: Text(
                '↩ Resume: ${recentDoc.displayLabel}',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () {
                final targetDoc = docs
                    .where((d) => d.relPath == recentDoc.relPath)
                    .firstOrNull;
                if (targetDoc != null) {
                  context.push(
                    '/documents/${targetDoc.id}',
                    extra: targetDoc,
                  );
                }
              },
            ),
          ),

        // Existing-vault 14-day historical task safeguard (A-06)
        if (!workspace.dismissedHistoricalPrompt &&
            oldUndatedOpenTasks.length > 10)
          _HistoricalTaskSafeguardBanner(
            oldTaskCount: oldUndatedOpenTasks.length,
          ),

        // Past Daily Log Migration / Fresh Start banner (B-06, B-09, P-04)
        if (pastDailyOpenTasks.isNotEmpty)
          _PastDailyMigrationBanner(
            openTasks: pastDailyOpenTasks,
            todayRelPath: todayRelPath,
          ),

        // Collapsible Today's Focus Shelf (E-02, G-05, D-17)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.wb_sunny_outlined),
                title: Text(
                  'Today\'s Focus Shelf (${pinnedTasks.length}/3 Top Focus)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${todayEvents.length} events · ${pinnedTasks.length + dueTodayTasks.length} focus tasks · ${habits.length} habits',
                ),
                trailing: IconButton(
                  icon: Icon(
                    workspace.focusShelfExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  tooltip: workspace.focusShelfExpanded
                      ? 'Collapse Focus Shelf'
                      : 'Expand Focus Shelf',
                  onPressed: () {
                    ref
                        .read(workspaceStateProvider.notifier)
                        .setFocusShelfExpanded(
                          !workspace.focusShelfExpanded,
                        );
                  },
                ),
              ),
              if (workspace.focusShelfExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (todayEvents.isNotEmpty) ...[
                        const Text(
                          'HARD LANDSCAPE (EVENTS)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        for (final ev in todayEvents)
                          InPlaceTaskTile(item: ev, dense: true),
                        const SizedBox(height: 6),
                      ],
                      const Text(
                        'TOP 3 & DUE TODAY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (pinnedTasks.isEmpty && dueTodayTasks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            'Pin up to 3 tasks for today.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      else ...[
                        for (final item in pinnedTasks)
                          InPlaceTaskTile(item: item, dense: true),
                        for (final item in dueTodayTasks)
                          InPlaceTaskTile(item: item, dense: true),
                      ],
                      if (habits.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'DAILY HABITS (NON-PUNITIVE CHECK-IN)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final h in habits)
                              _HabitCheckChip(
                                habit: h,
                                todayIso: todayIso,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (todayDoc != null) {
      return Column(
        children: [
          Flexible(
            flex: 0,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: topSection,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_calendar_outlined, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Daily Log ($todayRelPath)',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      if (dailyReviewCandidates.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (ctx) => _DailyMigrationDeckSheet(
                                tasks: dailyReviewCandidates,
                                todayRelPath: todayRelPath,
                              ),
                            );
                          },
                          icon: const Icon(Icons.fact_check_outlined, size: 16),
                          label: Text(
                            'Daily Review & Migrate (${dailyReviewCandidates.length})',
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: EmbeddedMarkdownEditor(relPath: todayRelPath),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          topSection,
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.wb_twilight, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Today\'s Daily Log ($todayRelPath)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      await ref
                          .read(vaultMutationProvider)
                          .ensureCadenceDocument(
                            CadenceKind.daily,
                            now,
                            includeStarterTutorial: docs.isEmpty,
                          );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Start Today\'s Daily Log'),
                  ),
                ],
              ),
            ),
          ),
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'VAULT NOTES & LOGS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final document in docs)
              ListTile(
                dense: true,
                title: Text(
                  document.title.isEmpty ? document.relPath : document.title,
                ),
                subtitle: Text(
                  '${document.relPath} · ${document.docType}',
                ),
                onTap: () => context.push(
                  '/documents/${document.id}',
                  extra: document,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _HabitCheckChip extends ConsumerWidget {
  const _HabitCheckChip({
    required this.habit,
    required this.todayIso,
  });

  final IndexedEntryWithDocument habit;
  final String todayIso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceStateProvider);
    final completedToday =
        workspace.isHabitCompletedOn(habit.uniqueKey, todayIso);
    final totalCompletions =
        workspace.habitCompletionsByDate[habit.uniqueKey]?.length ?? 0;

    return FilterChip(
      selected: completedToday,
      label: Text(
        '${habit.entry.textContent} ($totalCompletions days logged)',
        style: const TextStyle(fontSize: 12),
      ),
      onSelected: (_) {
        ref
            .read(workspaceStateProvider.notifier)
            .toggleHabitCompletion(habit.uniqueKey, todayIso);
      },
    );
  }
}

class _HistoricalTaskSafeguardBanner extends ConsumerWidget {
  const _HistoricalTaskSafeguardBanner({required this.oldTaskCount});

  final int oldTaskCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Existing Vault Safeguard: $oldTaskCount older open tasks found',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'To keep your action lists calm on day one, Citrinium can surface only open tasks from the last 14 days by default. Your older notes are never modified.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () {
                    ref
                        .read(workspaceStateProvider.notifier)
                        .setHistoricalTaskFilter(filterOlderUndatedTasks: true);
                  },
                  child: const Text('Surface last 14 days only (Recommended)'),
                ),
                OutlinedButton(
                  onPressed: () {
                    ref
                        .read(workspaceStateProvider.notifier)
                        .setHistoricalTaskFilter(filterOlderUndatedTasks: false);
                  },
                  child: const Text('Include all tasks'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PastDailyMigrationBanner extends ConsumerWidget {
  const _PastDailyMigrationBanner({
    required this.openTasks,
    required this.todayRelPath,
  });

  final List<IndexedEntryWithDocument> openTasks;
  final String todayRelPath;

  void _openDailyMigrationModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _DailyMigrationDeckSheet(
        tasks: openTasks,
        todayRelPath: todayRelPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.tertiaryContainer,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.autorenew, color: colorScheme.onTertiaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${openTasks.length} open task${openTasks.length == 1 ? '' : 's'} from earlier Daily Logs. Ready for a quick 1-minute migration?',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
            ),
            FilledButton.tonal(
              onPressed: () => _openDailyMigrationModal(context),
              child: const Text('Review & Migrate'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card-by-card Daily Migration Triage Deck (`B-06`, `R-02`, `P-04`, `P-05`):
/// presents open tasks from prior days one at a time so the user makes an
/// intentional `Migrate >`, `Schedule <`, `Someday`, or `Drop -` decision.
class _DailyMigrationDeckSheet extends ConsumerStatefulWidget {
  const _DailyMigrationDeckSheet({
    required this.tasks,
    required this.todayRelPath,
  });

  final List<IndexedEntryWithDocument> tasks;
  final String todayRelPath;

  @override
  ConsumerState<_DailyMigrationDeckSheet> createState() =>
      _DailyMigrationDeckSheetState();
}

class _DailyMigrationDeckSheetState
    extends ConsumerState<_DailyMigrationDeckSheet> {
  int _index = 0;

  void _advance() {
    if (_index + 1 >= widget.tasks.length) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily migration complete! Your open loops are up to date.'),
        ),
      );
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty || _index >= widget.tasks.length) {
      return const SizedBox.shrink();
    }
    final current = widget.tasks[_index];
    final theme = Theme.of(context);
    final now = DateTime.now();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Daily Migration (${_index + 1} of ${widget.tasks.length})',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Pause for later'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_index + 1) / widget.tasks.length,
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From ${current.document.relPath}',
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      current.entry.textContent,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Still worth your energy today?',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (current.document.relPath != widget.todayRelPath)
                  FilledButton.icon(
                    onPressed: () async {
                      await ref
                          .read(vaultMutationProvider)
                          .migrateOrScheduleEntry(
                            current,
                            targetRelPath: widget.todayRelPath,
                            targetInitialContent:
                                CadenceFiles.defaultContentForCadence(
                                  CadenceKind.daily,
                                  now,
                                ),
                            sourceMarker: TaskStateKind.migrated,
                          );
                      _advance();
                    },
                    icon: const Icon(Icons.keyboard_arrow_right),
                    label: const Text('Migrate to Today (>)'),
                  )
                else ...[
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await ref
                          .read(vaultMutationProvider)
                          .setTaskStateInPlace(
                            current,
                            TaskStateKind.completed,
                          );
                      _advance();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Mark Done ([x])'),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final tomorrow = now.add(const Duration(days: 1));
                      await ref
                          .read(vaultMutationProvider)
                          .migrateOrScheduleEntry(
                            current,
                            targetRelPath: CadenceFiles.dailyRelPath(tomorrow),
                            targetInitialContent:
                                CadenceFiles.defaultContentForCadence(
                                  CadenceKind.daily,
                                  tomorrow,
                                ),
                            sourceMarker: TaskStateKind.migrated,
                          );
                      _advance();
                    },
                    icon: const Icon(Icons.keyboard_arrow_right),
                    label: const Text('Migrate to Tomorrow (>)'),
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(vaultMutationProvider)
                        .migrateOrScheduleEntry(
                          current,
                          targetRelPath: CadenceFiles.futureLogRelPath,
                          targetInitialContent:
                              CadenceFiles.defaultContentForCadence(
                                CadenceKind.future,
                                now,
                              ),
                          sourceMarker: TaskStateKind.scheduled,
                        );
                    _advance();
                  },
                  icon: const Icon(Icons.keyboard_arrow_left),
                  label: const Text('Schedule to Future Log (<)'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(vaultMutationProvider)
                        .migrateOrScheduleEntry(
                          current,
                          targetRelPath: CadenceFiles.somedayRelPath,
                          targetInitialContent:
                              CadenceFiles.defaultSomedayContent(),
                          sourceMarker: TaskStateKind.scheduled,
                        );
                    _advance();
                  },
                  icon: const Icon(Icons.spa_outlined),
                  label: const Text('Someday / Maybe'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await ref
                        .read(vaultMutationProvider)
                        .setTaskStateInPlace(current, TaskStateKind.dropped);
                    _advance();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Drop (-)'),
                ),
                TextButton(
                  onPressed: _advance,
                  child: const Text('Skip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
