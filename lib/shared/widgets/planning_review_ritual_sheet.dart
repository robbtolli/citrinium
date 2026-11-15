import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock/app_clock.dart';
import '../../core/index/index_providers.dart';
import '../../core/workspace/workspace_state.dart';
import 'in_place_task_tile.dart';

/// Launches a Planning or Review ritual for [ritualKind] (`B-06`, `B-07`,
/// `R-01`–`R-04`, `Q-02`, `Y-02`).
///
/// If the user configured [ritualKind] to use [CadenceExecutionMode.freeformMarkdown],
/// ensures the target cadence Markdown file exists on disk and notifies the
/// user so they can work directly in the Live Preview editor without a wizard.
Future<void> showPlanningReviewRitualSheet(
  BuildContext context,
  WidgetRef ref, {
  required RitualKind ritualKind,
  RitualDepthMode? initialDepthOverride,
}) async {
  final workspace = ref.read(workspaceStateProvider);
  final config = workspace.configForRitual(ritualKind);
  final now = ref.read(appClockProvider).now();

  if (config.executionMode == CadenceExecutionMode.freeformMarkdown) {
    final relPath = await ref
        .read(vaultMutationProvider)
        .ensureCadenceDocument(ritualKind.cadence, now);
    await ref
        .read(workspaceStateProvider.notifier)
        .recordRitualCompleted(ritualKind, now);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Freeform Markdown mode active: opened $relPath ready for your custom process.',
          ),
        ),
      );
    }
    return;
  }

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _PlanningReviewRitualModal(
      ritualKind: ritualKind,
      initialDepthOverride: initialDepthOverride,
    ),
  );
}

/// Opens the Three-Layer Planning & Review Process Customizer & Guidance
/// Settings dialog.
Future<void> showProcessCustomizerDialog(
  BuildContext context, {
  RitualKind initialRitual = RitualKind.dailyMorningPlan,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _ProcessCustomizerDialog(initialRitual: initialRitual),
  );
}

class _PlanningReviewRitualModal extends ConsumerStatefulWidget {
  const _PlanningReviewRitualModal({
    required this.ritualKind,
    this.initialDepthOverride,
  });

  final RitualKind ritualKind;
  final RitualDepthMode? initialDepthOverride;

  @override
  ConsumerState<_PlanningReviewRitualModal> createState() =>
      _PlanningReviewRitualModalState();
}

