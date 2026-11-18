import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock/app_clock.dart';
import '../../core/index/index_providers.dart';
import '../../core/workspace/workspace_state.dart';
import '../../shared/widgets/citrine_data_view_card.dart';
import '../../shared/widgets/in_place_task_tile.dart';
import '../../shared/widgets/metadata_badge.dart';
import '../../shared/widgets/planning_review_ritual_sheet.dart';

/// Unified Pure Data View for `Plan & Review` (`design.md` §6.2, `B-02`, `B-12`):
/// Single-canvas database-backed planning & review views with no backing `.md`
/// files required, across user-configurable cadences:
/// - Daily, Weekly, Monthly, Quarterly, Yearly, and Future (`B-03`, `B-12`)
///
/// Includes dynamic horizon threading (`QY-04`) across enabled cadences,
/// editable/replaceable cadence templates (`B-11`), and a guided review/migration
/// ritual (`B-06`, `B-07`, `R-01`, `R-02`) for each cadence.
class HorizonsReviewScreen extends ConsumerStatefulWidget {
  const HorizonsReviewScreen({super.key});

  @override
  ConsumerState<HorizonsReviewScreen> createState() =>
      _HorizonsReviewScreenState();
}

class _HorizonsReviewScreenState extends ConsumerState<HorizonsReviewScreen> {
  CadenceKind _selectedCadence = CadenceKind.weekly;
  bool _periodShelfExpanded = true;

  List<IndexedEntryWithDocument> _entriesForCadencePeriod({
    required CadenceKind cadence,
    required String currentRelPath,
    required DateTime now,
    required List<IndexedEntryWithDocument> allEntries,
  }) {
    final monthPrefix = CadenceFiles.monthlyRelPath(
      now,
    ).replaceAll('monthly/', '').replaceAll('.md', ''); // YYYY-MM
    return allEntries.where((e) {
      if (e.document.relPath == currentRelPath) {
        return e.isTask || e.isEvent;
      }
      if (cadence == CadenceKind.monthly &&
          e.entry.dueDate != null &&
          e.entry.dueDate!.startsWith(monthPrefix)) {
        return e.isTask || e.isEvent;
      }
      return false;
    }).toList();
  }

