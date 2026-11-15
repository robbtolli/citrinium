import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock/app_clock.dart';
import '../../core/index/index_providers.dart';
import '../../core/workspace/workspace_state.dart';
import '../../shared/widgets/citrine_help_sheet.dart';
import '../../shared/widgets/embedded_markdown_editor.dart';
import '../../shared/widgets/in_place_task_tile.dart';
import '../../shared/widgets/planning_review_ritual_sheet.dart';

/// Default Home surface in the Hybrid Dual-Track UX (`design.md` §6.2, `B-01`,
/// `E-02`, `A-08`, `B-09`):
/// - Session Continuity / Resume chip (`A-08`)
/// - Existing-vault 14-day historical task safeguard (`A-06`)
/// - Calm Daily Migration / Fresh Start banner (`B-06`, `B-09`, `P-04`)
/// - Collapsible **Today's Focus Shelf** (Hard events + Top 3 pinned tasks +
///   Habits `D-17`)
/// - Live **Daily Log** (`daily/YYYY-MM-DD.md`, created lazily on first use).
class TodayCombinedScreen extends ConsumerStatefulWidget {
  const TodayCombinedScreen({super.key});

  @override
  ConsumerState<TodayCombinedScreen> createState() =>
      _TodayCombinedScreenState();
}

class _TodayCombinedScreenState extends ConsumerState<TodayCombinedScreen> {
  DateTime? _selectedDate;

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _setSelectedDate(DateTime target, DateTime today) {
    final normalized = DateTime(target.year, target.month, target.day);
    setState(() {
      _selectedDate = _isSameDay(normalized, today) ? null : normalized;
    });
  }