class _PlanningReviewRitualModalState
    extends ConsumerState<_PlanningReviewRitualModal> {
  late RitualDepthMode _depthMode;
  int _stepIndex = 0;
  bool _coachExpanded = true;
  bool _shutdownConfirmed = true;

  // Text controllers for interactive steps
  final TextEditingController _quickEventCtrl = TextEditingController();
  final TextEditingController _newFocusTaskCtrl = TextEditingController();
  final TextEditingController _microStepCtrl = TextEditingController();
  final TextEditingController _ifThenCueCtrl = TextEditingController();
  final TextEditingController _brainDumpTaskCtrl = TextEditingController();
  final TextEditingController _eveningReflectionCtrl = TextEditingController();
  final TextEditingController _tomorrowPriorityCtrl = TextEditingController();
  final TextEditingController _shutdownPhraseCtrl =
      TextEditingController(text: 'Shutdown complete.');
  final TextEditingController _mindSweepCtrl = TextEditingController();
  final TextEditingController _quarterScoreCtrl = TextEditingController();
  final TextEditingController _quarterBlockersCtrl = TextEditingController();
  final TextEditingController _thinkInsightsCtrl = TextEditingController();
  final TextEditingController _thinkExperimentsCtrl = TextEditingController();
  final TextEditingController _peakPositiveCtrl = TextEditingController();
  final TextEditingController _notToDoCtrl = TextEditingController();
  final TextEditingController _virtueThemeCtrl = TextEditingController();
  final TextEditingController _avoidAtAllCostsCtrl = TextEditingController();
  final TextEditingController _outcomesCtrl = TextEditingController();
  final TextEditingController _bridgeActionCtrl = TextEditingController();

  final Map<int, TextEditingController> _zombieControllers = {};
  final Map<String, TextEditingController> _fiveQControllers = {
    '1. What did I accomplish?': TextEditingController(),
    '2. What went unfinished or failed?': TextEditingController(),
    '3. What am I grateful for?': TextEditingController(),
    '4. What lessons did I learn?': TextEditingController(),
    '5. What will I change next year?': TextEditingController(),
  };
  final Map<String, TextEditingController> _customPromptControllers = {};
  final Set<String> _checkedCustomItems = {};

  @override
  void initState() {
    super.initState();
    final ws = ref.read(workspaceStateProvider);
    final cfg = ws.configForRitual(widget.ritualKind);
    _depthMode = widget.initialDepthOverride ?? cfg.preferredDepth;
    _coachExpanded = ws.shouldAutoExpandCoachTips(widget.ritualKind);

    final steps = cfg.activeSteps(depthOverride: _depthMode);
    final savedStep = ws.resumableStepForRitual(widget.ritualKind);
    if (savedStep > 0 && savedStep < steps.length) {
      _stepIndex = savedStep;
    }
  }

  @override
  void dispose() {
    _quickEventCtrl.dispose();
    _newFocusTaskCtrl.dispose();
    _microStepCtrl.dispose();
    _ifThenCueCtrl.dispose();
    _brainDumpTaskCtrl.dispose();
    _eveningReflectionCtrl.dispose();
    _tomorrowPriorityCtrl.dispose();
    _shutdownPhraseCtrl.dispose();
    _mindSweepCtrl.dispose();
    _quarterScoreCtrl.dispose();
    _quarterBlockersCtrl.dispose();
    _thinkInsightsCtrl.dispose();
    _thinkExperimentsCtrl.dispose();
    _peakPositiveCtrl.dispose();
    _notToDoCtrl.dispose();
    _virtueThemeCtrl.dispose();
    _avoidAtAllCostsCtrl.dispose();
    _outcomesCtrl.dispose();
    _bridgeActionCtrl.dispose();
    for (final c in _zombieControllers.values) {
      c.dispose();
    }
    for (final c in _fiveQControllers.values) {
      c.dispose();
    }
    for (final c in _customPromptControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _setStep(int newStep, int maxSteps) {
    final clamped = newStep.clamp(0, maxSteps - 1);
    setState(() => _stepIndex = clamped);
    ref
        .read(workspaceStateProvider.notifier)
        .setRitualResumableStep(widget.ritualKind, clamped);
  }

  Future<void> _finishRitual(
    RitualProcessConfig config,
    String todayIso,
  ) async {
    final now = ref.read(appClockProvider).now();
    final ws = ref.read(workspaceStateProvider);
    final presetName = config.executionMode == CadenceExecutionMode.customSteps
        ? 'Custom Process'
        : (PlanningPresetCatalog.findById(config.selectedPresetId)?.name ??
            widget.ritualKind.label);

    final outcomes = _outcomesCtrl.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final customPrompts = <String, String>{};
    for (final entry in _customPromptControllers.entries) {
      if (entry.value.text.trim().isNotEmpty) {
        customPrompts[entry.key] = entry.value.text.trim();
      }
    }

    final fiveQ = <String, String>{};
    for (final entry in _fiveQControllers.entries) {
      if (entry.value.text.trim().isNotEmpty) {
        fiveQ[entry.key] = entry.value.text.trim();
      }
    }

    final hasShutdownStep = config
        .activeSteps(depthOverride: _depthMode)
        .any((s) => s.kind == RitualStepKind.shutdownComplete);

    final output = RitualSessionOutput(
      ritualKind: widget.ritualKind,
      depthMode: _depthMode,
      presetName: presetName,
      completedAtIso: now.toIso8601String(),
      ruleOfOneFloorDay: ws.isRuleOfOneOn(todayIso),
      microFirstStepText: _microStepCtrl.text,
      ifThenCueText: _ifThenCueCtrl.text,
      eveningWinsAndLooseEnds: _eveningReflectionCtrl.text,
      tomorrowTopPriority: _tomorrowPriorityCtrl.text,
      shutdownPhrase:
          (hasShutdownStep && _shutdownConfirmed) ? _shutdownPhraseCtrl.text : '',
      quarterGoalScoreSummary: _quarterScoreCtrl.text,
      quarterBlockersAndFixes: _quarterBlockersCtrl.text,
      thinkWeekInsights: _thinkInsightsCtrl.text,
      thinkWeekExperiments: _thinkExperimentsCtrl.text,
      peakPositiveActivities: _peakPositiveCtrl.text,
      notToDoEnergyDrains: _notToDoCtrl.text,
      fiveQuestionAnswers: fiveQ,
      focalVirtueOrTheme: _virtueThemeCtrl.text,
      avoidAtAllCostsList: _avoidAtAllCostsCtrl.text,
      periodOutcomes: outcomes,
      bridgeActionForNextLowerCadence: _bridgeActionCtrl.text,
      customPromptResponses: customPrompts,
      completedCustomChecklistItems: _checkedCustomItems.toList(),
    );

    final targetRel = await ref
        .read(vaultMutationProvider)
        .commitRitualSessionOutput(output: output, now: now);

    await ref
        .read(workspaceStateProvider.notifier)
        .recordRitualCompleted(widget.ritualKind, now);

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.ritualKind.label} complete! Logged to $targetRel.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final workspace = ref.watch(workspaceStateProvider);
    final entriesAsync = ref.watch(allEntriesWithDocumentsProvider);
    final docsAsync = ref.watch(documentListProvider);

    final allEntries = entriesAsync.value ?? const [];
    final allDocs = docsAsync.value ?? const [];
    final now = ref.watch(appClockProvider).now();
    final todayIso = NlDateParser.formatIsoDate(now);
    final targetRelPath =
        CadenceFiles.relPathForCadence(widget.ritualKind.cadence, now);

    final config = workspace.configForRitual(widget.ritualKind);
    final steps = config.activeSteps(depthOverride: _depthMode);
    final safeStepIndex = _stepIndex.clamp(0, steps.length - 1);
    final currentStep = steps[safeStepIndex];

    final preset = PlanningPresetCatalog.findById(config.selectedPresetId);
    final modeSubtitle =
        config.executionMode == CadenceExecutionMode.customSteps
            ? 'Custom Process (${steps.length} steps)'
            : (preset?.name ?? widget.ritualKind.label);

    final savedStep = workspace.resumableStepForRitual(widget.ritualKind);
    final isResumed = savedStep > 0 && safeStepIndex == savedStep;

    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final availableHeight = (screenHeight - viewInsetsBottom).clamp(260.0, 900.0);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: viewInsetsBottom + 12,
      ),
      child: SizedBox(
        height: availableHeight * 0.86,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Title + Customize Process + Save & Pause
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.ritualKind.label} · Step ${safeStepIndex + 1} of ${steps.length}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$modeSubtitle → $targetRelPath',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Customize Process, Presets & Guidance',
                  icon: const Icon(Icons.tune, size: 20),
                  onPressed: () {
                    showProcessCustomizerDialog(
                      context,
                      initialRitual: widget.ritualKind,
                    );
                  },
                ),
                TextButton(
                  onPressed: () {
                    ref
                        .read(workspaceStateProvider.notifier)
                        .setRitualResumableStep(
                          widget.ritualKind,
                          safeStepIndex,
                        );
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save & Pause'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (safeStepIndex + 1) / steps.length,
            ),
            const SizedBox(height: 8),

            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Full vs. Minimal (Express) Toggle Bar + Estimated Time
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SegmentedButton<RitualDepthMode>(
                              showSelectedIcon: false,
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                              ),
                              segments: [
                                ButtonSegment(
                                  value: RitualDepthMode.full,
                                  label: Text(
                                    'Full (${widget.ritualKind.defaultFullMinutes})',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                ButtonSegment(
                                  value: RitualDepthMode.minimal,
                                  label: Text(
                                    '⚡ Minimal (${widget.ritualKind.defaultMinimalMinutes})',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                              selected: {_depthMode},
                              onSelectionChanged: (sel) {
                                final nextDepth = sel.first;
                                setState(() {
                                  _depthMode = nextDepth;
                                  _stepIndex = 0;
                                });
                                ref
                                    .read(workspaceStateProvider.notifier)
                                    .updateRitualProcessConfig(
                                      widget.ritualKind,
                                      config.copyWith(
                                        preferredDepth: nextDepth,
                                      ),
                                    );
                              },
                            ),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.timer_outlined, size: 14),
                              label: Text(
                                '~${currentStep.estimatedMinutes} min step',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            if (currentStep.coachWhy.isNotEmpty ||
                                currentStep.coachAvoidTrap.isNotEmpty)
                              ActionChip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(
                                  _coachExpanded
                                      ? Icons.lightbulb
                                      : Icons.lightbulb_outline,
                                  size: 14,
                                ),
                                label: Text(
                                  _coachExpanded
                                      ? 'Hide Coach Tip'
                                      : '💡 Why & How',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onPressed: () => setState(
                                  () => _coachExpanded = !_coachExpanded,
                                ),
                              ),
                          ],
                        ),

                        if (isResumed)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.history, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Resumed at Step ${safeStepIndex + 1}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref
                                        .read(workspaceStateProvider.notifier)
                                        .resetRitualProgress(widget.ritualKind);
                                    setState(() => _stepIndex = 0);
                                  },
                                  child: const Text(
                                    'Start Fresh',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 8),

                        // Step Title & Subtitle
                        Text(
                          currentStep.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (currentStep.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            currentStep.subtitle,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],

                        // Progressive Coaching Callout (Auto-collapses after 3 completions, or 1-click disable)
                        if (_coachExpanded &&
                            (currentStep.coachWhy.isNotEmpty ||
                                currentStep.coachAvoidTrap.isNotEmpty)) ...[
                          const SizedBox(height: 6),
                          Card(
                            elevation: 0,
                            color: colorScheme.secondaryContainer
                                .withValues(alpha: 0.45),
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (currentStep.coachWhy.isNotEmpty)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.psychology_outlined,
                                          size: 16,
                                          color:
                                              colorScheme.onSecondaryContainer,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Why this works: ${currentStep.coachWhy}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme
                                                  .onSecondaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (currentStep.coachAvoidTrap.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.shield_outlined,
                                          size: 16,
                                          color:
                                              colorScheme.onSecondaryContainer,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Avoid overwhelm: ${currentStep.coachAvoidTrap}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme
                                                  .onSecondaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () {
                                          ref
                                              .read(
                                                workspaceStateProvider.notifier,
                                              )
                                              .setGuidanceEnabled(false);
                                          setState(
                                            () => _coachExpanded = false,
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Guidance disabled. You can re-enable it or customize your process anytime.',
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          'Disable Guidance (I have my own process)',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
                // Interactive Step Body
                body: _buildStepBody(
                  context: context,
                  step: currentStep,
                  workspace: workspace,
                  allEntries: allEntries,
                  allDocs: allDocs,
                  now: now,
                  todayIso: todayIso,
                  targetRelPath: targetRelPath,
                ),
              ),
            ),

            const Divider(height: 16),

            // Bottom Navigation Buttons
            Row(
              children: [
                if (safeStepIndex > 0)
                  OutlinedButton(
                    onPressed: () =>
                        _setStep(safeStepIndex - 1, steps.length),
                    child: const Text('← Back'),
                  ),
                const Spacer(),
                if (safeStepIndex < steps.length - 1)
                  FilledButton(
                    onPressed: () =>
                        _setStep(safeStepIndex + 1, steps.length),
                    child: const Text('Next Step →'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _finishRitual(config, todayIso),
                    icon: const Icon(Icons.check),
                    label: Text('Complete ${widget.ritualKind.shortLabel}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBody({
    required BuildContext context,
    required RitualStepSpec step,
    required WorkspaceState workspace,
    required List<IndexedEntryWithDocument> allEntries,
    required List<Document> allDocs,
    required DateTime now,
    required String todayIso,
    required String targetRelPath,
  }) {
    final theme = Theme.of(context);
    final dailyRel = CadenceFiles.dailyRelPath(now);

    switch (step.kind) {
      case RitualStepKind.hardLandscapeCheck:
        final todayEvents = allEntries.where((e) {
          return e.isEvent &&
              (e.document.relPath == dailyRel || e.entry.dueDate == todayIso);
        }).toList();

        return ListView(
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Fixed-Time Commitments (${todayEvents.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      todayEvents.isEmpty
                          ? 'No fixed events logged for today ($todayIso). Protect buffer space for deep work!'
                          : 'Protect a 30-minute transition buffer around these appointments:',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    for (final ev in todayEvents)
                      InPlaceTaskTile(item: ev, dense: true),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quickEventCtrl,
                    decoration: InputDecoration(
                      labelText: 'Add a scheduled event for today',
                      hintText: 'e.g. Team sync ⏰ 14:00',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final raw = _quickEventCtrl.text.trim();
                    if (raw.isEmpty) return;
                    await ref.read(vaultMutationProvider).captureLine(
                      rawInput: '$raw 📅 $todayIso',
                      toTodayLog: true,
                      defaultPrefix: '- ○ ',
                      now: now,
                    );
                    _quickEventCtrl.clear();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Event'),
                ),
              ],
            ),
          ],
        );

      case RitualStepKind.carryoverMigration:
        final openCandidates = allEntries.where((e) {
          if (!e.isOpenTask) return false;
          if (widget.ritualKind == RitualKind.dailyMorningPlan) {
            return e.document.relPath.startsWith('daily/') &&
                e.document.relPath.compareTo(dailyRel) < 0;
          }
          if (widget.ritualKind == RitualKind.dailyEveningShutdown) {
            return e.document.relPath.startsWith('daily/') &&
                e.document.relPath.compareTo(dailyRel) <= 0;
          }
          return e.document.relPath != targetRelPath;
        }).toList();

        if (openCandidates.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 44,
                  color: Colors.green,
                ),
                const SizedBox(height: 8),
                Text(
                  'All open loops are clean and up to date!',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          );
        }

        final tomorrow = now.add(const Duration(days: 1));
        final migrateTargetRel =
            widget.ritualKind == RitualKind.dailyEveningShutdown
                ? CadenceFiles.dailyRelPath(tomorrow)
                : targetRelPath;
        final migrateLabel =
            widget.ritualKind == RitualKind.dailyEveningShutdown
                ? 'Tomorrow >'
                : 'Move to ${widget.ritualKind.cadence.label} >';

        return ListView.builder(
          itemCount: openCandidates.length,
          itemBuilder: (ctx, idx) {
            final item = openCandidates[idx];
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
                          avatar: const Icon(Icons.check, size: 14),
                          label: const Text(
                            'Done [x]',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            ref
                                .read(vaultMutationProvider)
                                .completeOrAdvanceTask(item, now: now);
                          },
                        ),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.arrow_forward, size: 14),
                          label: Text(
                            migrateLabel,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            ref
                                .read(vaultMutationProvider)
                                .migrateOrScheduleEntry(
                                  item,
                                  targetRelPath: migrateTargetRel,
                                  targetInitialContent:
                                      CadenceFiles.defaultContentForCadence(
                                        widget.ritualKind.cadence,
                                        widget.ritualKind ==
                                                RitualKind.dailyEveningShutdown
                                            ? tomorrow
                                            : now,
                                      ),
                                );
                          },
                        ),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(
                            Icons.calendar_month_outlined,
                            size: 14,
                          ),
                          label: const Text(
                            'Future Log <',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            ref
                                .read(vaultMutationProvider)
                                .migrateOrScheduleEntry(
                                  item,
                                  targetRelPath: CadenceFiles.futureLogRelPath,
                                  targetInitialContent:
                                      CadenceFiles.defaultContentForCadence(
                                        CadenceKind.future,
                                        now,
                                      ),
                                );
                          },
                        ),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.spa_outlined, size: 14),
                          label: const Text(
                            'Someday',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            ref
                                .read(vaultMutationProvider)
                                .migrateOrScheduleEntry(
                                  item,
                                  targetRelPath: CadenceFiles.somedayRelPath,
                                  targetInitialContent:
                                      CadenceFiles.defaultSomedayContent(),
                                );
                          },
                        ),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.close, size: 14),
                          label: const Text(
                            'Drop (-)',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            ref
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
        );

      case RitualStepKind.topFocusSelection:
        final ruleOfOne = workspace.isRuleOfOneOn(todayIso);
        final effectiveMax = ruleOfOne ? 1 : step.maxFocusItems;
        final openTasks = allEntries.where((e) => e.isOpenTask).toList();
        final pinnedCount = workspace.topThreePinnedKeys.length;

        return ListView(
          children: [
            // Anti-Paralysis "Rule of 1 (Floor Day)" Toggle
            SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              secondary: const Icon(Icons.self_improvement_outlined),
              title: const Text(
                '🛟 Low-Energy Day (Focus on 1 Thing)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              subtitle: const Text(
                'Feeling overwhelmed? Cap today\'s focus to 1 single task. Finishing that 1 task wins the day.',
                style: TextStyle(fontSize: 11),
              ),
              value: ruleOfOne,
              onChanged: (val) {
                ref
                    .read(workspaceStateProvider.notifier)
                    .toggleRuleOfOneFloorDay(todayIso, enabled: val);
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newFocusTaskCtrl,
                    decoration: InputDecoration(
                      labelText:
                          'Add & pin a new priority task ($pinnedCount/$effectiveMax pinned)',
                      hintText: 'e.g. Draft Q4 summary @computer',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final raw = _newFocusTaskCtrl.text.trim();
                    if (raw.isEmpty) return;
                    await ref.read(vaultMutationProvider).captureLine(
                      rawInput: '$raw 📅 $todayIso',
                      toTodayLog: true,
                      now: now,
                    );
                    _newFocusTaskCtrl.clear();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add to Today'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Tap the 📌 pin icon on up to $effectiveMax task${effectiveMax == 1 ? '' : 's'} for Today\'s Focus Shelf:',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            if (openTasks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No open tasks yet. Add your #1 task above!'),
              )
            else
              for (final item in openTasks)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  color: workspace.isPinnedToday(item.uniqueKey)
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                      : null,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: workspace.isPinnedToday(item.uniqueKey)
                            ? 'Unpin from Focus Shelf'
                            : 'Pin to Today\'s Focus Shelf',
                        icon: Icon(
                          workspace.isPinnedToday(item.uniqueKey)
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          size: 18,
                          color: workspace.isPinnedToday(item.uniqueKey)
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        onPressed: () async {
                          final ok = await ref
                              .read(workspaceStateProvider.notifier)
                              .togglePinToday(
                                item.uniqueKey,
                                allowOverThree: effectiveMax > 3 &&
                                    workspace.topThreePinnedKeys.length <
                                        effectiveMax,
                              );
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Focus Shelf is capped at $effectiveMax task${effectiveMax == 1 ? '' : 's'} to prevent overwhelm.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      Expanded(
                        child: InPlaceTaskTile(item: item, dense: true),
                      ),
                    ],
                  ),
                ),
          ],
        );

      case RitualStepKind.microFirstStep:
        final pinned = allEntries
            .where((e) => workspace.isPinnedToday(e.uniqueKey))
            .toList();
        final topOne = pinned.isNotEmpty ? pinned.first : null;

        return ListView(
          children: [
            if (topOne != null)
              Card(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.looks_one_outlined),
                  title: Text(
                    'Task #1: ${topOne.entry.textContent}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Ask: "Is the first step small enough to start in 2 minutes?"',
                  ),
                ),
              ),
            TextField(
              controller: _microStepCtrl,
              decoration: const InputDecoration(
                labelText: '2-Minute Physical Micro-First-Step (Solanto)',
                hintText:
                    'e.g. Open budget.xlsx and type the 3 column headers',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ifThenCueCtrl,
              decoration: const InputDecoration(
                labelText: 'When will you start? (After..., I will...)',
                hintText:
                    'e.g. When I sit down with my coffee at 9:00 AM, I will open budget.xlsx',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );

      case RitualStepKind.brainDumpLooseEnds:
        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _brainDumpTaskCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quick Brain Dump to Inbox (get loose loops out of your head)',
                      hintText: 'e.g. Reply to Alex about Tuesday agenda',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final raw = _brainDumpTaskCtrl.text.trim();
                    if (raw.isEmpty) return;
                    await ref.read(vaultMutationProvider).captureLine(
                      rawInput: raw,
                      toTodayLog: false,
                      now: now,
                    );
                    _brainDumpTaskCtrl.clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Captured safely into inbox.md.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.inbox_outlined, size: 16),
                  label: const Text('Dump to Inbox'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _eveningReflectionCtrl,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText:
                    'Evening Reflection: What good have I done today / what did I learn?',
                hintText:
                    'Jot down 1–2 wins or takeaways to log into today\'s Daily Log...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );

      case RitualStepKind.tomorrowPreview:
        final tomorrow = now.add(const Duration(days: 1));
        final tomorrowIso = NlDateParser.formatIsoDate(tomorrow);
        final tomorrowRel = CadenceFiles.dailyRelPath(tomorrow);
        final tomorrowEvents = allEntries.where((e) {
          return e.entry.dueDate == tomorrowIso ||
              e.document.relPath == tomorrowRel;
        }).toList();

        return ListView(
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tomorrow ($tomorrowIso) Scheduled Items (${tomorrowEvents.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (tomorrowEvents.isEmpty)
                      Text(
                        'No fixed events scheduled for tomorrow yet.',
                        style: theme.textTheme.bodySmall,
                      )
                    else
                      for (final ev in tomorrowEvents)
                        InPlaceTaskTile(item: ev, dense: true),
                  ],
                ),
              ),
            ),
            TextField(
              controller: _tomorrowPriorityCtrl,
              decoration: InputDecoration(
                labelText:
                    'Lock Tomorrow\'s #1 Priority (Ivy Lee / Ferriss Evening Lock)',
                hintText:
                    'Will be added directly into $tomorrowRel so you start tomorrow with clarity',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        );

      case RitualStepKind.shutdownComplete:
        return ListView(
          children: [
            Card(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              child: SwitchListTile(
                secondary: const Icon(Icons.nights_stay_outlined),
                title: const Text(
                  'Workspace Closed & Open Loops Trusted to Citrine',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Every open loop is captured or migrated. You have permission to disconnect completely.',
                ),
                value: _shutdownConfirmed,
                onChanged: (val) => setState(() => _shutdownConfirmed = val),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shutdownPhraseCtrl,
              decoration: const InputDecoration(
                labelText: 'Your Shutdown Phrase (Cal Newport Ritual)',
                helperText:
                    'Written to today\'s Daily Log when you click Complete below.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );

      case RitualStepKind.celebrateAndMindSweep:
        final completedTasks =
            allEntries.where((e) => e.isCompletedTask).toList();
        final inboxTasks = allEntries
            .where((e) => e.document.relPath == 'inbox.md' && e.isOpenTask)
            .toList();

        return ListView(
          children: [
            Card(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.celebration_outlined),
                title: Text(
                  'Celebrate What Shipped: ${completedTasks.length} completed tasks in vault! 🎉',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Acknowledge your progress before triaging what\'s next.',
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mindSweepCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mind-Sweep: Dump any lingering open loop to Inbox',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () async {
                    final raw = _mindSweepCtrl.text.trim();
                    if (raw.isEmpty) return;
                    await ref.read(vaultMutationProvider).captureLine(
                      rawInput: raw,
                      toTodayLog: false,
                      now: now,
                    );
                    _mindSweepCtrl.clear();
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              inboxTasks.isEmpty
                  ? '✅ Inbox Zero Achieved (0 unclarified items in inbox.md)!'
                  : 'Clarify inbox.md to Zero (${inboxTasks.length} remaining):',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            for (final item in inboxTasks)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InPlaceTaskTile(item: item, dense: true),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: const Text(
                              'Next Action',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              ref
                                  .read(vaultMutationProvider)
                                  .migrateOrScheduleEntry(
                                    item,
                                    targetRelPath: targetRelPath,
                                    targetInitialContent:
                                        CadenceFiles.defaultContentForCadence(
                                          widget.ritualKind.cadence,
                                          now,
                                        ),
                                  );
                            },
                          ),
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: const Text(
                              'Promote to Project',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              ref
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
                            label: const Text(
                              'Waiting For',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              ref
                                  .read(vaultMutationProvider)
                                  .delegateToWaitingFor(
                                    item,
                                    delegateTo: 'Follow-up',
                                  );
                            },
                          ),
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: const Text(
                              'Someday',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              ref
                                  .read(vaultMutationProvider)
                                  .fileToReference(
                                    item,
                                    targetRelPath: 'someday.md',
                                  );
                            },
                          ),
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: const Text(
                              'Reference',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              ref
                                  .read(vaultMutationProvider)
                                  .fileToReference(item);
                            },
                          ),
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: const Text(
                              'Drop (-)',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              ref
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
              ),
          ],
        );

      case RitualStepKind.calendarAndWaitingCheck:
        final twoWeeksOut = now.add(const Duration(days: 14));
        final waiting = allEntries.where((e) => e.isWaitingTask).toList();
        final upcoming = allEntries.where((e) {
          if (e.entry.dueDate == null) return false;
          final d = DateTime.tryParse(e.entry.dueDate!);
          if (d == null) return false;
          return d.isAfter(now.subtract(const Duration(days: 1))) &&
              d.isBefore(twoWeeksOut.add(const Duration(days: 1)));
        }).toList();

        return ListView(
          children: [
            Text(
              'Upcoming 14-Day Commitments (${upcoming.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (upcoming.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('No dated commitments in the next 14 days.'),
              )
            else
              for (final item in upcoming)
                InPlaceTaskTile(item: item, dense: true),
            const Divider(height: 20),
            Text(
              'Waiting For / Delegated Items (${waiting.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (waiting.isEmpty)
              const Text('No Waiting For items right now.')
            else
              for (final w in waiting) InPlaceTaskTile(item: w, dense: true),
          ],
        );

      case RitualStepKind.zombieProjectsCheck:
        final projects = allDocs.where((d) {
          return d.docType == 'project' || d.relPath.startsWith('projects/');
        }).toList();
        final zombieProjects = projects.where((p) {
          return !allEntries.any(
            (e) => e.document.id == p.id && e.isOpenTask,
          );
        }).toList();

        if (zombieProjects.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 44,
                  color: Colors.green,
                ),
                const SizedBox(height: 8),
                Text(
                  'All ${projects.length} active project(s) have an open Next Action!',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          );
        }

        return ListView(
          children: [
            Text(
              '⚠️ ${zombieProjects.length} project(s) have no open next action. Add a quick next step:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            for (final z in zombieProjects)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        z.title.isNotEmpty ? z.title : z.relPath,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _zombieControllers.putIfAbsent(
                                z.id,
                                () => TextEditingController(),
                              ),
                              decoration: const InputDecoration(
                                hintText:
                                    'Next physical action (e.g. Email Alex @computer)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () async {
                              final ctrl = _zombieControllers[z.id];
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
                            child: const Text('Add Action'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );

      case RitualStepKind.staleAndSomedayTriage:
        final staleCutoffMs =
            now.subtract(const Duration(days: 14)).millisecondsSinceEpoch;
        final staleTasks = allEntries.where((e) {
          if (!e.isOpenTask) return false;
          if (e.document.relPath == targetRelPath) return false;
          return e.document.mtimeMs <= staleCutoffMs;
        }).toList();
        final somedayItems = allEntries.where((e) {
          return e.document.relPath == CadenceFiles.somedayRelPath;
        }).toList();

        return ListView(
          children: [
            Text(
              'Resting / Untouched 14+ Days (${staleTasks.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (staleTasks.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Zero stale tasks — everything is fresh!'),
              )
            else
              for (final item in staleTasks)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InPlaceTaskTile(item: item, dense: true),
                        Wrap(
                          spacing: 6,
                          children: [
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text(
                                'Keep Active',
                                style: TextStyle(fontSize: 11),
                              ),
                              onPressed: () {
                                ref
                                    .read(vaultMutationProvider)
                                    .setTaskStateInPlace(
                                      item,
                                      TaskStateKind.open,
                                    );
                              },
                            ),
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text(
                                'Move to Someday',
                              style: TextStyle(fontSize: 11),
                              ),
                              onPressed: () {
                                ref
                                    .read(vaultMutationProvider)
                                    .fileToReference(
                                      item,
                                      targetRelPath: 'someday.md',
                                    );
                              },
                            ),
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text(
                                'Drop (-)',
                                style: TextStyle(fontSize: 11),
                              ),
                              onPressed: () {
                                ref
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
                ),
            const Divider(height: 20),
            Text(
              'Someday / Maybe Incubator (${somedayItems.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (somedayItems.isEmpty)
              const Text('No items in someday.md yet.')
            else
              for (final s in somedayItems)
                InPlaceTaskTile(item: s, dense: true),
          ],
        );

      case RitualStepKind.futureLogPullForward:
        final futureItems = allEntries.where((e) {
          return e.document.relPath == CadenceFiles.futureLogRelPath &&
              !e.isCompletedTask;
        }).toList();

        if (futureItems.isEmpty) {
          return const Center(
            child: Text('No pending items in future.md right now.'),
          );
        }

        return ListView.builder(
          itemCount: futureItems.length,
          itemBuilder: (ctx, idx) {
            final item = futureItems[idx];
            final isNarrow = MediaQuery.sizeOf(context).width < 480;
            final pullButton = FilledButton.tonalIcon(
              onPressed: () {
                ref
                    .read(vaultMutationProvider)
                    .migrateOrScheduleEntry(
                      item,
                      targetRelPath: targetRelPath,
                      targetInitialContent:
                          CadenceFiles.defaultContentForCadence(
                            widget.ritualKind.cadence,
                            now,
                          ),
                    );
              },
              icon: const Icon(Icons.download_outlined, size: 16),
              label: Text('Pull to ${widget.ritualKind.cadence.label}'),
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InPlaceTaskTile(item: item, dense: true),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: pullButton,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: InPlaceTaskTile(item: item, dense: true)),
                          const SizedBox(width: 8),
                          pullButton,
                        ],
                      ),
              ),
            );
          },
        );

      case RitualStepKind.habitRhythmReview:
        final habits = allEntries.where((e) => e.isHabit).toList();
        return ListView(
          children: [
            const Text(
              'Non-Punitive Habit Rhythm Check-In (7-Day Window)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            if (habits.isEmpty)
              const Text(
                'No habits tagged with #habit yet. Add #habit and 🔁 daily to any task to track rhythm without streak shame.',
              )
            else
              for (final h in habits)
                Builder(
                  builder: (ctx) {
                    final completedToday =
                        workspace.isHabitCompletedOn(h.uniqueKey, todayIso);
                    final completedDates =
                        workspace.habitCompletionsByDate[h.uniqueKey] ??
                            const [];
                    final rule = RecurrenceRule.tryParse(h.entry.recurrenceRaw);
                    final summary = HabitTrackerEngine.summarize(
                      rule: rule,
                      completedIsoDates: completedDates,
                      referenceDate: now,
                      windowDays: 7,
                    );
                    final dots = summary.recentDays
                        .map(
                          (d) => switch (d.state) {
                            HabitDayState.completed => '●',
                            HabitDayState.unloggedScheduled => '·',
                            HabitDayState.restDay => '○',
                          },
                        )
                        .join(' ');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: CheckboxListTile(
                        dense: true,
                        value: completedToday,
                        title: Text(h.entry.textContent),
                        subtitle: Text(
                          '7d Rhythm: [$dots] · ${summary.supportiveSummaryText}',
                        ),
                        onChanged: (_) {
                          ref
                              .read(workspaceStateProvider.notifier)
                              .toggleHabitCompletion(h.uniqueKey, todayIso);
                        },
                      ),
                    );
                  },
                ),
            const SizedBox(height: 12),
            TextField(
              controller: _virtueThemeCtrl,
              decoration: const InputDecoration(
                labelText: 'Habit / Virtue Adjustment Note (Optional)',
                hintText:
                    'e.g. Move stretching cue next to coffee maker (Wendy Wood context cue)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );

      case RitualStepKind.quarterGoalScoring:
        return ListView(
          children: [
            TextField(
              controller: _quarterScoreCtrl,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText:
                    'Prior Cycle Goal Score & Key Wins (12-Week Year Review)',
                hintText:
                    'Score your execution (e.g. 85% of weekly actions completed) and list what worked well...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quarterBlockersCtrl,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText:
                    'Root-Cause Blockers & Environmental Fixes (Engineering Data)',
                hintText:
                    'Where did friction happen, and what structural adjustment will prevent it next cycle?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );

      case RitualStepKind.thinkWeekSynthesis:
        return ListView(
          children: [
            TextField(
              controller: _thinkInsightsCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText:
                    'Deep-Thinking Synthesis & Strategic Insights (Bill Gates Think Week)',
                hintText:
                    'Summarize long-term trends, reading insights, or big questions...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _thinkExperimentsCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText:
                    '1–3 Concrete Experiments to Run This Quarter (1 per line)',
                hintText:
                    'Each line becomes an actionable "- [ ] Experiment: ..." task in your Quarterly Log',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );

      case RitualStepKind.eightyTwentyEnergyAudit:
        return ListView(
          children: [
            TextField(
              controller: _peakPositiveCtrl,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText:
                    '➕ Peak Positive (Top 20% activities/people/projects producing 80% of results & joy)',
                hintText:
                    'What should you double down on and block onto your calendar first?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notToDoCtrl,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText:
                    '➖ Strict "Not-To-Do" List (Top 20% energy drains to eliminate)',
                hintText:
                    'What commitments, habits, or drains will you actively drop next year?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );

      case RitualStepKind.fiveQuestionSelfAudit:
        return ListView(
          children: [
            for (final entry in _fiveQControllers.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: entry.value,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: entry.key,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
          ],
        );

      case RitualStepKind.focalVirtueAndVision:
        return ListView(
          children: [
            TextField(
              controller: _virtueThemeCtrl,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText:
                    'Focal Virtue / Annual Theme & Commitment Statement (Ben Franklin)',
                hintText:
                    'e.g. Order & Calm Execution — "I like a speckled axe best"',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _avoidAtAllCostsCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText:
                    'Warren Buffett 5/25 "Avoid-At-All-Costs" List (Goals 6–25)',
                hintText:
                    'Appealing distractions you will deliberately ignore until your top priorities are done...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );

      case RitualStepKind.periodOutcomesAndBridge:
        final showBridge =
            widget.ritualKind.cadence != CadenceKind.daily &&
            widget.ritualKind.cadence != CadenceKind.weekly;
        return ListView(
          children: [
            TextField(
              controller: _outcomesCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText:
                    'Core Outcomes / Priorities for $targetRelPath (1 per line)',
                hintText:
                    'Each line will be added as an actionable "- [ ]" outcome in $targetRelPath',
                border: const OutlineInputBorder(),
              ),
            ),
            if (showBridge) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _bridgeActionCtrl,
                decoration: const InputDecoration(
                  labelText:
                      'Bridge to Next Lower Horizon (First tactical action for this week/quarter)',
                  hintText:
                      'Automatically links into your active lower-horizon plan',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        );

      case RitualStepKind.customReflectionPrompt:
        final headingKey = step.markdownHeading.trim().isNotEmpty
            ? step.markdownHeading.trim()
            : '## ${step.title}';
        final ctrl = _customPromptControllers.putIfAbsent(
          headingKey,
          () => TextEditingController(),
        );
        return ListView(
          children: [
            TextField(
              controller: ctrl,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: step.promptQuestion.isNotEmpty
                    ? step.promptQuestion
                    : step.title,
                helperText: 'Saved under "$headingKey" in $targetRelPath',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        );

      case RitualStepKind.customChecklist:
        final items = step.checklistItems.isEmpty
            ? const ['Review calendar', 'Check open tasks', 'Set top priority']
            : step.checklistItems;
        return ListView(
          children: [
            for (final item in items)
              CheckboxListTile(
                value: _checkedCustomItems.contains(item),
                title: Text(item),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _checkedCustomItems.add(item);
                    } else {
                      _checkedCustomItems.remove(item);
                    }
                  });
                },
              ),
          ],
        );
    }
  }
}

/// Dialog for configuring Citrine's Three-Layer Planning & Review Process
/// Flexibility and Progressive Learning Guidance (`B-11`, `B-12`, `A-06`).
class _ProcessCustomizerDialog extends ConsumerStatefulWidget {
  const _ProcessCustomizerDialog({required this.initialRitual});

  final RitualKind initialRitual;

  @override
  ConsumerState<_ProcessCustomizerDialog> createState() =>
      _ProcessCustomizerDialogState();
}

class _ProcessCustomizerDialogState
    extends ConsumerState<_ProcessCustomizerDialog> {
  late RitualKind _selectedRitual = widget.initialRitual;

  Future<void> _saveConfig(RitualProcessConfig updated) async {
    await ref
        .read(workspaceStateProvider.notifier)
        .updateRitualProcessConfig(_selectedRitual, updated);
    await ref.read(vaultMutationProvider).syncPortableProcessConfigToVault();
  }

  void _showAddCustomStepSheet(
    BuildContext context,
    RitualProcessConfig config,
  ) {
    final titleCtrl = TextEditingController();
    final promptCtrl = TextEditingController();
    var isChecklist = false;
    var inMinimal = true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Add Custom Step to ${_selectedRitual.shortLabel}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Reflection Prompt'),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Checklist Step'),
                    ),
                  ],
                  selected: {isChecklist},
                  onSelectionChanged: (s) =>
                      setDialogState(() => isChecklist = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Step Title',
                    hintText: 'e.g. Energy & Environment Check',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: promptCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: isChecklist
                        ? 'Checklist items (one per line)'
                        : 'Reflection question',
                    hintText: isChecklist
                        ? 'Clear physical desk\nFill water bottle\nClose chat tabs'
                        : 'What 1 thing would make today feel peaceful?',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include in Minimal (Express) mode'),
                  value: inMinimal,
                  onChanged: (v) => setDialogState(() => inMinimal = v),
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
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                final newStep = isChecklist
                    ? RitualStepSpec(
                        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                        kind: RitualStepKind.customChecklist,
                        title: title,
                        subtitle: 'Custom checklist verification',
                        includedInMinimal: inMinimal,
                        checklistItems: promptCtrl.text
                            .split('\n')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList(),
                      )
                    : RitualStepSpec(
                        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                        kind: RitualStepKind.customReflectionPrompt,
                        title: title,
                        subtitle: promptCtrl.text.trim(),
                        includedInMinimal: inMinimal,
                        promptQuestion: promptCtrl.text.trim(),
                        markdownHeading: '## $title',
                      );
                final updatedSteps = [...config.customSteps, newStep];
                await _saveConfig(
                  config.copyWith(
                    executionMode: CadenceExecutionMode.customSteps,
                    customSteps: updatedSteps,
                  ),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Add Step'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workspace = ref.watch(workspaceStateProvider);
    final config = workspace.configForRitual(_selectedRitual);
    final presets = PlanningPresetCatalog.presetsFor(_selectedRitual);

    return AlertDialog(
      title: const Text('Planning & Review Process Studio'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 620),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Progressive Guidance & Learning Stage Card
              Card(
                margin: EdgeInsets.zero,
                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Progressive Coaching & In-App Guidance',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          workspace.guidanceEnabled
                              ? 'Introduces rituals step-by-step (${workspace.learningStage.title}) with coach tips that auto-fade after 3 runs.'
                              : 'Guidance disabled — all horizons unlocked with zero coaching prompts.',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: workspace.guidanceEnabled,
                        onChanged: (enabled) async {
                          await ref
                              .read(workspaceStateProvider.notifier)
                              .setGuidanceEnabled(enabled);
                          await ref
                              .read(vaultMutationProvider)
                              .syncPortableProcessConfigToVault();
                        },
                      ),
                      if (workspace.guidanceEnabled) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final stage in LearningStage.values)
                              ChoiceChip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  'Stage ${stage.indexOrder}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: workspace.learningStage == stage,
                                onSelected: (_) {
                                  ref
                                      .read(workspaceStateProvider.notifier)
                                      .setLearningStage(stage);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          workspace.learningStage.summary,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Select Ritual to Configure
              Text(
                '1. Select Cadence Ritual:',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in RitualKind.values)
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        r.shortLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _selectedRitual == r,
                      onSelected: (_) => setState(() => _selectedRitual = r),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Three-Layer Execution Mode Selector
              Text(
                '2. Process Mode for ${_selectedRitual.label}:',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final mode in CadenceExecutionMode.values)
                    ChoiceChip(
                      label: Text(
                        mode.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: config.executionMode == mode,
                      onSelected: (selected) {
                        if (selected) {
                          _saveConfig(config.copyWith(executionMode: mode));
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                config.executionMode.description,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),

              // 4. Default Depth (Full vs. Minimal)
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Default Depth Mode:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  SegmentedButton<RitualDepthMode>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(
                        value: RitualDepthMode.full,
                        label: Text('Full', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: RitualDepthMode.minimal,
                        label: Text('⚡ Minimal', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    selected: {config.preferredDepth},
                    onSelectionChanged: (sel) {
                      _saveConfig(config.copyWith(preferredDepth: sel.first));
                    },
                  ),
                ],
              ),
              const Divider(height: 20),

              // Layer 1 UI: Built-in Preset Picker
              if (config.executionMode ==
                  CadenceExecutionMode.guidedPreset) ...[
                Text(
                  'Choose Built-In Process Preset:',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                for (final p in presets)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      selected: config.selectedPresetId == p.id,
                      leading: Icon(
                        config.selectedPresetId == p.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '${p.summary}\nSource: ${p.inspirationSource} (${p.steps.length} steps)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        _saveConfig(
                          config.copyWith(
                            selectedPresetId: p.id,
                            customSteps: p.steps,
                          ),
                        );
                      },
                    ),
                  ),
              ],

              // Layer 2 UI: Step Customizer (Toggle, Reorder, Minimal Flag, Add Custom)
              if (config.executionMode == CadenceExecutionMode.customSteps) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Customize Steps (${config.customSteps.length}):',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        final basePreset = PlanningPresetCatalog.findById(
                              config.selectedPresetId,
                            ) ??
                            PlanningPresetCatalog.defaultPresetFor(
                              _selectedRitual,
                            );
                        _saveConfig(
                          config.copyWith(customSteps: basePreset.steps),
                        );
                      },
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text(
                        'Reset to Preset',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _showAddCustomStepSheet(context, config),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Add Step',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < config.customSteps.length; i++)
                  Builder(
                    builder: (ctx) {
                      final step = config.customSteps[i];
                      final isNarrow = MediaQuery.sizeOf(ctx).width < 480;
                      final minChip = FilterChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text(
                          '⚡ Min',
                          style: TextStyle(fontSize: 10),
                        ),
                        selected: step.includedInMinimal,
                        onSelected: (val) {
                          final updated = List<RitualStepSpec>.from(
                            config.customSteps,
                          );
                          updated[i] = step.copyWith(includedInMinimal: val);
                          _saveConfig(
                            config.copyWith(customSteps: updated),
                          );
                        },
                      );
                      final reorderButtons = <Widget>[
                        if (i > 0)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.arrow_upward,
                              size: 16,
                            ),
                            onPressed: () {
                              final updated = List<RitualStepSpec>.from(
                                config.customSteps,
                              );
                              final item = updated.removeAt(i);
                              updated.insert(i - 1, item);
                              _saveConfig(
                                config.copyWith(customSteps: updated),
                              );
                            },
                          ),
                        if (i < config.customSteps.length - 1)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.arrow_downward,
                              size: 16,
                            ),
                            onPressed: () {
                              final updated = List<RitualStepSpec>.from(
                                config.customSteps,
                              );
                              final item = updated.removeAt(i);
                              updated.insert(i + 1, item);
                              _saveConfig(
                                config.copyWith(customSteps: updated),
                              );
                            },
                          ),
                      ];
                      final titleColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            step.includedInMinimal
                                ? 'Included in Full & ⚡ Minimal'
                                : 'Full Process only',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      );
                      final checkbox = Checkbox(
                        value: step.enabled,
                        onChanged: (val) {
                          if (val == null) return;
                          final updated = List<RitualStepSpec>.from(
                            config.customSteps,
                          );
                          updated[i] = step.copyWith(enabled: val);
                          _saveConfig(
                            config.copyWith(customSteps: updated),
                          );
                        },
                      );
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: isNarrow
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        checkbox,
                                        Expanded(child: titleColumn),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        minChip,
                                        const SizedBox(width: 4),
                                        ...reorderButtons,
                                      ],
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    checkbox,
                                    Expanded(child: titleColumn),
                                    minChip,
                                    ...reorderButtons,
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
              ],

              // Layer 3 UI: Freeform Markdown Info
              if (config.executionMode ==
                  CadenceExecutionMode.freeformMarkdown) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Freeform Markdown Mode Enabled',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Launching ${_selectedRitual.label} will skip the step-by-step wizard and take you straight to the ${_selectedRitual.cadence.label} Markdown log (.citrine/templates/${_selectedRitual.cadence.id}.md).',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
