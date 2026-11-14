import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import '../vault/cadence_files.dart';
import '../vault/path_normalization.dart';
import '../vault/vault_file_io.dart';
import '../vault/vault_watcher.dart';

/// Distinct planning and review ritual types across Citrine's cadences
/// (`B-06`, `B-07`, `R-01`, `R-02`, `Q-02`, `Y-02`).
///
/// Daily uses two lightweight bookends ([dailyMorningPlan] and
/// [dailyEveningShutdown]), while Weekly, Monthly, Quarterly, and Yearly each
/// use a unified "Review & Plan" transition ritual tailored to that horizon.
enum RitualKind {
  dailyMorningPlan(
    id: 'daily_morning_plan',
    label: 'Daily Morning Plan',
    shortLabel: 'Morning Plan',
    cadence: CadenceKind.daily,
    defaultFullMinutes: '5–10 min',
    defaultMinimalMinutes: '1–2 min',
    description:
        'Check today\'s hard landscape, lock Top 1–3 focus tasks, and define your first 2-minute physical step.',
  ),
  dailyEveningShutdown(
    id: 'daily_evening_shutdown',
    label: 'Daily Evening Shutdown',
    shortLabel: 'Evening Shutdown',
    cadence: CadenceKind.daily,
    defaultFullMinutes: '5–10 min',
    defaultMinimalMinutes: '2 min',
    description:
        'Offload loose ends, migrate or close open loops, preview tomorrow, and signal "Shutdown complete."',
  ),
  weeklyReviewPlan(
    id: 'weekly_review_plan',
    label: 'Weekly Review & Plan',
    shortLabel: 'Weekly Review',
    cadence: CadenceKind.weekly,
    defaultFullMinutes: '20–45 min',
    defaultMinimalMinutes: '3–5 min',
    description:
        'Clear your inbox to zero, check upcoming commitments & project next actions, triage stale items, and lock weekly outcomes.',
  ),
  monthlyReviewPlan(
    id: 'monthly_review_plan',
    label: 'Monthly Migration & Plan',
    shortLabel: 'Monthly Migration',
    cadence: CadenceKind.monthly,
    defaultFullMinutes: '15–30 min',
    defaultMinimalMinutes: '3–5 min',
    description:
        'Review habit rhythms, migrate or drop last month\'s open loops, pull forward Future Log items, and set monthly focus.',
  ),
  quarterlyReviewPlan(
    id: 'quarterly_review_plan',
    label: 'Quarterly Review & Plan',
    shortLabel: 'Quarterly Review',
    cadence: CadenceKind.quarterly,
    defaultFullMinutes: '45–60 min',
    defaultMinimalMinutes: '5–10 min',
    description:
        'Score prior quarter goals, synthesize strategic insights & experiments, check Areas of Focus, and set 3–5 quarterly goals.',
  ),
  yearlyReviewPlan(
    id: 'yearly_review_plan',
    label: 'Yearly Review & Vision',
    shortLabel: 'Yearly Review',
    cadence: CadenceKind.yearly,
    defaultFullMinutes: '60–120 min',
    defaultMinimalMinutes: '10–15 min',
    description:
        'Run an 80/20 energy audit (Peak Positive vs. Not-To-Do list), 5-question reflection, focal virtue/theme, and annual goals.',
  );

  const RitualKind({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.cadence,
    required this.defaultFullMinutes,
    required this.defaultMinimalMinutes,
    required this.description,
  });

  final String id;
  final String label;
  final String shortLabel;
  final CadenceKind cadence;
  final String defaultFullMinutes;
  final String defaultMinimalMinutes;
  final String description;

  static RitualKind? fromId(String id) {
    for (final value in RitualKind.values) {
      if (value.id == id) return value;
    }
    return null;
  }

  /// Returns the rituals associated with a given [CadenceKind].
  static List<RitualKind> ritualsForCadence(CadenceKind cadence) {
    switch (cadence) {
      case CadenceKind.daily:
        return const [
          RitualKind.dailyMorningPlan,
          RitualKind.dailyEveningShutdown,
        ];
      case CadenceKind.weekly:
        return const [RitualKind.weeklyReviewPlan];
      case CadenceKind.monthly:
        return const [RitualKind.monthlyReviewPlan];
      case CadenceKind.quarterly:
        return const [RitualKind.quarterlyReviewPlan];
      case CadenceKind.yearly:
        return const [RitualKind.yearlyReviewPlan];
      case CadenceKind.future:
        return const [];
    }
  }

  /// Returns the primary [RitualKind] for a given [CadenceKind], or `null`
  /// for [CadenceKind.future].
  static RitualKind? primaryForCadence(CadenceKind cadence) {
    final list = ritualsForCadence(cadence);
    return list.isEmpty ? null : list.first;
  }
}

/// Depth mode selectable on every planning & review ritual (`A-01`, `P-04`).
enum RitualDepthMode {
  full(
    id: 'full',
    label: 'Full Process',
    description: 'Comprehensive step-by-step planning and review ritual.',
  ),
  minimal(
    id: 'minimal',
    label: 'Minimal (Express)',
    description:
        'Quick 2–3 minute reset for busy or low-energy days ("Rule of 1" friendly).',
  );