  Future<void> _pickDate(
    BuildContext context,
    DateTime activeDate,
    DateTime today,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: activeDate,
      firstDate: DateTime(today.year - 10, 1, 1),
      lastDate: DateTime(today.year + 10, 12, 31),
    );
    if (picked != null && mounted) {
      _setSelectedDate(picked, today);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clock = ref.watch(appClockProvider);
    final now = clock.now();
    final today = clock.today();
    final activeDate = _selectedDate ?? today;
    final isViewingToday = _isSameDay(activeDate, today);

    final todayIso = NlDateParser.formatIsoDate(today);
    final todayRelPath = CadenceFiles.dailyRelPath(today);
    final activeIso = NlDateParser.formatIsoDate(activeDate);
    final activeRelPath = CadenceFiles.dailyRelPath(activeDate);

    final docsAsync = ref.watch(documentListProvider);
    final entriesAsync = ref.watch(allEntriesWithDocumentsProvider);
    final workspace = ref.watch(workspaceStateProvider);

    final docs = docsAsync.value ?? const [];
    final allEntries = entriesAsync.value ?? const [];

    final activeDoc = docs.where((d) => d.relPath == activeRelPath).firstOrNull;

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

        // Getting Started progressive checklist banner (A-06, P-07)
        if (!workspace.onboardingChecklistDismissed)
          const _OnboardingChecklistBanner(),

        // Past Daily Log Migration / Fresh Start banner (B-06, B-09, P-04)
        if (pastDailyOpenTasks.isNotEmpty)
          _PastDailyMigrationBanner(
            openTasks: pastDailyOpenTasks,
            todayRelPath: todayRelPath,
          ),

        // Daily Bookends (Morning Plan + Evening Shutdown) & Progressive Guidance Bar
        _DailyBookendsAndGuidanceBar(todayIso: todayIso),

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
                  workspace.isRuleOfOneOn(todayIso)
                      ? 'Today\'s Focus Shelf (${pinnedTasks.length}/1 · 🛟 Low-Energy Day)'
                      : 'Today\'s Focus Shelf (${pinnedTasks.length}/3 Top Focus)',
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
                          'SCHEDULE & EVENTS',
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

    return Column(
      children: [
        _DateNavigationBar(
          activeDate: activeDate,
          activeIso: activeIso,
          isViewingToday: isViewingToday,
          onPreviousDay: () => _setSelectedDate(
            activeDate.subtract(const Duration(days: 1)),
            today,
          ),
          onNextDay: () => _setSelectedDate(
            activeDate.add(const Duration(days: 1)),
            today,
          ),
          onPickDate: () => _pickDate(context, activeDate, today),
          onBackToToday: () => setState(() => _selectedDate = null),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              if (isViewingToday) topSection,
              if (activeDoc != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_calendar_outlined, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Daily Log ($activeRelPath)',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        ],
                      ),
                      if (isViewingToday && dailyReviewCandidates.isNotEmpty)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
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
                EmbeddedMarkdownEditor(
                  key: ValueKey(activeRelPath),
                  relPath: activeRelPath,
                  referenceDate: activeDate,
                  shrinkWrap: true,
                ),
              ] else ...[
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 440;
                        final headerRow = Row(
                          children: [
                            const Icon(Icons.wb_twilight, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isViewingToday
                                        ? 'Today\'s Daily Log ($activeRelPath)'
                                        : 'No daily note recorded for $activeIso',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  if (!isViewingToday)
                                    Text(
                                      activeRelPath,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            if (!isNarrow) ...[
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: () async {
                                  await ref
                                      .read(vaultMutationProvider)
                                      .ensureCadenceDocument(
                                        CadenceKind.daily,
                                        activeDate,
                                        includeStarterTutorial:
                                            isViewingToday && docs.isEmpty,
                                      );
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(
                                  isViewingToday
                                      ? 'Start Today\'s Daily Log'
                                      : 'Create Note for This Day',
                                ),
                              ),
                            ],
                          ],
                        );
                        if (!isNarrow) return headerRow;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            headerRow,
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: () async {
                                await ref
                                    .read(vaultMutationProvider)
                                    .ensureCadenceDocument(
                                      CadenceKind.daily,
                                      activeDate,
                                      includeStarterTutorial:
                                          isViewingToday && docs.isEmpty,
                                    );
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(
                                isViewingToday
                                    ? 'Start Today\'s Daily Log'
                                    : 'Create Note for This Day',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
              if (docs.isNotEmpty) ...[
                const SizedBox(height: 12),
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
                      document.title.isEmpty
                          ? document.relPath
                          : document.title,
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
          ),
        ),
      ],
    );
  }
}

class _DateNavigationBar extends StatelessWidget {
  const _DateNavigationBar({
    required this.activeDate,
    required this.activeIso,
    required this.isViewingToday,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onPickDate,
    required this.onBackToToday,
  });

  final DateTime activeDate;
  final String activeIso;
  final bool isViewingToday;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onPickDate;
  final VoidCallback onBackToToday;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              key: const Key('today-date-prev'),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous Day',
              onPressed: onPreviousDay,
            ),
            Flexible(
              child: InkWell(
                key: const Key('today-date-picker'),
                borderRadius: BorderRadius.circular(8),
                onTap: onPickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isViewingToday ? 'Today · $activeIso' : activeIso,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              key: const Key('today-date-next'),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next Day',
              onPressed: onNextDay,
            ),
            const Spacer(),
            if (!isViewingToday)
              TextButton.icon(
                key: const Key('today-back-to-today'),
                onPressed: onBackToToday,
                icon: const Icon(Icons.today, size: 16),
                label: Text(
                  MediaQuery.sizeOf(context).width < 420
                      ? 'Today'
                      : 'Back to Today',
                ),
              ),
          ],
        ),
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
    final completedDates =
        workspace.habitCompletionsByDate[habit.uniqueKey] ?? const [];
    final rule = RecurrenceRule.tryParse(habit.entry.recurrenceRaw);
    final summary = HabitTrackerEngine.summarize(
      rule: rule,
      completedIsoDates: completedDates,
      referenceDate: ref.watch(appClockProvider).now(),
      windowDays: 7,
    );
    final rhythmDots = summary.recentDays
        .map(
          (d) => switch (d.state) {
            HabitDayState.completed => '●',
            HabitDayState.unloggedScheduled => '·',
            HabitDayState.restDay => '○',
          },
        )
        .join();

    return Tooltip(
      message: summary.supportiveSummaryText,
      child: FilterChip(
        selected: completedToday,
        label: Text(
          '${habit.entry.textContent} [$rhythmDots] (${summary.totalCompletions}d)',
          style: const TextStyle(fontSize: 12),
        ),
        onSelected: (_) {
          ref
              .read(workspaceStateProvider.notifier)
              .toggleHabitCompletion(habit.uniqueKey, todayIso);
        },
      ),
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
              'To keep your action lists calm on day one, Citrine can surface only open tasks from the last 14 days by default. Your older notes are never modified.',
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
    final isNarrow = MediaQuery.sizeOf(context).width < 480;
    return Card(
      color: colorScheme.tertiaryContainer,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
                if (!isNarrow) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => _openDailyMigrationModal(context),
                    child: const Text('Review & Migrate'),
                  ),
                ],
              ],
            ),
            if (isNarrow) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => _openDailyMigrationModal(context),
                child: const Text('Review & Migrate'),
              ),
            ],
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
    final now = ref.read(appClockProvider).now();

    return SafeArea(
      child: SingleChildScrollView(
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
                          );
                      _advance();
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Move to Today'),
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
                          );
                      _advance();
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Move to Tomorrow'),
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
                        );
                    _advance();
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: const Text('Schedule to Future Log'),
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
                        .setTaskStateInPlace(current, TaskStateKind.cancelled);
                    _advance();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel (-)'),
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