  void _openQuickAddToCadenceDialog(
    BuildContext context, {
    required CadenceKind cadence,
    required String targetRelPath,
    required DateTime now,
  }) {
    final textCtrl = TextEditingController();
    var entryPrefix = '- [ ]';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Add to ${cadence.label} ($targetRelPath)'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: '- [ ]', label: Text('• Task')),
                    ButtonSegment(value: '- ○', label: Text('○ Event')),
                    ButtonSegment(value: '- –', label: Text('– Note')),
                  ],
                  selected: {entryPrefix},
                  onSelectionChanged: (s) =>
                      setDialogState(() => entryPrefix = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  decoration: InputDecoration(
                    labelText: 'Entry for $targetRelPath',
                    hintText: cadence == CadenceKind.future
                        ? 'e.g. Renew passport 📅 2026-12-15'
                        : 'e.g. Ship milestone outcomes @computer',
                    border: const OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final raw = textCtrl.text.trim();
                if (raw.isEmpty) return;
                await ref
                    .read(vaultMutationProvider)
                    .ensureCadenceDocument(cadence, now);
                await ref
                    .read(vaultMutationProvider)
                    .appendLineToDocument(
                      relPath: targetRelPath,
                      lineText: '$entryPrefix $raw',
                    );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceStateProvider);
    final docsAsync = ref.watch(documentListProvider);
    final entriesAsync = ref.watch(allEntriesWithDocumentsProvider);

    final enabledList = CadenceKind.values
        .where((c) => workspace.enabledCadences.contains(c))
        .toList();

    final activeCadence = enabledList.contains(_selectedCadence)
        ? _selectedCadence
        : (enabledList.isNotEmpty ? enabledList.first : CadenceKind.daily);

    final now = ref.watch(appClockProvider).now();
    final currentRelPath = CadenceFiles.relPathForCadence(activeCadence, now);
    final docs = docsAsync.value ?? const [];
    final allEntries = entriesAsync.value ?? const [];
    final periodEntries = _entriesForCadencePeriod(
      cadence: activeCadence,
      currentRelPath: currentRelPath,
      now: now,
      allEntries: allEntries,
    );
    final dataViewQueries = _dataViewQueriesForCadence(activeCadence);
    final bridgedHorizons = CadenceFiles.horizonLinksForCadence(
      activeCadence,
      now,
      workspace.enabledCadences,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top cadence selector + Templates (B-11) & Configure Cadences (B-12)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final c in enabledList)
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(c.label, style: const TextStyle(fontSize: 12)),
                  selected: activeCadence == c,
                  onSelected: (_) {
                    setState(() => _selectedCadence = c);
                  },
                ),
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.auto_fix_high_outlined, size: 14),
                label: const Text(
                  'Process Studio',
                  style: TextStyle(fontSize: 12),
                ),
                onPressed: () {
                  final initialRitual =
                      RitualKind.primaryForCadence(activeCadence) ??
                      RitualKind.weeklyReviewPlan;
                  showProcessCustomizerDialog(
                    context,
                    initialRitual: initialRitual,
                  );
                },
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => showCadenceTemplatesDialog(
                  context,
                  initialCadence: activeCadence,
                ),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Templates'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _openConfigureCadencesDialog(context),
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Cadences'),
              ),
            ],
          ),

          // Dynamic Horizon Threading Breadcrumbs (QY-04, B-12) + Start Review button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.account_tree_outlined, size: 15),
                Text(
                  bridgedHorizons.isEmpty
                      ? 'Horizon Threading:'
                      : 'Horizon Threading (${bridgedHorizons.join(' ↔ ')}):',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                for (final c in enabledList.where(
                  (c) => c != CadenceKind.future,
                ))
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: c == activeCadence
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    label: Text(
                      CadenceFiles.relPathForCadence(
                        c,
                        now,
                      ).replaceAll('.md', '').split('/').last,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () => setState(() => _selectedCadence = c),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _openQuickAddToCadenceDialog(
                    context,
                    cadence: activeCadence,
                    targetRelPath: currentRelPath,
                    now: now,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('Add to ${activeCadence.label}'),
                ),
                if (activeCadence == CadenceKind.daily) ...[
                  FilledButton.tonalIcon(
                    onPressed: () => showPlanningReviewRitualSheet(
                      context,
                      ref,
                      ritualKind: RitualKind.dailyMorningPlan,
                    ),
                    icon: const Icon(Icons.wb_sunny_outlined, size: 16),
                    label: const Text('🌅 Morning Plan'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showPlanningReviewRitualSheet(
                      context,
                      ref,
                      ritualKind: RitualKind.dailyEveningShutdown,
                    ),
                    icon: const Icon(Icons.nights_stay_outlined, size: 16),
                    label: const Text('🌇 Evening Shutdown'),
                  ),
                ] else if (activeCadence != CadenceKind.future) ...[
                  FilledButton.icon(
                    onPressed: () {
                      final rk = RitualKind.primaryForCadence(activeCadence);
                      if (rk != null) {
                        showPlanningReviewRitualSheet(
                          context,
                          ref,
                          ritualKind: rk,
                        );
                      }
                    },
                    icon: const Icon(Icons.explore_outlined, size: 16),
                    label: Text('Guided ${activeCadence.label} Process'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final rk = RitualKind.primaryForCadence(activeCadence);
                      if (rk != null) {
                        showPlanningReviewRitualSheet(
                          context,
                          ref,
                          ritualKind: rk,
                          initialDepthOverride: RitualDepthMode.minimal,
                        );
                      }
                    },
                    icon: const Icon(Icons.bolt_outlined, size: 16),
                    label: Text('⚡ Express ${activeCadence.label}'),
                  ),
                ],
                if (activeCadence != CadenceKind.future)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (ctx) => _GuidedCadenceReviewModal(
                          cadence: activeCadence,
                          targetRelPath: currentRelPath,
                          allEntries: allEntries,
                          allDocs: docs,
                        ),
                      );
                    },
                    icon: const Icon(Icons.fact_check_outlined, size: 16),
                    label: Text('Start ${activeCadence.label} Review'),
                  ),
              ],
            ),
          ),

          // Pure Data View header (B-02)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.view_agenda_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${activeCadence.label} Plan & Review · Pure Data View',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  activeCadence.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // Period Open Loops & Key Dates Shelf (B-02, B-03, D-19)
          if (periodEntries.isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.playlist_add_check, size: 18),
                    title: Text(
                      '${activeCadence.label} Open Loops & Key Dates (${periodEntries.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        _periodShelfExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 18,
                      ),
                      onPressed: () => setState(
                        () => _periodShelfExpanded = !_periodShelfExpanded,
                      ),
                    ),
                  ),
                  if (_periodShelfExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Column(
                        children: [
                          for (final entry in periodEntries)
                            InPlaceTaskTile(item: entry, dense: true),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // Pure database-driven Data View cards (B-02)
          _buildReorderableDataViews(
            cadence: activeCadence,
            queries: dataViewQueries,
            savedOrder: workspace.cadenceDataViewOrder[activeCadence.name],
            referenceDate: now,
          ),
        ],
      ),
    );
  }

  static String _dataViewQueryId(CitrineDataViewQuery query) =>
      '${query.view.name}|${query.filter ?? ''}|${query.status}|${query.resolvedTitle}';

  Widget _buildReorderableDataViews({
    required CadenceKind cadence,
    required List<CitrineDataViewQuery> queries,
    required List<String>? savedOrder,
    required DateTime referenceDate,
  }) {
    final ordered = _applySavedOrder(queries, savedOrder);
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: ordered.length,
      onReorderItem: (oldIndex, newIndex) {
        if (oldIndex == newIndex) return;
        final next = List<CitrineDataViewQuery>.from(ordered);
        final moved = next.removeAt(oldIndex);
        next.insert(newIndex, moved);
        ref.read(workspaceStateProvider.notifier).reorderCadenceDataView(
          cadence.name,
          [for (final q in next) _dataViewQueryId(q)],
        );
      },
      itemBuilder: (context, index) {
        final query = ordered[index];
        final id = _dataViewQueryId(query);
        return CitrineDataViewCard(
          key: ValueKey('horizon_dv_${cadence.name}_$id'),
          query: query,
          referenceDate: referenceDate,
          dragHandle: ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Tooltip(
                message: 'Drag to reorder',
                child: Icon(Icons.drag_indicator, size: 20),
              ),
            ),
          ),
        );
      },
    );
  }

  List<CitrineDataViewQuery> _applySavedOrder(
    List<CitrineDataViewQuery> queries,
    List<String>? savedOrder,
  ) {
    if (savedOrder == null || savedOrder.isEmpty) return queries;
    final byId = <String, CitrineDataViewQuery>{
      for (final q in queries) _dataViewQueryId(q): q,
    };
    final result = <CitrineDataViewQuery>[];
    final used = <String>{};
    for (final id in savedOrder) {
      final q = byId[id];
      if (q != null && used.add(id)) {
        result.add(q);
      }
    }
    for (final q in queries) {
      final id = _dataViewQueryId(q);
      if (used.add(id)) {
        result.add(q);
      }
    }
    return result;
  }

  List<CitrineDataViewQuery> _dataViewQueriesForCadence(CadenceKind cadence) {
    return switch (cadence) {
      CadenceKind.daily => const [
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.topFocus,
          title: 'Top Focus',
        ),
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.dueToday,
          includeOverdue: true,
          title: 'Due Today & Overdue',
        ),
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.events,
          filter: 'today',
          title: 'Today\'s Schedule',
        ),
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.tasks,
          filter: 'completed-today',
          status: 'completed',
          title: 'Completed Today',
        ),
      ],
      CadenceKind.weekly => const [
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.events,
          filter: 'this-week',
          title: 'This Week\'s Schedule',
        ),
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.dueThisWeek,
          includeOverdue: true,
          title: 'Tasks Due This Week & Overdue',
        ),
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.projects,
          filter: 'active',
          title: 'Active Projects',
        ),
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.tasks,
          filter: 'completed-this-week',
          status: 'completed',
          title: 'Completed This Week',
        ),
      ],
      CadenceKind.monthly => const [
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.events,
          filter: 'this-month',
          title: 'This Month\'s Key Dates',
        ),
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.tasks,
          filter: 'due-this-month',
          includeOverdue: true,
          title: 'Tasks Due This Month & Overdue',
        ),
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.projects,
          filter: 'active',
          title: 'Active Projects',
        ),
      ],
      CadenceKind.quarterly => const [
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.projects,
          filter: 'active',
          title: 'Active Projects & Milestones',
        ),
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.tasks,
          filter: 'open',
          title: 'Open Tasks',
        ),
      ],
      CadenceKind.yearly => const [
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.projects,
          filter: 'active',
          title: 'Active Projects & Annual Goals',
        ),
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.events,
          filter: 'upcoming',
          title: 'Upcoming Key Dates',
        ),
      ],
      CadenceKind.future => const [
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.events,
          filter: 'upcoming',
          title: 'Upcoming Scheduled Dates',
        ),
        CitrineDataViewQuery(
          view: CitrineDataViewPreset.tasks,
          filter: 'open',
          title: 'Future & Undated Tasks',
        ),
      ],
    };
  }

  void _openConfigureCadencesDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => const _ConfigureCadencesDialog(),
    );
  }
}