  const RitualDepthMode({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  static RitualDepthMode fromId(String? id) {
    if (id == minimal.id) return minimal;
    return full;
  }
}

/// Three-layer customization model allowing users to run Citrine's built-in
/// presets, customize individual steps, or bypass the wizard for freeform
/// Markdown (`P-06`, `B-11`, `X-04`).
enum CadenceExecutionMode {
  guidedPreset(
    id: 'guided_preset',
    label: 'Built-In Preset',
    description:
        'Follow a curated planning & review method (Citrine Hybrid, Ivy Lee, GTD, BuJo, 12-Week Year, Ferriss 80/20, Franklin).',
  ),
  customSteps(
    id: 'custom_steps',
    label: 'Custom Steps',
    description:
        'Toggle, reorder, or add your own custom reflection prompts and checklists.',
  ),
  freeformMarkdown(
    id: 'freeform_markdown',
    label: 'Freeform Markdown',
    description:
        'Skip the step-by-step wizard and work directly in your customizable Markdown template.',
  );

  const CadenceExecutionMode({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  static CadenceExecutionMode fromId(String? id) {
    for (final mode in CadenceExecutionMode.values) {
      if (mode.id == id) return mode;
    }
    return guidedPreset;
  }
}

/// Progressive learning stage that introduces Citrine's planning and review
/// habits as the user uses the app, rather than all at once (`A-06`, `P-07`).
enum LearningStage {
  stage1DailyLaunch(
    indexOrder: 1,
    id: 'stage_1_daily_launch',
    title: 'Stage 1: Capture & Morning Top-3 Launch',
    summary:
        'Start small: capture thoughts freely and pick 1–3 priority tasks for Today\'s Focus Shelf.',
    nextHint:
        'Complete your first Morning Plan or check off a task to unlock Stage 2 (Evening Shutdown & Migration).',
  ),
  stage2EveningShutdown(
    indexOrder: 2,
    id: 'stage_2_evening_shutdown',
    title: 'Stage 2: Evening Shutdown & Daily Migration',
    summary:
        'Close open loops at the end of the day so unfinished tasks stop nagging your working memory.',
    nextHint:
        'Try an Evening Shutdown (or use Citrine for 3 days) to unlock Stage 3 (Weekly Review & Plan).',
  ),
  stage3WeeklyReview(
    indexOrder: 3,
    id: 'stage_3_weekly_review',
    title: 'Stage 3: The Weekly System Trust Reset',
    summary:
        'Once a week, clear your inbox, check projects for next actions, and pick 1–3 weekly outcomes.',
    nextHint:
        'Complete a Weekly Review to unlock Stage 4 (Monthly, Quarterly & Yearly Horizons).',
  ),
  stage4MultiHorizon(
    indexOrder: 4,
    id: 'stage_4_multi_horizon',
    title: 'Stage 4: Multi-Horizon Mastery (M / Q / Y)',
    summary:
        'Connect daily and weekly action to Monthly Migration, Quarterly 12-Week sprints, and Yearly 80/20 reviews.',
    nextHint:
        'All horizons unlocked! Coach tips automatically collapse once you\'ve completed a ritual 3 times.',
  );

  const LearningStage({
    required this.indexOrder,
    required this.id,
    required this.title,
    required this.summary,
    required this.nextHint,
  });

  final int indexOrder;
  final String id;
  final String title;
  final String summary;
  final String nextHint;

  static LearningStage fromId(String? id) {
    for (final stage in LearningStage.values) {
      if (stage.id == id) return stage;
    }
    return stage1DailyLaunch;
  }
}

/// Interactive or user-authored step types available inside a planning/review
/// ritual.
enum RitualStepKind {
  hardLandscapeCheck(
    id: 'hard_landscape_check',
    defaultTitle: 'Check Hard Landscape & Capacity',
  ),
  carryoverMigration(
    id: 'carryover_migration',
    defaultTitle: 'Migrate or Triage Open Loops',
  ),
  topFocusSelection(
    id: 'top_focus_selection',
    defaultTitle: 'Select Vital Focus Priorities',
  ),
  microFirstStep(
    id: 'micro_first_step',
    defaultTitle: 'Define 2-Minute Micro-First-Step (If-Then)',
  ),
  brainDumpLooseEnds(
    id: 'brain_dump_loose_ends',
    defaultTitle: 'Capture Loose Ends & Daily Wins',
  ),
  tomorrowPreview(
    id: 'tomorrow_preview',
    defaultTitle: 'Preview Tomorrow & Pre-Pin Priorities',
  ),
  shutdownComplete(
    id: 'shutdown_complete',
    defaultTitle: 'Signal "Shutdown Complete"',
  ),
  celebrateAndMindSweep(
    id: 'celebrate_and_mind_sweep',
    defaultTitle: 'Celebrate Shipped & Clear Inbox to Zero',
  ),
  calendarAndWaitingCheck(
    id: 'calendar_and_waiting_check',
    defaultTitle: 'Check Calendar Window & Waiting For',
  ),
  zombieProjectsCheck(
    id: 'zombie_projects_check',
    defaultTitle: 'Project Health & Next-Action Check',
  ),
  staleAndSomedayTriage(
    id: 'stale_and_someday_triage',
    defaultTitle: 'Compassionate Stale & Someday/Maybe Triage',
  ),
  futureLogPullForward(
    id: 'future_log_pull_forward',
    defaultTitle: 'Pull Forward from Future Log',
  ),
  habitRhythmReview(
    id: 'habit_rhythm_review',
    defaultTitle: 'Habit Rhythm & Focal Virtue Check-In',
  ),
  quarterGoalScoring(
    id: 'quarter_goal_scoring',
    defaultTitle: 'Score Prior Cycle Goals & Debug Blockers',
  ),
  thinkWeekSynthesis(
    id: 'think_week_synthesis',
    defaultTitle: 'Deep-Thinking Synthesis & Experiments',
  ),
  eightyTwentyEnergyAudit(
    id: 'eighty_twenty_energy_audit',
    defaultTitle: '80/20 Energy Audit (+ Peak vs. - Not-To-Do List)',
  ),
  fiveQuestionSelfAudit(
    id: 'five_question_self_audit',
    defaultTitle: 'Five-Question Self-Audit',
  ),
  focalVirtueAndVision(
    id: 'focal_virtue_and_vision',
    defaultTitle: 'Focal Virtue / Theme & 5/25 Subtraction',
  ),
  periodOutcomesAndBridge(
    id: 'period_outcomes_and_bridge',
    defaultTitle: 'Lock Horizon Outcomes & Next-Cadence Bridge',
  ),
  customReflectionPrompt(
    id: 'custom_reflection_prompt',
    defaultTitle: 'Custom Reflection Prompt',
  ),
  customChecklist(
    id: 'custom_checklist',
    defaultTitle: 'Custom Review Checklist',
  );

  const RitualStepKind({
    required this.id,
    required this.defaultTitle,
  });

  final String id;
  final String defaultTitle;

  static RitualStepKind fromId(String? id) {
    for (final k in RitualStepKind.values) {
      if (k.id == id) return k;
    }
    return customReflectionPrompt;
  }
}

/// Specification for a single step in a planning or review ritual.
@immutable
class RitualStepSpec {
  const RitualStepSpec({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.estimatedMinutes = 2,
    this.enabled = true,
    this.includedInMinimal = false,
    this.coachWhy = '',
    this.coachAvoidTrap = '',
    this.maxFocusItems = 3,
    this.promptQuestion = '',
    this.markdownHeading = '',
    this.checklistItems = const [],
  });

  factory RitualStepSpec.fromJson(Map<String, Object?> json) {
    final rawChecklist = json['checklistItems'];
    final checklist = <String>[];
    if (rawChecklist is List) {
      for (final item in rawChecklist) {
        if (item is String) checklist.add(item);
      }
    }
    final kind = RitualStepKind.fromId(json['kind'] as String?);
    return RitualStepSpec(
      id: (json['id'] as String?) ?? kind.id,
      kind: kind,
      title: (json['title'] as String?) ?? kind.defaultTitle,
      subtitle: (json['subtitle'] as String?) ?? '',
      estimatedMinutes: (json['estimatedMinutes'] as int?) ?? 2,
      enabled: (json['enabled'] as bool?) ?? true,
      includedInMinimal: (json['includedInMinimal'] as bool?) ?? false,
      coachWhy: (json['coachWhy'] as String?) ?? '',
      coachAvoidTrap: (json['coachAvoidTrap'] as String?) ?? '',
      maxFocusItems: (json['maxFocusItems'] as int?) ?? 3,
      promptQuestion: (json['promptQuestion'] as String?) ?? '',
      markdownHeading: (json['markdownHeading'] as String?) ?? '',
      checklistItems: checklist,
    );
  }

  final String id;
  final RitualStepKind kind;
  final String title;
  final String subtitle;
  final int estimatedMinutes;
  final bool enabled;
  final bool includedInMinimal;
  final String coachWhy;
  final String coachAvoidTrap;
  final int maxFocusItems;
  final String promptQuestion;
  final String markdownHeading;
  final List<String> checklistItems;

  RitualStepSpec copyWith({
    String? id,
    RitualStepKind? kind,
    String? title,
    String? subtitle,
    int? estimatedMinutes,
    bool? enabled,
    bool? includedInMinimal,
    String? coachWhy,
    String? coachAvoidTrap,
    int? maxFocusItems,
    String? promptQuestion,
    String? markdownHeading,
    List<String>? checklistItems,
  }) {
    return RitualStepSpec(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      enabled: enabled ?? this.enabled,
      includedInMinimal: includedInMinimal ?? this.includedInMinimal,
      coachWhy: coachWhy ?? this.coachWhy,
      coachAvoidTrap: coachAvoidTrap ?? this.coachAvoidTrap,
      maxFocusItems: maxFocusItems ?? this.maxFocusItems,
      promptQuestion: promptQuestion ?? this.promptQuestion,
      markdownHeading: markdownHeading ?? this.markdownHeading,
      checklistItems: checklistItems ?? this.checklistItems,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.id,
    'title': title,
    'subtitle': subtitle,
    'estimatedMinutes': estimatedMinutes,
    'enabled': enabled,
    'includedInMinimal': includedInMinimal,
    'coachWhy': coachWhy,
    'coachAvoidTrap': coachAvoidTrap,
    'maxFocusItems': maxFocusItems,
    'promptQuestion': promptQuestion,
    'markdownHeading': markdownHeading,
    'checklistItems': checklistItems,
  };
}

/// Named built-in process preset synthesizing practitioner and clinical
/// research (`docs/research/planning_and_review_processes.md`).
@immutable
class ProcessPreset {
  const ProcessPreset({
    required this.id,
    required this.ritualKind,
    required this.name,
    required this.inspirationSource,
    required this.sourceUrl,
    required this.summary,
    required this.steps,
  });

  final String id;
  final RitualKind ritualKind;
  final String name;
  final String inspirationSource;
  final String sourceUrl;
  final String summary;
  final List<RitualStepSpec> steps;
}

/// User-configured settings for a specific [RitualKind], supporting Preset
/// selection, Custom Steps, or Freeform Markdown mode.
@immutable
class RitualProcessConfig {
  const RitualProcessConfig({
    required this.ritualKind,
    required this.executionMode,
    required this.selectedPresetId,
    required this.preferredDepth,
    required this.customSteps,
  });

  factory RitualProcessConfig.defaultFor(RitualKind kind) {
    final defaultPreset = PlanningPresetCatalog.defaultPresetFor(kind);
    return RitualProcessConfig(
      ritualKind: kind,
      executionMode: CadenceExecutionMode.guidedPreset,
      selectedPresetId: defaultPreset.id,
      preferredDepth: RitualDepthMode.full,
      customSteps: defaultPreset.steps,
    );
  }

  factory RitualProcessConfig.fromJson(
    RitualKind kind,
    Map<String, Object?> json,
  ) {
    final defaultPreset = PlanningPresetCatalog.defaultPresetFor(kind);
    final presetId = (json['selectedPresetId'] as String?) ?? defaultPreset.id;
    final preset =
        PlanningPresetCatalog.findById(presetId) ?? defaultPreset;
    final rawSteps = json['customSteps'];
    final parsedSteps = <RitualStepSpec>[];
    if (rawSteps is List) {
      for (final item in rawSteps) {
        if (item is Map<String, Object?>) {
          parsedSteps.add(RitualStepSpec.fromJson(item));
        }
      }
    }
    return RitualProcessConfig(
      ritualKind: kind,
      executionMode: CadenceExecutionMode.fromId(
        json['executionMode'] as String?,
      ),
      selectedPresetId: preset.id,
      preferredDepth: RitualDepthMode.fromId(
        json['preferredDepth'] as String?,
      ),
      customSteps: parsedSteps.isEmpty ? preset.steps : parsedSteps,
    );
  }

  final RitualKind ritualKind;
  final CadenceExecutionMode executionMode;
  final String selectedPresetId;
  final RitualDepthMode preferredDepth;
  final List<RitualStepSpec> customSteps;

  /// Resolves the active steps for the given [depthOverride] (or
  /// [preferredDepth]).
  List<RitualStepSpec> activeSteps({RitualDepthMode? depthOverride}) {
    final effectiveDepth = depthOverride ?? preferredDepth;
    final baseSteps = executionMode == CadenceExecutionMode.customSteps
        ? customSteps
        : (PlanningPresetCatalog.findById(selectedPresetId)?.steps ??
            PlanningPresetCatalog.defaultPresetFor(ritualKind).steps);

    final enabledSteps = baseSteps.where((s) => s.enabled).toList();
    if (enabledSteps.isEmpty) {
      return [baseSteps.first];
    }
    if (effectiveDepth == RitualDepthMode.minimal) {
      final minimalSteps =
          enabledSteps.where((s) => s.includedInMinimal).toList();
      return minimalSteps.isNotEmpty ? minimalSteps : [enabledSteps.first];
    }
    return enabledSteps;
  }

  RitualProcessConfig copyWith({
    CadenceExecutionMode? executionMode,
    String? selectedPresetId,
    RitualDepthMode? preferredDepth,
    List<RitualStepSpec>? customSteps,
  }) {
    return RitualProcessConfig(
      ritualKind: ritualKind,
      executionMode: executionMode ?? this.executionMode,
      selectedPresetId: selectedPresetId ?? this.selectedPresetId,
      preferredDepth: preferredDepth ?? this.preferredDepth,
      customSteps: customSteps ?? this.customSteps,
    );
  }

  Map<String, Object?> toJson() => {
    'ritualKind': ritualKind.id,
    'executionMode': executionMode.id,
    'selectedPresetId': selectedPresetId,
    'preferredDepth': preferredDepth.id,
    'customSteps': [for (final s in customSteps) s.toJson()],
  };
}

/// Catalog of built-in planning and review presets across all 6 rituals,
/// directly grounding the research in `docs/research/planning_and_review_processes.md`
/// and `docs/research/planning_habits_and_review.md`.
class PlanningPresetCatalog {
  const PlanningPresetCatalog._();

  static const String portableConfigRelPath = '.citrine/process_config.json';

  static final List<ProcessPreset> allPresets = [
    // -------------------------------------------------------------------------
    // DAILY MORNING PLAN PRESETS
    // -------------------------------------------------------------------------
    const ProcessPreset(
      id: 'citrine_daily_morning',
      ritualKind: RitualKind.dailyMorningPlan,
      name: 'Citrine Hybrid Morning Launch (Default)',
      inspirationSource: 'ADHD CBT (Solanto/Ramsay) + Tim Ferriss 1–3 + Gollwitzer If-Then',
      sourceUrl: 'https://chadd.org/attention-article/cbt-for-adult-adhd/',
      summary:
          '10-minute anti-overwhelm launch: check today\'s hard calendar, triage any leftover tasks from yesterday, lock 1–3 vital priorities (or a "Rule of 1" floor day), and write a 2-minute physical first step.',
      steps: [
        RitualStepSpec(
          id: 'dm_hard_landscape',
          kind: RitualStepKind.hardLandscapeCheck,
          title: '1. Ground in the Hard Landscape',
          subtitle:
              'Scan fixed-time appointments for today and count your realistic discretionary hours.',
          estimatedMinutes: 2,
          includedInMinimal: false,
          coachWhy:
              'People underestimate task durations by 40–100% (the Planning Fallacy). Seeing your fixed meetings first prevents overbooking your day.',
          coachAvoidTrap:
              'Don\'t treat the calendar as a wish list for flexible tasks, and don\'t assume 100% of open hours can be spent on deep work.',
        ),
        RitualStepSpec(
          id: 'dm_carryover',
          kind: RitualStepKind.carryoverMigration,
          title: '2. Quick Carryover Triage',
          subtitle:
              'Decide what to keep, schedule to Future/Someday, or drop from earlier Daily Logs.',
          estimatedMinutes: 2,
          includedInMinimal: false,
          coachWhy:
              'Intentional migration prevents yesterday\'s unfinished tasks from silently piling up into a wall of guilt.',
          coachAvoidTrap:
              'Don\'t automatically carry everything forward—dropping obsolete tasks is a win for focus.',
        ),
        RitualStepSpec(
          id: 'dm_top_focus',
          kind: RitualStepKind.topFocusSelection,
          title: '3. Select the "Vital Few" (Top 1–3)',
          subtitle:
              'Ask: "If I only completed ONE thing today, what would make me satisfied with my day?" Use "Rule of 1" on low-energy days.',
          estimatedMinutes: 3,
          includedInMinimal: true,
          maxFocusItems: 3,
          coachWhy:
              'Isolating a Top 1–3 Focus Shelf shields working memory from the executive paralysis of an infinite backlog.',
          coachAvoidTrap:
              'Never stare at 15 "must-dos" at once. On tough days, toggle "Rule of 1 (Floor Day)" and pick a single task.',
        ),
        RitualStepSpec(
          id: 'dm_micro_step',
          kind: RitualStepKind.microFirstStep,
          title: '4. Shrink the First Step (If-Then Cue)',
          subtitle:
              'Write a concrete physical verb taking under 2 minutes for Task #1 (e.g. "When I sit down at 9am, I will open budget.xlsx").',
          estimatedMinutes: 2,
          includedInMinimal: false,
          coachWhy:
              'Mary Solanto\'s CBT maxim: "If you are having trouble getting started, the first step is too big." Gollwitzer\'s If-Then plans double initiation rates.',
          coachAvoidTrap:
              'Don\'t leave vague project titles ("deal with taxes") as your #1 action.',
        ),
      ],
    ),
    const ProcessPreset(
      id: 'ivy_lee_morning',
      ritualKind: RitualKind.dailyMorningPlan,
      name: 'Ivy Lee 6-Task Sequential Method',
      inspirationSource: 'Ivy Lee (1918) for Charles M. Schwab',
      sourceUrl: 'https://todoist.com/productivity-methods/ivy-lee',
      summary:
          'Select and rank up to 6 tasks in strict order of true importance. Start with #1 and work sequentially until done.',
      steps: [
        RitualStepSpec(
          id: 'il_morning_carryover',
          kind: RitualStepKind.carryoverMigration,
          title: '1. Carry Over Unfinished Items',
          subtitle: 'Review any unfinished tasks from yesterday (still capped at 6 total).',
          estimatedMinutes: 2,
          includedInMinimal: false,
          coachWhy: 'Keeps a hard ceiling of 6 active items so your daily list never balloons.',
          coachAvoidTrap: 'Don\'t add a 7th task without dropping or deferring one first.',
        ),
        RitualStepSpec(
          id: 'il_morning_rank6',
          kind: RitualStepKind.topFocusSelection,
          title: '2. Rank Up to 6 Tasks by True Importance',
          subtitle: 'Select up to 6 tasks for today and rank #1 as your sole starting focus.',
          estimatedMinutes: 4,
          includedInMinimal: true,
          maxFocusItems: 6,
          coachWhy:
              'Single-tasking in strict priority order eliminates mid-day decision fatigue.',
          coachAvoidTrap:
              'Ignore tasks #2–#6 while working on #1.',
        ),
      ],
    ),
    const ProcessPreset(
      id: 'franklin_morning',
      ritualKind: RitualKind.dailyMorningPlan,
      name: 'Benjamin Franklin Morning Bookend',
      inspirationSource: 'Benjamin Franklin\'s Scheme of Employment',
      sourceUrl: 'https://founders.archives.gov/documents/Franklin/01-01-02-0057',
      summary:
          'Anchor your morning with Franklin\'s Morning Question ("What good shall I do this day?"), review your focal habit/virtue, and lock your daily priorities.',
      steps: [
        RitualStepSpec(
          id: 'bf_morning_question',
          kind: RitualStepKind.customReflectionPrompt,
          title: '1. The Morning Question',
          subtitle: 'Ask yourself: "What good shall I do this day?"',
          estimatedMinutes: 2,
          includedInMinimal: true,
          promptQuestion: 'What good shall I do this day? (Focal intention or virtue)',
          markdownHeading: '## Morning Intention (What Good Shall I Do?)',
          coachWhy:
              'Connects daily execution to personal values and intentionality before reactive tasks take over.',
          coachAvoidTrap:
              'Remember Franklin\'s "Speckled Axe"—aim for sincere direction, not rigid perfection.',
        ),
        RitualStepSpec(
          id: 'bf_morning_hard',
          kind: RitualStepKind.hardLandscapeCheck,
          title: '2. Order Your Day\'s Business',
          subtitle: 'Check today\'s scheduled events and work blocks.',
          estimatedMinutes: 2,
          includedInMinimal: false,
          coachWhy: 'Gives each part of your business its time.',
        ),
        RitualStepSpec(
          id: 'bf_morning_top3',
          kind: RitualStepKind.topFocusSelection,
          title: '3. Choose Today\'s Core Business (Top 1–3)',
          subtitle: 'Pin the 1–3 most meaningful tasks for today.',
          estimatedMinutes: 2,
          includedInMinimal: true,
          maxFocusItems: 3,
        ),
      ],
    ),

    // -------------------------------------------------------------------------
    // DAILY EVENING SHUTDOWN PRESETS
    // -------------------------------------------------------------------------
    const ProcessPreset(
      id: 'citrine_daily_shutdown',
      ritualKind: RitualKind.dailyEveningShutdown,
      name: 'Citrine Hybrid Evening Shutdown (Default)',
      inspirationSource: 'Cal Newport Shutdown + BuJo Reflection + Ivy Lee Evening Lock',
      sourceUrl: 'https://calnewport.com/drastically-reduce-stress-with-a-work-shutdown-ritual/',
      summary:
          'Offload loose thoughts from working memory, migrate or drop today\'s open loops without guilt, preview tomorrow, and flip the "Shutdown Complete" switch.',
      steps: [
        RitualStepSpec(
          id: 'ds_brain_dump',
          kind: RitualStepKind.brainDumpLooseEnds,
          title: '1. Capture Loose Ends & What Went Well',
          subtitle:
              'Dump stray ideas, follow-ups, or notes into your Inbox/Daily Log and note 1 good thing you accomplished.',
          estimatedMinutes: 2,
          includedInMinimal: false,
          coachWhy:
              'Harvard research shows 15 minutes of end-of-day reflection boosts performance by 23%, and writing down loose ends silences the Zeigarnik effect.',
          coachAvoidTrap:
              'Don\'t start doing the tasks you capture—just get them out of your head.',
        ),
        RitualStepSpec(
          id: 'ds_migration',
          kind: RitualStepKind.carryoverMigration,
          title: '2. Close or Migrate Today\'s Open Loops',
          subtitle:
              'For each open task: Mark Done [x], Move to Tomorrow >, Schedule to Future <, or Drop -.',
          estimatedMinutes: 3,
          includedInMinimal: true,
          coachWhy:
              'Leaves zero dangling commitments when you close your workspace.',
          coachAvoidTrap:
              'Dropping a task that no longer matters is healthy triage, not failure.',
        ),
        RitualStepSpec(
          id: 'ds_tomorrow_preview',
          kind: RitualStepKind.tomorrowPreview,
          title: '3. Preview Tomorrow & Pre-Lock Priorities',
          subtitle:
              'Check tomorrow\'s calendar and optionally jot down tomorrow\'s #1 priority (Ivy Lee style).',
          estimatedMinutes: 2,
          includedInMinimal: false,
          coachWhy:
              'Deciding tomorrow\'s priority the night before prevents morning reactivity.',
        ),
        RitualStepSpec(
          id: 'ds_shutdown_complete',
          kind: RitualStepKind.shutdownComplete,
          title: '4. Signal "Shutdown Complete"',
          subtitle:
              'Confirm your workspace is closed and say your shutdown phrase so your brain can rest guilt-free.',
          estimatedMinutes: 1,
          includedInMinimal: true,
          coachWhy:
              'An explicit verbal/written boundary cue halts evening work rumination.',
        ),
      ],
    ),
    const ProcessPreset(
      id: 'newport_shutdown',
      ritualKind: RitualKind.dailyEveningShutdown,
      name: 'Cal Newport Deep Work Shutdown Ritual',
      inspirationSource: 'Cal Newport (Deep Work)',
      sourceUrl: 'https://focusbox.io/articles/daily-shutdown',
      summary:
          'Capture loose ends, review master list & next-day calendar, draft tomorrow\'s plan, and say "Shutdown complete."',
      steps: [
        RitualStepSpec(
          id: 'cn_loose_ends',
          kind: RitualStepKind.brainDumpLooseEnds,
          title: '1. Capture Loose Ends',
          subtitle: 'Move any stray notes, emails, or ideas into your system.',
          estimatedMinutes: 2,
          includedInMinimal: false,
        ),
        RitualStepSpec(
          id: 'cn_tomorrow_check',
          kind: RitualStepKind.tomorrowPreview,
          title: '2. Check Next-Day Calendar & Adjust Plan',
          subtitle: 'Verify upcoming meetings/deadlines and rough in tomorrow\'s plan.',
          estimatedMinutes: 2,
          includedInMinimal: true,
        ),
        RitualStepSpec(
          id: 'cn_shutdown_phrase',
          kind: RitualStepKind.shutdownComplete,
          title: '3. Say the Shutdown Phrase',
          subtitle: 'Close down your workspace and declare "Shutdown complete."',
          estimatedMinutes: 1,
          includedInMinimal: true,
        ),
      ],
    ),
    const ProcessPreset(
      id: 'franklin_evening',
      ritualKind: RitualKind.dailyEveningShutdown,
      name: 'Benjamin Franklin Evening Examination',
      inspirationSource: 'Benjamin Franklin Autobiography',
      sourceUrl: 'https://www.franklinplanner.com/virtues',
      summary:
          'Put things in their places, ask "What good have I done today?", check in on your daily habits/virtues, and migrate open tasks.',
      steps: [
        RitualStepSpec(
          id: 'bf_evening_question',
          kind: RitualStepKind.customReflectionPrompt,
          title: '1. The Evening Question',
          subtitle: 'Reflect: "What good have I done today?"',
          estimatedMinutes: 3,
          includedInMinimal: true,
          promptQuestion: 'What good have I done today, and what did I learn?',
          markdownHeading: '## Evening Reflection (What Good Have I Done?)',
        ),
        RitualStepSpec(
          id: 'bf_evening_habits',
          kind: RitualStepKind.habitRhythmReview,
          title: '2. Daily Habit & Virtue Check-In',
          subtitle: 'Log today\'s habits with non-punitive rhythm dots.',
          estimatedMinutes: 2,
          includedInMinimal: true,
        ),
        RitualStepSpec(
          id: 'bf_evening_migrate',
          kind: RitualStepKind.carryoverMigration,
          title: '3. Put Open Loops in Their Places',
          subtitle: 'Migrate or close remaining tasks from today.',
          estimatedMinutes: 2,
          includedInMinimal: false,
        ),
      ],
    ),

    // -------------------------------------------------------------------------
    // WEEKLY REVIEW & PLAN PRESETS
    // -------------------------------------------------------------------------
    const ProcessPreset(
      id: 'gtd_weekly_review',
      ritualKind: RitualKind.weeklyReviewPlan,
      name: 'GTD Weekly Review (Citrine Default)',
      inspirationSource: 'David Allen\'s Getting Things Done Weekly Review',
      sourceUrl: 'https://gettingthingsdone.com/weekly-review',
      summary:
          'The System Trust Engine: Get Clear (Mind-Sweep + Inbox Zero), Get Current (14d Calendar, Waiting For, Zombie Projects), Get Creative (Stale & Someday), and lock Weekly Outcomes.',
      steps: [
        RitualStepSpec(
          id: 'wk_get_clear',
          kind: RitualStepKind.celebrateAndMindSweep,
          title: '1. Get Clear (Celebrate Wins, Mind-Sweep & Inbox Zero)',
          subtitle:
              'Celebrate what shipped this week, dump lingering ideas from your head, and clarify inbox.md to zero.',
          estimatedMinutes: 10,
          includedInMinimal: true,
          coachWhy:
              'Your brain only trusts your external system when loose capture inboxes are emptied regularly.',
          coachAvoidTrap:
              'Clarifying means deciding what an item is—not doing every 30-minute task right inside the review.',
        ),
        RitualStepSpec(
          id: 'wk_calendar_waiting',
          kind: RitualStepKind.calendarAndWaitingCheck,
          title: '2. Get Current: Calendar & Waiting For',
          subtitle:
              'Review upcoming 14-day hard commitments and follow up on delegated Waiting For items.',
          estimatedMinutes: 8,
          includedInMinimal: false,
          coachWhy:
              'Prevents surprise deadlines and dropped handoffs in the coming two weeks.',
        ),
        RitualStepSpec(
          id: 'wk_zombie_projects',
          kind: RitualStepKind.zombieProjectsCheck,
          title: '3. Get Current: Project Health Check',
          subtitle:
              'Ensure every active project has at least one concrete physical Next Action.',
          estimatedMinutes: 8,
          includedInMinimal: true,
          coachWhy:
              'Projects stall when they lack a physical next step ("Zombie Projects"). Adding one 2-minute action restores momentum.',
        ),
        RitualStepSpec(
          id: 'wk_get_creative',
          kind: RitualStepKind.staleAndSomedayTriage,
          title: '4. Get Creative & Compassionate Stale Triage',
          subtitle:
              'Review items untouched for 14+ days and scan Someday/Maybe for ideas ready to activate.',
          estimatedMinutes: 7,
          includedInMinimal: false,
          coachWhy:
              'Keeps your Next Actions list fresh and trustworthy by parking or dropping stale items without guilt.',
        ),
        RitualStepSpec(
          id: 'wk_outcomes',
          kind: RitualStepKind.periodOutcomesAndBridge,
          title: '5. Lock 1–3 Weekly Focus Outcomes',
          subtitle:
              'Write the 1–3 outcomes that will make this week a success in weekly/YYYY-Www.md.',
          estimatedMinutes: 5,
          includedInMinimal: true,
          coachWhy:
              'Bridges your weekly review directly into Monday morning so you start the week with clarity.',
        ),
      ],
    ),
    const ProcessPreset(
      id: 'adhd_cbt_weekly_reset',
      ritualKind: RitualKind.weeklyReviewPlan,
      name: 'ADHD Compassionate CBT Weekly Reset',
      inspirationSource: 'Safren & Solanto CBT for Adult ADHD',
      sourceUrl: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC2909688/',
      summary:
          'Reframes weekly review as compassionate engineering debugging ("Where did friction happen?") rather than moral judgment.',
      steps: [
        RitualStepSpec(
          id: 'cbt_celebrate',
          kind: RitualStepKind.celebrateAndMindSweep,
          title: '1. Celebrate Shipped & Empty Working Memory',
          subtitle: 'Review completed tasks to counter retrospective time blindness, then clear Inbox.',
          estimatedMinutes: 8,
          includedInMinimal: true,
        ),
        RitualStepSpec(
          id: 'cbt_debug',
          kind: RitualStepKind.customReflectionPrompt,
          title: '2. Compassionate Friction Debugging',
          subtitle:
              'Treat stuck tasks as engineering data: Was the first step too vague? Scheduled at low energy? Cue out of sight?',
          estimatedMinutes: 5,
          includedInMinimal: false,
          promptQuestion:
              'Where did friction happen this week, and what 1 environmental or first-step tweak will help next week?',
          markdownHeading: '## Compassionate Friction Debugging',
        ),
        RitualStepSpec(
          id: 'cbt_projects',
          kind: RitualStepKind.zombieProjectsCheck,
          title: '3. Shrink Stuck Project First Steps',
          subtitle: 'Give any stalled project a 2-minute physical next action.',
          estimatedMinutes: 5,
          includedInMinimal: true,
        ),
        RitualStepSpec(
          id: 'cbt_outcomes',
          kind: RitualStepKind.periodOutcomesAndBridge,
          title: '4. Choose 1–3 Realistic Weekly Intentions',
          subtitle: 'Pick 1–3 priorities with generous buffer space.',
          estimatedMinutes: 4,
          includedInMinimal: true,
        ),
      ],
    ),

    // -------------------------------------------------------------------------
    // MONTHLY REVIEW & PLAN PRESETS
    // -------------------------------------------------------------------------
    const ProcessPreset(
      id: 'bujo_monthly_migration',
      ritualKind: RitualKind.monthlyReviewPlan,
      name: 'Bullet Journal Monthly Migration (Default)',
      inspirationSource: 'Ryder Carroll\'s Bullet Journal Method',
      sourceUrl: 'https://bulletjournal.com/blogs/bulletjournalist/migration',
      summary:
          'Intentional editorial filter: celebrate the month, review habit rhythms, evaluate every open task (keep, schedule, or drop), pull forward Future Log items, and set monthly focus.',
      steps: [
        RitualStepSpec(
          id: 'mo_habits_wins',
          kind: RitualStepKind.habitRhythmReview,
          title: '1. Monthly Wins & Habit Rhythm Check-In',
          subtitle:
              'Review your non-punitive habit consistency and celebrate completed outcomes from the past month.',
          estimatedMinutes: 5,
          includedInMinimal: false,
          coachWhy:
              'Phillippa Lally\'s habit research shows single misses don\'t break automaticity—reflecting on overall rhythm builds sustainable momentum.',
        ),
        RitualStepSpec(
          id: 'mo_open_migration',
          kind: RitualStepKind.carryoverMigration,
          title: '2. Monthly Open-Loop Migration',
          subtitle:
              'Scan open tasks and ask: "Is this still worth my time?" Migrate (>), move to Future/Someday (<), or Drop (-).',
          estimatedMinutes: 10,
          includedInMinimal: true,
          coachWhy:
              'Ryder Carroll\'s deliberate friction: pausing every 30 days to consciously keep or cross out unfinished tasks kills zombie commitments.',
        ),
        RitualStepSpec(
          id: 'mo_future_pull',
          kind: RitualStepKind.futureLogPullForward,
          title: '3. Pull Forward from Future Log (future.md)',
          subtitle:
              'Check future.md for events and tasks slated for this month and pull them into your active Monthly Log.',
          estimatedMinutes: 5,
          includedInMinimal: true,
          coachWhy:
              'Ensures items you parked months ago resurface automatically when their month arrives (P-03).',
        ),
        RitualStepSpec(
          id: 'mo_theme_goals',
          kind: RitualStepKind.periodOutcomesAndBridge,
          title: '4. Set New Monthly Theme & Core Goals',
          subtitle:
              'Define your focus theme and 1–3 key outcomes for monthly/YYYY-MM.md.',
          estimatedMinutes: 5,
          includedInMinimal: true,
        ),
      ],
    ),

    // -------------------------------------------------------------------------
    // QUARTERLY REVIEW & PLAN PRESETS
    // -------------------------------------------------------------------------
    const ProcessPreset(
      id: 'citrine_quarterly_hybrid',
      ritualKind: RitualKind.quarterlyReviewPlan,
      name: 'Citrine Quarterly Hybrid (12-Week Year + Think Week)',
      inspirationSource: 'Brian Moran (12-Week Year) + Bill Gates (Think Week)',
      sourceUrl: 'https://the12weekyear.com/annual-review',
      summary:
          'Combines 90-day goal scoring and blocker analysis with deep strategic synthesis, Horizon 2 Areas of Focus balance, and 3–5 high-impact quarterly goals.',
      steps: [
        RitualStepSpec(
          id: 'qt_score_goals',
          kind: RitualStepKind.quarterGoalScoring,
          title: '1. Score Prior Quarter Goals & Identify Blockers',
          subtitle:
              'Celebrate completed outcomes, score prior 12-week goals, and note root-cause blockers.',
          estimatedMinutes: 15,
          includedInMinimal: true,
          coachWhy:
              '90-day cycles avoid the temporal discounting of annual goals while giving enough runway for deep projects.',
        ),
        RitualStepSpec(
          id: 'qt_think_week',
          kind: RitualStepKind.thinkWeekSynthesis,
          title: '2. Think-Week Synthesis & Experiments',
          subtitle:
              'Step back from daily noise: write key strategic insights and 1–3 concrete experiments to try this quarter.',
          estimatedMinutes: 15,
          includedInMinimal: false,
          coachWhy:
              'Inspired by Bill Gates\'s Think Weeks: deliberate synthesis turns accumulated notes into strategic experiments.',
        ),
        RitualStepSpec(
          id: 'qt_stale_projects',
          kind: RitualStepKind.staleAndSomedayTriage,
          title: '3. Prune Stale Projects & Someday/Maybe',
          subtitle:
              'Retire or park projects that no longer align with your next 12 weeks.',
          estimatedMinutes: 10,
          includedInMinimal: false,
        ),
        RitualStepSpec(
          id: 'qt_goals_bridge',
          kind: RitualStepKind.periodOutcomesAndBridge,
          title: '4. Set 3–5 Quarterly Goals & Week 1 Actions',
          subtitle:
              'Define 3–5 Horizon 3 goals in quarterly/YYYY-QN.md and seed tactical actions for Week 1.',
          estimatedMinutes: 15,
          includedInMinimal: true,
        ),
      ],
    ),
    const ProcessPreset(
      id: 'gates_think_week',
      ritualKind: RitualKind.quarterlyReviewPlan,
      name: 'Bill Gates "Think Week" Deep Synthesis',
      inspirationSource: 'Bill Gates Think Week',
      sourceUrl: 'https://www.gatesnotes.com/Think-Week',
      summary:
          'Disconnect from reactive noise, review collected reading & notes, synthesize long-term insights, and define 2–3 concrete experiments.',
      steps: [
        RitualStepSpec(
          id: 'gtw_synthesis',
          kind: RitualStepKind.thinkWeekSynthesis,
          title: '1. Synthesize Insights & Strategic Questions',
          subtitle: 'Review your reading, collections, and notes; summarize key insights.',
          estimatedMinutes: 30,
          includedInMinimal: true,
        ),
        RitualStepSpec(
          id: 'gtw_experiments',
          kind: RitualStepKind.periodOutcomesAndBridge,
          title: '2. Define 2–3 Concrete Experiments',
          subtitle: 'Turn your insights into 2–3 testable experiments for the coming quarter.',
          estimatedMinutes: 15,
          includedInMinimal: true,
        ),
      ],
    ),

    // -------------------------------------------------------------------------
    // YEARLY REVIEW & PLAN PRESETS
    // -------------------------------------------------------------------------
    const ProcessPreset(
      id: 'citrine_yearly_hybrid',
      ritualKind: RitualKind.yearlyReviewPlan,
      name: 'Citrine Annual Review (Ferriss 80/20 + Franklin Virtue)',
      inspirationSource: 'Tim Ferriss Past Year Review + Ben Franklin Virtue Ledger + Buffett 5/25',
      sourceUrl: 'https://tim.blog/2020/12/31/annual-review',
      summary:
          'A transformative annual reset: run Tim Ferriss\'s 80/20 Peak Positive (+) and Not-To-Do (-) energy audit, answer the 5-Question Self-Audit, choose a focal virtue/theme, and bridge into Q1.',
      steps: [
        RitualStepSpec(
          id: 'yr_80_20_audit',
          kind: RitualStepKind.eightyTwentyEnergyAudit,
          title: '1. 80/20 Energy Audit (+ Peak Positive vs. - Not-To-Do)',
          subtitle:
              'Identify the 20% of activities/people/projects that created 80% of your best outcomes (+), and put the top 20% drains on your strict "Not-To-Do" list (-).',
          estimatedMinutes: 25,
          includedInMinimal: true,
          coachWhy:
              'Tim Ferriss\'s Past Year Review proves subtraction is more powerful than wishful New Year\'s resolutions.',
          coachAvoidTrap:
              'Don\'t skip the "Not-To-Do" list—removing high-friction drains creates the capacity for your new goals.',
        ),
        RitualStepSpec(
          id: 'yr_five_questions',
          kind: RitualStepKind.fiveQuestionSelfAudit,
          title: '2. Five-Question Self-Audit',
          subtitle:
              'Reflect on: Accomplished, Unfinished, Grateful for, Lessons learned, and What to change next year.',
          estimatedMinutes: 25,
          includedInMinimal: false,
          coachWhy:
              'Structured reflection consolidates learning across the entire year.',
        ),
        RitualStepSpec(
          id: 'yr_virtue_vision',
          kind: RitualStepKind.focalVirtueAndVision,
          title: '3. Focal Virtue / Theme & Buffett 5/25 Subtraction',
          subtitle:
              'Choose your focal virtue/theme for the year and isolate your Avoid-At-All-Costs distractions.',
          estimatedMinutes: 15,
          includedInMinimal: true,
          coachWhy:
              'Combines Benjamin Franklin\'s focal virtue commitment with Warren Buffett\'s 5/25 focus protection.',
        ),
        RitualStepSpec(
          id: 'yr_goals_q1_bridge',
          kind: RitualStepKind.periodOutcomesAndBridge,
          title: '4. Top 3–5 Life Goals & Q1 Bridge',
          subtitle:
              'Write your top 3–5 annual goals into yearly/YYYY.md and bridge the first milestone into Q1.',
          estimatedMinutes: 15,
          includedInMinimal: true,
        ),
      ],
    ),
    const ProcessPreset(
      id: 'ferriss_past_year_review',
      ritualKind: RitualKind.yearlyReviewPlan,
      name: 'Tim Ferriss "Past Year Review" & 5-Question Audit',
      inspirationSource: 'Tim Ferriss',
      sourceUrl: 'https://tim.blog/2020/12/31/annual-review',
      summary:
          'Perform a quantitative & calendar 80/20 analysis, answer the Five-Question self-audit, and set 3–5 life-level goals.',
      steps: [
        RitualStepSpec(
          id: 'tf_80_20',
          kind: RitualStepKind.eightyTwentyEnergyAudit,
          title: '1. 80/20 Peak Positive (+) & Not-To-Do (-)',
          subtitle: 'Find the 20% of activities producing 80% of positive and negative results.',
          estimatedMinutes: 30,
          includedInMinimal: true,
        ),
        RitualStepSpec(
          id: 'tf_5q',
          kind: RitualStepKind.fiveQuestionSelfAudit,
          title: '2. The Five-Question Self-Audit',
          subtitle: 'Accomplished, Failed, Grateful, Lessons, and Changes.',
          estimatedMinutes: 30,
          includedInMinimal: true,
        ),
        RitualStepSpec(
          id: 'tf_future_vision',
          kind: RitualStepKind.periodOutcomesAndBridge,
          title: '3. Future-Year Vision & Q1 Launch',
          subtitle: 'Lock 3–5 life-level goals and seed Q1.',
          estimatedMinutes: 20,
          includedInMinimal: true,
        ),
      ],
    ),
    const ProcessPreset(
      id: 'franklin_virtue_ledger',
      ritualKind: RitualKind.yearlyReviewPlan,
      name: 'Benjamin Franklin Yearly Virtue Ledger',
      inspirationSource: 'Benjamin Franklin',
      sourceUrl: 'https://www.franklinplanner.com/virtues',
      summary:
          'Review habit and virtue rhythms across the year, choose one focal virtue for the coming year, and write your commitment statement.',
      steps: [
        RitualStepSpec(
          id: 'bf_yr_habits',
          kind: RitualStepKind.habitRhythmReview,
          title: '1. Review Yearly Habit & Virtue Patterns',
          subtitle: 'Observe patterns of strength and growth without perfectionism.',
          estimatedMinutes: 15,
          includedInMinimal: false,
        ),
        RitualStepSpec(
          id: 'bf_yr_virtue',
          kind: RitualStepKind.focalVirtueAndVision,
          title: '2. Choose Focal Virtue & Commitment Statement',
          subtitle: 'Select your primary virtue/theme and write a brief commitment statement.',
          estimatedMinutes: 15,
          includedInMinimal: true,
        ),
        RitualStepSpec(
          id: 'bf_yr_goals',
          kind: RitualStepKind.periodOutcomesAndBridge,
          title: '3. Core Goals for the Upcoming Year',
          subtitle: 'Set 1–3 aligned goals for the year.',
          estimatedMinutes: 10,
          includedInMinimal: true,
        ),
      ],
    ),
  ];

  /// Returns all built-in presets for [kind].
  static List<ProcessPreset> presetsFor(RitualKind kind) {
    return allPresets.where((p) => p.ritualKind == kind).toList();
  }

  /// Returns the default preset for [kind].
  static ProcessPreset defaultPresetFor(RitualKind kind) {
    return presetsFor(kind).first;
  }

  /// Looks up a preset by its [id].
  static ProcessPreset? findById(String id) {
    for (final preset in allPresets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  /// Saves the user's ritual process configs to `.citrine/process_config.json`
  /// inside the vault so custom processes travel with the vault (`P-11`, `T-02`).
  static Future<void> savePortableConfigToVault({
    required String vaultRootPath,
    required Map<RitualKind, RitualProcessConfig> configs,
    required bool guidanceEnabled,
    required LearningStage learningStage,
    VaultWatcher? watcher,
  }) async {
    final absPath =
        VaultPath(portableConfigRelPath).toAbsolute(vaultRootPath);
    final file = File(absPath);
    await file.parent.create(recursive: true);
    watcher?.suppressSelfWrite(VaultPath(absPath));
    final payload = const JsonEncoder.withIndent('  ').convert({
      'guidanceEnabled': guidanceEnabled,
      'learningStage': learningStage.id,
      'ritualConfigs': {
        for (final entry in configs.entries) entry.key.id: entry.value.toJson(),
      },
    });
    await writeVaultFileAtomic(
      file,
      VaultFileContents(text: '$payload\n', hadBom: false),
    );
  }
}

/// Captured user inputs from a single planning or review ritual session to be
/// formatted as clean Markdown and written directly into the cadence `.md` file
/// (`P-11`, `D-15`).
@immutable
class RitualSessionOutput {
  const RitualSessionOutput({
    required this.ritualKind,
    required this.depthMode,
    required this.presetName,
    required this.completedAtIso,
    this.ruleOfOneFloorDay = false,
    this.microFirstStepText = '',
    this.ifThenCueText = '',
    this.eveningWinsAndLooseEnds = '',
    this.tomorrowTopPriority = '',
    this.shutdownPhrase = '',
    this.quarterGoalScoreSummary = '',
    this.quarterBlockersAndFixes = '',
    this.thinkWeekInsights = '',
    this.thinkWeekExperiments = '',
    this.peakPositiveActivities = '',
    this.notToDoEnergyDrains = '',
    this.fiveQuestionAnswers = const {},
    this.focalVirtueOrTheme = '',
    this.avoidAtAllCostsList = '',
    this.periodOutcomes = const [],
    this.bridgeActionForNextLowerCadence = '',
    this.customPromptResponses = const {},
    this.completedCustomChecklistItems = const [],
  });

  final RitualKind ritualKind;
  final RitualDepthMode depthMode;
  final String presetName;
  final String completedAtIso;

  // Daily Morning
  final bool ruleOfOneFloorDay;
  final String microFirstStepText;
  final String ifThenCueText;

  // Daily Evening
  final String eveningWinsAndLooseEnds;
  final String tomorrowTopPriority;
  final String shutdownPhrase;

  // Quarterly
  final String quarterGoalScoreSummary;
  final String quarterBlockersAndFixes;
  final String thinkWeekInsights;
  final String thinkWeekExperiments;

  // Yearly
  final String peakPositiveActivities;
  final String notToDoEnergyDrains;
  final Map<String, String> fiveQuestionAnswers;
  final String focalVirtueOrTheme;
  final String avoidAtAllCostsList;

  // Shared outcomes & custom steps
  final List<String> periodOutcomes;
  final String bridgeActionForNextLowerCadence;
  final Map<String, String> customPromptResponses; // heading -> response
  final List<String> completedCustomChecklistItems;

  /// Formats all non-empty user-authored plans, priorities, and reflections
  /// into clean, standard Markdown lines ready to be appended to the cadence
  /// `.md` log file (`P-11`).
  List<String> toMarkdownLines() {
    final lines = <String>[];
    final datePart = completedAtIso.length >= 10
        ? completedAtIso.substring(0, 10)
        : completedAtIso;

    lines.add('');
    lines.add(
      '## ${ritualKind.label} ($datePart · ${depthMode.label})',
    );

    if (ruleOfOneFloorDay) {
      lines.add(
        '- – **Floor Day (Rule of 1 Active):** Focused on 1 essential task today without guilt.',
      );
    }

    if (periodOutcomes.isNotEmpty) {
      for (final outcome in periodOutcomes) {
        final trimmed = outcome.trim();
        if (trimmed.isEmpty) continue;
        final hasPrefix = RegExp(r'^[-*+]\s+').hasMatch(trimmed);
        lines.add(hasPrefix ? trimmed : '- [ ] $trimmed');
      }
    }

    if (microFirstStepText.trim().isNotEmpty) {
      lines.add(
        '- [ ] **2m First Step:** ${microFirstStepText.trim()}',
      );
    }
    if (ifThenCueText.trim().isNotEmpty) {
      lines.add(
        '- – **If-Then Cue:** ${ifThenCueText.trim()}',
      );
    }

    if (eveningWinsAndLooseEnds.trim().isNotEmpty) {
      lines.add('### Evening Reflection & Wins');
      for (final raw in eveningWinsAndLooseEnds.trim().split('\n')) {
        if (raw.trim().isNotEmpty) {
          lines.add('- – ${raw.trim()}');
        }
      }
    }

    if (tomorrowTopPriority.trim().isNotEmpty) {
      lines.add(
        '- – **Tomorrow\'s #1 Priority Lock:** ${tomorrowTopPriority.trim()}',
      );
    }

    if (shutdownPhrase.trim().isNotEmpty) {
      lines.add(
        '- – **Shutdown Complete:** *"${shutdownPhrase.trim()}"*',
      );
    }

    if (quarterGoalScoreSummary.trim().isNotEmpty ||
        quarterBlockersAndFixes.trim().isNotEmpty) {
      lines.add('### Prior Cycle Score & Blocker Analysis');
      if (quarterGoalScoreSummary.trim().isNotEmpty) {
        lines.add('- – **Goal Score & Wins:** ${quarterGoalScoreSummary.trim()}');
      }
      if (quarterBlockersAndFixes.trim().isNotEmpty) {
        lines.add('- – **Blockers & Root Causes:** ${quarterBlockersAndFixes.trim()}');
      }
    }

    if (thinkWeekInsights.trim().isNotEmpty ||
        thinkWeekExperiments.trim().isNotEmpty) {
      lines.add('### Deep-Thinking Synthesis & Experiments');
      if (thinkWeekInsights.trim().isNotEmpty) {
        lines.add('- – **Strategic Insights:** ${thinkWeekInsights.trim()}');
      }
      if (thinkWeekExperiments.trim().isNotEmpty) {
        for (final exp in thinkWeekExperiments.trim().split('\n')) {
          if (exp.trim().isNotEmpty) {
            lines.add('- [ ] **Experiment:** ${exp.trim()}');
          }
        }
      }
    }

    if (peakPositiveActivities.trim().isNotEmpty ||
        notToDoEnergyDrains.trim().isNotEmpty) {
      lines.add('### 80/20 Energy Audit (Tim Ferriss Past Year Review)');
      if (peakPositiveActivities.trim().isNotEmpty) {
        lines.add(
          '- – **Peak Positive (+ 20% producing 80% of joy/results):** ${peakPositiveActivities.trim()}',
        );
      }
      if (notToDoEnergyDrains.trim().isNotEmpty) {
        lines.add(
          '- – **Not-To-Do List (- 20% energy drains to eliminate):** ${notToDoEnergyDrains.trim()}',
        );
      }
    }

    final nonEmpty5Q = fiveQuestionAnswers.entries
        .where((e) => e.value.trim().isNotEmpty)
        .toList();
    if (nonEmpty5Q.isNotEmpty) {
      lines.add('### Five-Question Self-Audit');
      for (final entry in nonEmpty5Q) {
        lines.add('- – **${entry.key}:** ${entry.value.trim()}');
      }
    }

    if (focalVirtueOrTheme.trim().isNotEmpty) {
      lines.add(
        '- – **Focal Virtue / Theme:** ${focalVirtueOrTheme.trim()}',
      );
    }

    if (avoidAtAllCostsList.trim().isNotEmpty) {
      lines.add(
        '- – **Buffett 5/25 Avoid-At-All-Costs List:** ${avoidAtAllCostsList.trim()}',
      );
    }

    if (bridgeActionForNextLowerCadence.trim().isNotEmpty) {
      lines.add(
        '- – **Next-Horizon Bridge Action:** ${bridgeActionForNextLowerCadence.trim()}',
      );
    }

    for (final entry in customPromptResponses.entries) {
      final val = entry.value.trim();
      if (val.isEmpty) continue;
      final heading = entry.key.trim().startsWith('#')
          ? entry.key.trim()
          : '### ${entry.key.trim()}';
      lines.add(heading);
      for (final line in val.split('\n')) {
        if (line.trim().isNotEmpty) {
          lines.add('- – ${line.trim()}');
        }
      }
    }

    if (completedCustomChecklistItems.isNotEmpty) {
      lines.add('### Completed Review Checklist');
      for (final item in completedCustomChecklistItems) {
        lines.add('- [x] $item');
      }
    }

    // If only the header was generated, add a brief completion marker so the
    // log records the review cleanly.
    if (lines.length <= 2) {
      lines.add('- – Completed ${ritualKind.label} ($presetName).');
    }

    return lines;
  }
}