class _OnboardingChecklistBanner extends ConsumerStatefulWidget {
  const _OnboardingChecklistBanner();

  @override
  ConsumerState<_OnboardingChecklistBanner> createState() =>
      _OnboardingChecklistBannerState();
}

class _OnboardingChecklistBannerState
    extends ConsumerState<_OnboardingChecklistBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceStateProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const steps = [
      ('quick_capture', 'Capture a thought with Quick Capture'),
      ('focus_shelf_pin', 'Pin a task to Today\'s Top 3'),
      ('in_place_edit', 'Edit a task in-place or try a 2m Sprint'),
      ('clarify_inbox', 'Clarify an item in Actions & Inbox'),
      ('explore_guides', 'Browse notes, guides, or collections'),
    ];

    final completedCount = steps
        .where((s) => workspace.completedOnboardingSteps.contains(s.$1))
        .length;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.secondary.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  completedCount == steps.length
                      ? Icons.check_circle_outline
                      : Icons.lightbulb_outline,
                  size: 20,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Getting Started with Citrine ($completedCount/${steps.length})',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                if (MediaQuery.sizeOf(context).width >= 440)
                  TextButton(
                    onPressed: () => showCitrineHelpSheet(context),
                    child: const Text('Field Guide'),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  tooltip: _expanded ? 'Show less' : 'Show checklist',
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Dismiss checklist',
                  onPressed: () {
                    ref
                        .read(workspaceStateProvider.notifier)
                        .dismissOnboardingChecklist(dismissed: true);
                  },
                ),
              ],
            ),
            if (MediaQuery.sizeOf(context).width < 440)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  onPressed: () => showCitrineHelpSheet(context),
                  icon: const Icon(Icons.help_outline, size: 15),
                  label: const Text('Field Guide'),
                ),
              ),
            if (_expanded) ...[
              const Divider(height: 12),
              for (final step in steps) ...[
                InkWell(
                  onTap: () {
                    final isDone = workspace.completedOnboardingSteps.contains(
                      step.$1,
                    );
                    ref
                        .read(workspaceStateProvider.notifier)
                        .toggleOnboardingStep(step.$1, !isDone);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          workspace.completedOnboardingSteps.contains(step.$1)
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 18,
                          color: workspace.completedOnboardingSteps.contains(
                            step.$1,
                          )
                              ? colorScheme.primary
                              : colorScheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step.$2,
                            style: TextStyle(
                              fontSize: 13,
                              decoration: workspace.completedOnboardingSteps
                                      .contains(step.$1)
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Calm Daily Bookends bar (`🌅 Morning Plan` + `🌇 Evening Shutdown`) paired
/// with Citrine's progressive learning stage indicator (`A-06`, `P-07`) and a
/// 1-click "Disable Guidance / Customize Process" affordance.
class _DailyBookendsAndGuidanceBar extends ConsumerWidget {
  const _DailyBookendsAndGuidanceBar({required this.todayIso});

  final String todayIso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceStateProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final morningDone = workspace.isMorningPlanCompletedOn(todayIso);
    final shutdownDone = workspace.isShutdownCompletedOn(todayIso);
    final ruleOfOne = workspace.isRuleOfOneOn(todayIso);

    // Progressive stage visibility:
    // - If guidance is disabled, all bookends & horizons are visible without coaching banners.
    // - If guidance is enabled:
    //   Stage 1 focuses on Morning Plan;
    //   Stage 2+ highlights Evening Shutdown;
    //   Stage 3+ surfaces a contextual Weekly Review chip;
    //   Stage 4 surfaces Monthly/Quarterly/Yearly readiness.
    final showEveningBookend = !workspace.guidanceEnabled ||
        workspace.learningStage.indexOrder >=
            LearningStage.stage2EveningShutdown.indexOrder ||
        morningDone;
    final showWeeklyChip = !workspace.guidanceEnabled ||
        workspace.learningStage.indexOrder >=
            LearningStage.stage3WeeklyReview.indexOrder;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.compass_calibration_outlined, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        workspace.guidanceEnabled
                            ? 'Daily Bookends · ${workspace.learningStage.title}'
                            : 'Daily Bookends & Planning Rituals',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => showProcessCustomizerDialog(context),
                  icon: const Icon(Icons.tune, size: 15),
                  label: Text(
                    workspace.guidanceEnabled
                        ? 'Customize / Own Process'
                        : 'Process Studio',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            if (workspace.guidanceEnabled) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      workspace.learningStage.nextHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: () {
                        ref
                            .read(workspaceStateProvider.notifier)
                            .setGuidanceEnabled(false);
                      },
                      child: const Text(
                        'Disable Guidance',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    showPlanningReviewRitualSheet(
                      context,
                      ref,
                      ritualKind: RitualKind.dailyMorningPlan,
                    );
                  },
                  icon: Icon(
                    morningDone ? Icons.check_circle : Icons.wb_sunny_outlined,
                    size: 16,
                  ),
                  label: Text(
                    morningDone ? '🌅 Morning Plan ✓' : '🌅 Morning Plan',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (showEveningBookend)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      showPlanningReviewRitualSheet(
                        context,
                        ref,
                        ritualKind: RitualKind.dailyEveningShutdown,
                      );
                    },
                    icon: Icon(
                      shutdownDone
                          ? Icons.check_circle
                          : Icons.nights_stay_outlined,
                      size: 16,
                    ),
                    label: Text(
                      shutdownDone
                          ? '🌇 Evening Shutdown ✓'
                          : '🌇 Evening Shutdown',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.bolt, size: 15),
                  label: const Text(
                    '⚡ 2m Express Plan',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: () {
                    showPlanningReviewRitualSheet(
                      context,
                      ref,
                      ritualKind: RitualKind.dailyMorningPlan,
                      initialDepthOverride: RitualDepthMode.minimal,
                    );
                  },
                ),
                FilterChip(
                  visualDensity: VisualDensity.compact,
                  selected: ruleOfOne,
                  label: const Text(
                    '🛟 Low-Energy Day (Just 1 Thing)',
                    style: TextStyle(fontSize: 11),
                  ),
                  onSelected: (val) {
                    ref
                        .read(workspaceStateProvider.notifier)
                        .toggleRuleOfOneFloorDay(todayIso, enabled: val);
                  },
                ),
                if (showWeeklyChip &&
                    workspace.enabledCadences.contains(CadenceKind.weekly))
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.fact_check_outlined, size: 14),
                    label: const Text(
                      '📆 Weekly Review',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      showPlanningReviewRitualSheet(
                        context,
                        ref,
                        ritualKind: RitualKind.weeklyReviewPlan,
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