/// Opens the Editable / Replaceable Cadence Templates dialog (`B-11`).
Future<void> showCadenceTemplatesDialog(
  BuildContext context, {
  CadenceKind initialCadence = CadenceKind.daily,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _CadenceTemplatesDialog(initialCadence: initialCadence),
  );
}

class _CadenceTemplatesDialog extends ConsumerStatefulWidget {
  const _CadenceTemplatesDialog({required this.initialCadence});

  final CadenceKind initialCadence;

  @override
  ConsumerState<_CadenceTemplatesDialog> createState() =>
      _CadenceTemplatesDialogState();
}

class _CadenceTemplatesDialogState
    extends ConsumerState<_CadenceTemplatesDialog> {
  late CadenceKind _cadence = widget.initialCadence;
  final TextEditingController _templateCtrl = TextEditingController();
  bool _isCustom = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplate(_cadence);
  }

  @override
  void dispose() {
    _templateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate(CadenceKind cadence) async {
    setState(() {
      _cadence = cadence;
      _loading = true;
    });
    final res = await ref
        .read(vaultMutationProvider)
        .readCadenceTemplate(cadence);
    if (!mounted) return;
    setState(() {
      _templateCtrl.text = res.text;
      _isCustom = res.isCustom;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Planning Templates'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customize or replace the default Markdown template for any cadence (.citrine/templates/<id>.md). Editing a template never disables the underlying cadence or review ritual.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in CadenceKind.values)
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        c.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _cadence == c,
                      onSelected: (_) => _loadTemplate(c),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isCustom
                          ? 'Using custom template (${CadenceFiles.templateRelPath(_cadence)})'
                          : 'Using built-in functional default template',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  if (_isCustom)
                    TextButton.icon(
                      onPressed: () async {
                        await ref
                            .read(vaultMutationProvider)
                            .resetCadenceTemplate(_cadence);
                        await _loadTemplate(_cadence);
                      },
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Reset to Default'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                TextField(
                  controller: _templateCtrl,
                  minLines: 7,
                  maxLines: 11,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: '${_cadence.label} Template Markdown',
                    helperText:
                        'Placeholders: {{date}}, {{week}}, {{month}}, {{quarter}}, {{year}}, {{horizons}}',
                    border: const OutlineInputBorder(),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: _loading
              ? null
              : () async {
                  await ref
                      .read(vaultMutationProvider)
                      .saveCadenceTemplate(_cadence, _templateCtrl.text);
                  if (!context.mounted) return;
                  setState(() => _isCustom = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Saved custom ${_cadence.label} template (${CadenceFiles.templateRelPath(_cadence)}).',
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('Save Template'),
        ),
      ],
    );
  }
}

/// Dialog allowing users to configure which planning and review cadences they
/// want enabled (`B-12`).
class _ConfigureCadencesDialog extends ConsumerWidget {
  const _ConfigureCadencesDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceStateProvider);

    return AlertDialog(
      title: const Text('Configure Planning & Review Cadences'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enable only the horizons that fit how you work. Disabling a cadence hides its tabs without deleting any Markdown files on disk, and horizon links automatically bridge across enabled cadences.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final c in CadenceKind.values)
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.label),
                  subtitle: Text(c.description),
                  value: workspace.enabledCadences.contains(c),
                  onChanged: (enabled) {
                    ref
                        .read(workspaceStateProvider.notifier)
                        .toggleCadence(c, enabled);
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Guided Multi-Step Review & End-of-Period Migration Ritual (`B-06`, `B-07`,
/// `R-01`, `R-02`, `R-03`, `Q-02`, `Y-02`):
/// 1. Celebrate What Shipped (completed tasks — ADHD positive reinforcement)
/// 2. End-of-Period Migration & Open Loop Triage (`B-06`, `B-07`, `D-19`)
/// 3. Project Health & Waiting For Check (`D-04`, `D-06`)
/// 4. Set Focus Priorities for the current period (`targetRelPath`)
class _GuidedCadenceReviewModal extends ConsumerStatefulWidget {
  const _GuidedCadenceReviewModal({
    required this.cadence,
    required this.targetRelPath,
    required this.allEntries,
    required this.allDocs,
  });

  final CadenceKind cadence;
  final String targetRelPath;
  final List<IndexedEntryWithDocument> allEntries;
  final List<Document> allDocs;

  @override
  ConsumerState<_GuidedCadenceReviewModal> createState() =>
      _GuidedCadenceReviewModalState();
}

class _GuidedCadenceReviewModalState
    extends ConsumerState<_GuidedCadenceReviewModal> {
  int _step = 0;
  final TextEditingController _focusCtrl = TextEditingController();
  final Map<int, TextEditingController> _zombieActionControllers = {};

  @override
  void initState() {
    super.initState();
    if (widget.cadence == CadenceKind.weekly) {
      final ws = ref.read(workspaceStateProvider);
      if (ws.weeklyReviewStep > 0 && ws.weeklyReviewStep < 4) {
        _step = ws.weeklyReviewStep;
      }
    }
  }

  @override
  void dispose() {
    _focusCtrl.dispose();
    for (final c in _zombieActionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _goToStep(int newStep) {
    setState(() => _step = newStep);
    if (widget.cadence == CadenceKind.weekly) {
      ref.read(workspaceStateProvider.notifier).setWeeklyReviewStep(newStep);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entriesAsync = ref.watch(allEntriesWithDocumentsProvider);
    final docsAsync = ref.watch(documentListProvider);
    final workspace = ref.watch(workspaceStateProvider);
    final liveEntries = entriesAsync.value ?? widget.allEntries;
    final liveDocs = docsAsync.value ?? widget.allDocs;

    final completedTasks = liveEntries.where((e) => e.isCompletedTask).toList();
    final inboxTasks = liveEntries
        .where((e) => e.document.relPath == 'inbox.md' && e.isOpenTask)
        .toList();
    final futureItems = liveEntries.where((e) {
      return e.document.relPath == CadenceFiles.futureLogRelPath &&
          e.isOpenTask;
    }).toList();
    final projects = liveDocs.where((d) {
      return d.docType == 'project' || d.relPath.startsWith('projects/');
    }).toList();
    final zombieProjects = projects.where((p) {
      return !liveEntries.any((e) => e.document.id == p.id && e.isOpenTask);
    }).toList();

    final isResumed =
        widget.cadence == CadenceKind.weekly &&
        workspace.weeklyReviewStep > 0 &&
        _step == workspace.weeklyReviewStep;

    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight =
        (MediaQuery.sizeOf(context).height - viewInsetsBottom).clamp(
          260.0,
          900.0,
        );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, viewInsetsBottom + 16),
        child: SizedBox(
          height: availableHeight * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Guided ${widget.cadence.label} Review (Step ${_step + 1} of 4)',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (widget.cadence == CadenceKind.weekly) {
                        ref
                            .read(workspaceStateProvider.notifier)
                            .setWeeklyReviewStep(_step);
                      }
                      Navigator.of(context).pop();
                    },
                    child: const Text('Save & Close'),
                  ),
                ],
              ),
              if (isResumed)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Resumed review at Step ${_step + 1}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _goToStep(0);
                          ref
                              .read(workspaceStateProvider.notifier)
                              .resetWeeklyReview();
                        },
                        child: const Text(
                          'Start Fresh',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: (_step + 1) / 4),
              const SizedBox(height: 14),

              Expanded(
                child: switch (_step) {
                  0 => _buildStepGetClear(theme, inboxTasks, completedTasks),
                  1 => _buildStepGetCurrent(theme, zombieProjects, liveEntries),
                  2 => _buildStepGetCreativeAndStale(
                    theme,
                    liveEntries,
                    futureItems,
                  ),
                  _ => _buildStepSetPriorities(theme),
                },
              ),

              const Divider(),
              Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: () => _goToStep(_step - 1),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (_step < 3)
                    FilledButton(
                      onPressed: () => _goToStep(_step + 1),
                      child: const Text('Next Step →'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () async {
                        final text = _focusCtrl.text.trim();
                        final now = DateTime.now();
                        await ref
                            .read(vaultMutationProvider)
                            .ensureCadenceDocument(widget.cadence, now);
                        if (text.isNotEmpty) {
                          await ref
                              .read(vaultMutationProvider)
                              .appendLineToDocument(
                                relPath: widget.targetRelPath,
                                lineText: '- [ ] $text',
                              );
                        }
                        if (widget.cadence == CadenceKind.weekly) {
                          await ref
                              .read(workspaceStateProvider.notifier)
                              .completeWeeklyReview(now);
                        }
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${widget.cadence.label} Review complete! 🎉 Updated ${widget.targetRelPath}.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: Text('Finish ${widget.cadence.label} Review'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepGetClear(
    ThemeData theme,
    List<IndexedEntryWithDocument> inboxTasks,
    List<IndexedEntryWithDocument> completedTasks,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '1. Get Clear (Inbox Zero) 📥',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            MetadataBadge(
              label: inboxTasks.isEmpty
                  ? 'Inbox Zero 🎉'
                  : '${inboxTasks.length} to clarify',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Process unclarified inbox items to zero. Make a quick decision on each item:',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: inboxTasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inbox Zero Achieved! 🎉',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No unclarified items in inbox.md. You also completed ${completedTasks.length} tasks in the vault!',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: inboxTasks.length,
                  itemBuilder: (context, index) {
                    final item = inboxTasks[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InPlaceTaskTile(item: item, dense: true),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.arrow_forward,
                                    size: 14,
                                  ),
                                  label: const Text(
                                    'Next Action',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(vaultMutationProvider)
                                        .migrateOrScheduleEntry(
                                          item,
                                          targetRelPath: widget.targetRelPath,
                                          targetInitialContent:
                                              CadenceFiles.defaultContentForCadence(
                                                widget.cadence,
                                                DateTime.now(),
                                              ),
                                        );
                                  },
                                ),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.hourglass_bottom,
                                    size: 14,
                                  ),
                                  label: const Text(
                                    'Waiting For',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(vaultMutationProvider)
                                        .delegateToWaitingFor(
                                          item,
                                          delegateTo: 'Someone',
                                        );
                                  },
                                ),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.folder_outlined,
                                    size: 14,
                                  ),
                                  label: const Text(
                                    'Project',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(vaultMutationProvider)
                                        .createNoteOrProject(
                                          title: item.entry.textContent,
                                          docType: 'project',
                                          promoteFromEntry: item,
                                        );
                                  },
                                ),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.lightbulb_outline,
                                    size: 14,
                                  ),
                                  label: const Text(
                                    'Someday',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(vaultMutationProvider)
                                        .fileToReference(
                                          item,
                                          targetRelPath: 'someday.md',
                                        );
                                  },
                                ),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.close, size: 14),
                                  label: const Text(
                                    'Cancel (-)',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(vaultMutationProvider)
                                        .setTaskStateInPlace(
                                          item,
                                          TaskStateKind.cancelled,
                                        );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStepGetCurrent(
    ThemeData theme,
    List<Document> zombieProjects,
    List<IndexedEntryWithDocument> liveEntries,
  ) {
    final now = DateTime.now();
    final twoWeeksOut = now.add(const Duration(days: 14));
    final waiting = liveEntries.where((e) => e.isWaitingTask).toList();

    // 14-day upcoming commitments (G-05)
    final upcomingCommitments = liveEntries.where((e) {
      if (e.entry.dueDate == null) return false;
      final d = DateTime.tryParse(e.entry.dueDate!);
      if (d == null) return false;
      return d.isAfter(now.subtract(const Duration(days: 1))) &&
          d.isBefore(twoWeeksOut.add(const Duration(days: 1)));
    }).toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2. Get Current 📅',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Upcoming 14d (${upcomingCommitments.length})'),
              Tab(
                text: zombieProjects.isEmpty
                    ? 'Projects Health (All Good)'
                    : 'Projects (${zombieProjects.length} ⚠️)',
              ),
              Tab(text: 'Waiting For (${waiting.length})'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                // Upcoming 14d Commitments (G-05)
                upcomingCommitments.isEmpty
                    ? const Center(
                        child: Text(
                          'No scheduled commitments in the next 14 days.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: upcomingCommitments.length,
                        itemBuilder: (context, index) => InPlaceTaskTile(
                          item: upcomingCommitments[index],
                          dense: true,
                        ),
                      ),

                // Active Projects & Zombie Check (D-04)
                ListView(
                  children: [
                    if (zombieProjects.isEmpty)
                      const Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                          title: Text(
                            'All active projects have at least one open Next Action!',
                          ),
                        ),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '⚠️ These projects have zero open Next Actions. Add one to keep momentum:',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      for (final z in zombieProjects) ...[
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 18,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        z.title.isNotEmpty
                                            ? z.title
                                            : z.relPath,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _zombieActionControllers
                                            .putIfAbsent(
                                              z.id,
                                              () => TextEditingController(),
                                            ),
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Next action (e.g. Draft proposal @computer)',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: () async {
                                        final ctrl =
                                            _zombieActionControllers[z.id];
                                        final text = ctrl?.text.trim() ?? '';
                                        if (text.isEmpty) return;
                                        await ref
                                            .read(vaultMutationProvider)
                                            .appendLineToDocument(
                                              relPath: z.relPath,
                                              lineText: '- [ ] $text',
                                            );
                                        ctrl?.clear();
                                      },
                                      child: const Text('Add'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),

                // Waiting For (D-06)
                waiting.isEmpty
                    ? const Center(
                        child: Text('No Waiting For items right now.'),
                      )
                    : ListView.builder(
                        itemCount: waiting.length,
                        itemBuilder: (context, index) =>
                            InPlaceTaskTile(item: waiting[index], dense: true),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepGetCreativeAndStale(
    ThemeData theme,
    List<IndexedEntryWithDocument> liveEntries,
    List<IndexedEntryWithDocument> futureItems,
  ) {
    final now = DateTime.now();
    final staleCutoffMs = now
        .subtract(const Duration(days: 14))
        .millisecondsSinceEpoch;

    // Stale items: open tasks with no touch in >= 14 days (R-03)
    final staleTasks = liveEntries.where((e) {
      if (!e.isOpenTask) return false;
      if (e.document.relPath == widget.targetRelPath) return false;
      return e.document.mtimeMs <= staleCutoffMs;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '3. Get Creative & Stale Review 💡',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            MetadataBadge(label: '${staleTasks.length} resting items'),
          ],
        ),
        const SizedBox(height: 6),
        // Non-shame, forgiving ADHD message (R-03, P-04)
        Card(
          color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(
                  Icons.favorite_outline,
                  size: 20,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No guilt here — life evolves! These items haven\'t been touched in 14+ days. Review them gently: keep, move to Someday, or let them go.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: staleTasks.isEmpty
              ? const Center(
                  child: Text('Zero stale tasks — everything is fresh!'),
                )
              : ListView.builder(
                  itemCount: staleTasks.length,
                  itemBuilder: (context, index) {
                    final item = staleTasks[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InPlaceTaskTile(item: item, dense: true),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.thumb_up_outlined,
                                    size: 14,
                                  ),
                                  label: const Text(
                                    'Keep (Active)',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () async {
                                    // Touch item to keep it active
                                    await ref
                                        .read(vaultMutationProvider)
                                        .setTaskStateInPlace(
                                          item,
                                          TaskStateKind.open,
                                        );
                                  },
                                ),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.lightbulb_outline,
                                    size: 14,
                                  ),
                                  label: const Text(
                                    'Move to Someday',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(vaultMutationProvider)
                                        .fileToReference(
                                          item,
                                          targetRelPath: 'someday.md',
                                        );
                                  },
                                ),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.close, size: 14),
                                  label: const Text(
                                    'Cancel (-)',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(vaultMutationProvider)
                                        .setTaskStateInPlace(
                                          item,
                                          TaskStateKind.cancelled,
                                        );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStepSetPriorities(ThemeData theme) {
    return ListView(
      children: [
        Text(
          '4. Choose Outcomes & Intentions 🎯',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'What are 1–3 high-level outcomes or themes that would make this ${widget.cadence.label.toLowerCase()} feel successful? These will be logged into ${widget.targetRelPath}.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _focusCtrl,
          decoration: InputDecoration(
            labelText: 'Key outcome for ${widget.targetRelPath}',
            hintText: 'e.g. Ship v1 prototype @computer',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
      ],
    );
  }
}
