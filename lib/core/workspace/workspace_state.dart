import 'dart:convert';

import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vault/vault_path_provider.dart';

/// Destination for the persistent Quick Capture bar (`C-01` sticky toggle).
enum CaptureDestination {
  today('Today'),
  inbox('Inbox');

  const CaptureDestination(this.label);
  final String label;
}

/// A recently visited document or view for the `🕒 Recent` switcher and
/// 2-hour session-continuity resume (`A-08`, `N-04`).
@immutable
class RecentWorkspaceItem {
  const RecentWorkspaceItem({
    required this.relPath,
    required this.title,
    required this.docType,
    required this.visitedAtMs,
  });

  factory RecentWorkspaceItem.fromJson(Map<String, Object?> json) {
    return RecentWorkspaceItem(
      relPath: (json['relPath'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      docType: (json['docType'] as String?) ?? 'note',
      visitedAtMs: (json['visitedAtMs'] as int?) ?? 0,
    );
  }

  final String relPath;
  final String title;
  final String docType;
  final int visitedAtMs;

  String get displayLabel => title.isNotEmpty ? title : relPath;

  Map<String, Object?> toJson() => {
    'relPath': relPath,
    'title': title,
    'docType': docType,
    'visitedAtMs': visitedAtMs,
  };
}

/// Operational installation record for a community or core plugin (PL-02, PL-03, PL-04, PL-08).
@immutable
class PluginInstallRecord {
  const PluginInstallRecord({
    required this.pluginId,
    required this.grantedPermissions,
    required this.isEnabled,
    required this.installedAtMs,
    this.isCore = false,
  });

  factory PluginInstallRecord.fromJson(Map<String, Object?> json) {
    final rawPerms = json['grantedPermissions'];
    final perms = <String>{};
    if (rawPerms is List) {
      for (final p in rawPerms) {
        if (p is String) perms.add(p);
      }
    }
    return PluginInstallRecord(
      pluginId: (json['pluginId'] as String?) ?? '',
      grantedPermissions: perms,
      isEnabled: (json['isEnabled'] as bool?) ?? true,
      installedAtMs: (json['installedAtMs'] as int?) ?? 0,
      isCore: (json['isCore'] as bool?) ?? false,
    );
  }

  final String pluginId;
  final Set<String> grantedPermissions;
  final bool isEnabled;
  final int installedAtMs;
  final bool isCore;

  PluginInstallRecord copyWith({
    Set<String>? grantedPermissions,
    bool? isEnabled,
  }) {
    return PluginInstallRecord(
      pluginId: pluginId,
      grantedPermissions: grantedPermissions ?? this.grantedPermissions,
      isEnabled: isEnabled ?? this.isEnabled,
      installedAtMs: installedAtMs,
      isCore: isCore,
    );
  }

  Map<String, Object?> toJson() => {
    'pluginId': pluginId,
    'grantedPermissions': grantedPermissions.toList(),
    'isEnabled': isEnabled,
    'installedAtMs': installedAtMs,
    'isCore': isCore,
  };
}

/// Structured operational state (`P-11`, `D-15`, `design.md` §3.5):
/// holds Today's Top-3 Focus pins (`E-02`), habit completion history (`D-17`),
/// sticky capture destination (`C-01`), user-configured cadences (`B-12`),
/// 14-day historical task filter (`A-06`), and 2-hour session continuity +
/// Recent views/documents (`A-08`, `N-04`).
///
/// 100% exportable to human-readable Markdown and JSON (`T-02`).
@immutable
class WorkspaceState {
  const WorkspaceState({
    required this.captureDestination,
    required this.enabledCadences,
    required this.topThreePinnedKeys,
    required this.habitCompletionsByDate,
    required this.recentItems,
    required this.lastActiveTimestampMs,
    required this.filterOlderUndatedTasks,
    required this.historicalTaskCutoffDays,
    required this.dismissedHistoricalPrompt,
    required this.focusShelfExpanded,
    this.snoozedUntilMsByTaskKey = const {},
    this.reminderLeadMinutesByTaskKey = const {},
    this.defaultReminderLeadMinutes = 0,
    this.notificationPermissionGranted = false,
    this.onboardingChecklistDismissed = false,
    this.completedOnboardingSteps = const {},
    this.weeklyReviewStep = 0,
    this.lastWeeklyReviewCompletedAt,
    this.weeklyReviewReminderEnabled = false,
    this.weeklyReviewReminderDay = 7,
    this.weeklyReviewReminderTime = '17:00',
    this.installedPlugins = const {},
    this.enabledCorePlugins = const {
      'daily_notes',
      'templates',
      'gtd_clarify',
      'hard_calendar',
    },
    this.guidanceEnabled = true,
    this.learningStage = LearningStage.stage1DailyLaunch,
    this.ruleOfOneFloorDayDates = const {},
    this.morningPlanCompletedDates = const {},
    this.shutdownCompletedDates = const {},
    this.ritualCompletionCounts = const {},
    this.resumableStepByRitual = const {},
    this.lastCompletedIsoByRitual = const {},
    this.ritualConfigs = const {},
    this.cadenceDataViewOrder = const {},
  });

  factory WorkspaceState.initial() {
    return WorkspaceState(
      captureDestination: CaptureDestination.today,
      enabledCadences: {
        for (final c in CadenceKind.values)
          if (c.defaultEnabled) c,
      },
      topThreePinnedKeys: const [],
      habitCompletionsByDate: const {},
      recentItems: const [],
      lastActiveTimestampMs: null,
      filterOlderUndatedTasks: false,
      historicalTaskCutoffDays: 14,
      dismissedHistoricalPrompt: false,
      focusShelfExpanded: true,
      snoozedUntilMsByTaskKey: const {},
      reminderLeadMinutesByTaskKey: const {},
      defaultReminderLeadMinutes: 0,
      notificationPermissionGranted: false,
      onboardingChecklistDismissed: false,
      completedOnboardingSteps: const {},
      weeklyReviewStep: 0,
      lastWeeklyReviewCompletedAt: null,
      weeklyReviewReminderEnabled: false,
      weeklyReviewReminderDay: 7,
      weeklyReviewReminderTime: '17:00',
      installedPlugins: const {},
      enabledCorePlugins: const {
        'daily_notes',
        'templates',
        'gtd_clarify',
        'hard_calendar',
      },
      guidanceEnabled: true,
      learningStage: LearningStage.stage1DailyLaunch,
      ruleOfOneFloorDayDates: const {},
      morningPlanCompletedDates: const {},
      shutdownCompletedDates: const {},
      ritualCompletionCounts: const {},
      resumableStepByRitual: const {},
      lastCompletedIsoByRitual: const {},
      ritualConfigs: {
        for (final r in RitualKind.values) r: RitualProcessConfig.defaultFor(r),
      },
    );
  }

  final CaptureDestination captureDestination;
  final Set<CadenceKind> enabledCadences;

  /// Up to 3 task keys (`relPath:lineIndex`) pinned to Today's Focus Shelf (`E-02`).
  final List<String> topThreePinnedKeys;

  /// Map of `habitKey` -> list of ISO dates (`YYYY-MM-DD`) completed (`D-17`).
  final Map<String, List<String>> habitCompletionsByDate;

  /// Up to 12 most recently opened documents/views (`N-04`, `A-08`).
  final List<RecentWorkspaceItem> recentItems;

  /// Timestamp of last user interaction for the 2-hour session continuity rule (`A-08`).
  final int? lastActiveTimestampMs;

  /// Whether undated open tasks in files older than [historicalTaskCutoffDays]
  /// are filtered out of active Next Actions lists (`A-06`).
  final bool filterOlderUndatedTasks;
  final int historicalTaskCutoffDays;
  final bool dismissedHistoricalPrompt;
  final bool focusShelfExpanded;

  /// Map of `taskKey` -> epoch milliseconds until which a task reminder is snoozed (`E-12`).
  final Map<String, int> snoozedUntilMsByTaskKey;

  /// Map of `taskKey` -> custom reminder lead-time minutes (`E-10`).
  final Map<String, int> reminderLeadMinutesByTaskKey;

  /// Default reminder lead time in minutes across tasks (`E-08`, `E-10`).
  final int defaultReminderLeadMinutes;

  /// Whether native notification permission has been contextually granted on this device (`E-11`).
  final bool notificationPermissionGranted;

  /// Whether the user dismissed the Getting Started progress checklist card (`A-06`).
  final bool onboardingChecklistDismissed;

  /// IDs of completed onboarding steps (e.g. `quick_capture`, `top_three_pin`).
  final Set<String> completedOnboardingSteps;

  /// Resumable progress step (0..3) of the guided Weekly Review ritual (`R-04`).
  final int weeklyReviewStep;

  /// ISO 8601 timestamp of last completed Weekly Review ritual (`R-01`).
  final String? lastWeeklyReviewCompletedAt;

  /// Whether an optional Weekly Review reminder is enabled (`R-05`).
  final bool weeklyReviewReminderEnabled;

  /// Day of week for Weekly Review reminder (1 = Monday ... 7 = Sunday).
  final int weeklyReviewReminderDay;

  /// 24-hour time string `HH:MM` for Weekly Review reminder.
  final String weeklyReviewReminderTime;

  /// Installed community plugins and their granted permissions (PL-02, PL-03, PL-04).
  final Map<String, PluginInstallRecord> installedPlugins;

  /// IDs of enabled built-in core plugins (PL-08).
  final Set<String> enabledCorePlugins;

  /// Whether progressive planning/review guidance is enabled (`A-06`, `P-07`).
  /// Users can disable this in 1 click to use their own process immediately.
  final bool guidanceEnabled;

  /// Current contextual learning stage (`stage_1`..`stage_4`) when
  /// [guidanceEnabled] is true.
  final LearningStage learningStage;

  /// ISO dates (`YYYY-MM-DD`) where the user activated the "Rule of 1 (Floor Day)"
  /// anti-paralysis mode (`A-01`, `P-04`).
  final Set<String> ruleOfOneFloorDayDates;

  /// ISO dates (`YYYY-MM-DD`) where the Daily Morning Plan bookend was completed.
  final Set<String> morningPlanCompletedDates;

  /// ISO dates (`YYYY-MM-DD`) where the Daily Evening Shutdown bookend was completed.
  final Set<String> shutdownCompletedDates;

  /// Total completion count per [RitualKind]; coach tips auto-collapse once a
  /// ritual reaches >= 3 completions.
  final Map<RitualKind, int> ritualCompletionCounts;

  /// Resumable step index per [RitualKind] (`R-04`).
  final Map<RitualKind, int> resumableStepByRitual;

  /// ISO timestamp of last completion per [RitualKind].
  final Map<RitualKind, String> lastCompletedIsoByRitual;

  /// Process configuration per [RitualKind] (preset, custom steps, or freeform
  /// Markdown + preferred depth mode).
  final Map<RitualKind, RitualProcessConfig> ritualConfigs;

  /// Custom ordering of pure UI data view IDs per [CadenceKind.name].
  final Map<String, List<String>> cadenceDataViewOrder;

  /// True if the user was active within the last 2 hours (`A-08`).
  bool isWithinTwoHourWindow(DateTime now) {
    if (lastActiveTimestampMs == null) return false;
    final elapsedMs = now.millisecondsSinceEpoch - lastActiveTimestampMs!;
    return elapsedMs >= 0 && elapsedMs <= const Duration(hours: 2).inMilliseconds;
  }

  RecentWorkspaceItem? get mostRecentItem =>
      recentItems.isEmpty ? null : recentItems.first;

  bool isPinnedToday(String uniqueKey) => topThreePinnedKeys.contains(uniqueKey);

  bool isHabitCompletedOn(String habitKey, String isoDate) {
    final dates = habitCompletionsByDate[habitKey];
    return dates != null && dates.contains(isoDate);
  }

  bool isRuleOfOneOn(String isoDate) =>
      ruleOfOneFloorDayDates.contains(isoDate);

  bool isMorningPlanCompletedOn(String isoDate) =>
      morningPlanCompletedDates.contains(isoDate);

  bool isShutdownCompletedOn(String isoDate) =>
      shutdownCompletedDates.contains(isoDate);

  int completionCountForRitual(RitualKind kind) =>
      ritualCompletionCounts[kind] ?? 0;

  /// Coach tips stay expanded for the first 2 completions of a ritual (when
  /// [guidanceEnabled] is true) and auto-collapse starting on the 3rd run.
  bool shouldAutoExpandCoachTips(RitualKind kind) =>
      guidanceEnabled && completionCountForRitual(kind) < 3;

  int resumableStepForRitual(RitualKind kind) {
    if (kind == RitualKind.weeklyReviewPlan &&
        !resumableStepByRitual.containsKey(kind)) {
      return weeklyReviewStep;
    }
    return resumableStepByRitual[kind] ?? 0;
  }

  RitualProcessConfig configForRitual(RitualKind kind) =>
      ritualConfigs[kind] ?? RitualProcessConfig.defaultFor(kind);

  DateTime? snoozedUntil(String uniqueKey) {
    final ms = snoozedUntilMsByTaskKey[uniqueKey];
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  ReminderLeadTime reminderLeadTimeFor(String uniqueKey) {
    final mins =
        reminderLeadMinutesByTaskKey[uniqueKey] ?? defaultReminderLeadMinutes;
    return ReminderLeadTime.fromStoredMinutes(mins);
  }

  WorkspaceState copyWith({
    CaptureDestination? captureDestination,
    Set<CadenceKind>? enabledCadences,
    List<String>? topThreePinnedKeys,
    Map<String, List<String>>? habitCompletionsByDate,
    List<RecentWorkspaceItem>? recentItems,
    int? lastActiveTimestampMs,
    bool? filterOlderUndatedTasks,
    int? historicalTaskCutoffDays,
    bool? dismissedHistoricalPrompt,
    bool? focusShelfExpanded,
    Map<String, int>? snoozedUntilMsByTaskKey,
    Map<String, int>? reminderLeadMinutesByTaskKey,
    int? defaultReminderLeadMinutes,
    bool? notificationPermissionGranted,
    bool? onboardingChecklistDismissed,
    Set<String>? completedOnboardingSteps,
    int? weeklyReviewStep,
    String? lastWeeklyReviewCompletedAt,
    bool? weeklyReviewReminderEnabled,
    int? weeklyReviewReminderDay,
    String? weeklyReviewReminderTime,
    Map<String, PluginInstallRecord>? installedPlugins,
    Set<String>? enabledCorePlugins,
    bool? guidanceEnabled,
    LearningStage? learningStage,
    Set<String>? ruleOfOneFloorDayDates,
    Set<String>? morningPlanCompletedDates,
    Set<String>? shutdownCompletedDates,
    Map<RitualKind, int>? ritualCompletionCounts,
    Map<RitualKind, int>? resumableStepByRitual,
    Map<RitualKind, String>? lastCompletedIsoByRitual,
    Map<RitualKind, RitualProcessConfig>? ritualConfigs,
    Map<String, List<String>>? cadenceDataViewOrder,
  }) {
    return WorkspaceState(
      captureDestination: captureDestination ?? this.captureDestination,
      enabledCadences: enabledCadences ?? this.enabledCadences,
      topThreePinnedKeys: topThreePinnedKeys ?? this.topThreePinnedKeys,
      habitCompletionsByDate:
          habitCompletionsByDate ?? this.habitCompletionsByDate,
      recentItems: recentItems ?? this.recentItems,
      lastActiveTimestampMs:
          lastActiveTimestampMs ?? this.lastActiveTimestampMs,
      filterOlderUndatedTasks:
          filterOlderUndatedTasks ?? this.filterOlderUndatedTasks,
      historicalTaskCutoffDays:
          historicalTaskCutoffDays ?? this.historicalTaskCutoffDays,
      dismissedHistoricalPrompt:
          dismissedHistoricalPrompt ?? this.dismissedHistoricalPrompt,
      focusShelfExpanded: focusShelfExpanded ?? this.focusShelfExpanded,
      snoozedUntilMsByTaskKey:
          snoozedUntilMsByTaskKey ?? this.snoozedUntilMsByTaskKey,
      reminderLeadMinutesByTaskKey:
          reminderLeadMinutesByTaskKey ?? this.reminderLeadMinutesByTaskKey,
      defaultReminderLeadMinutes:
          defaultReminderLeadMinutes ?? this.defaultReminderLeadMinutes,
      notificationPermissionGranted:
          notificationPermissionGranted ?? this.notificationPermissionGranted,
      onboardingChecklistDismissed:
          onboardingChecklistDismissed ?? this.onboardingChecklistDismissed,
      completedOnboardingSteps:
          completedOnboardingSteps ?? this.completedOnboardingSteps,
      weeklyReviewStep: weeklyReviewStep ?? this.weeklyReviewStep,
      lastWeeklyReviewCompletedAt:
          lastWeeklyReviewCompletedAt ?? this.lastWeeklyReviewCompletedAt,
      weeklyReviewReminderEnabled:
          weeklyReviewReminderEnabled ?? this.weeklyReviewReminderEnabled,
      weeklyReviewReminderDay:
          weeklyReviewReminderDay ?? this.weeklyReviewReminderDay,
      weeklyReviewReminderTime:
          weeklyReviewReminderTime ?? this.weeklyReviewReminderTime,
      installedPlugins: installedPlugins ?? this.installedPlugins,
      enabledCorePlugins: enabledCorePlugins ?? this.enabledCorePlugins,
      guidanceEnabled: guidanceEnabled ?? this.guidanceEnabled,
      learningStage: learningStage ?? this.learningStage,
      ruleOfOneFloorDayDates:
          ruleOfOneFloorDayDates ?? this.ruleOfOneFloorDayDates,
      morningPlanCompletedDates:
          morningPlanCompletedDates ?? this.morningPlanCompletedDates,
      shutdownCompletedDates:
          shutdownCompletedDates ?? this.shutdownCompletedDates,
      ritualCompletionCounts:
          ritualCompletionCounts ?? this.ritualCompletionCounts,
      resumableStepByRitual:
          resumableStepByRitual ?? this.resumableStepByRitual,
      lastCompletedIsoByRitual:
          lastCompletedIsoByRitual ?? this.lastCompletedIsoByRitual,
      ritualConfigs: ritualConfigs ?? this.ritualConfigs,
      cadenceDataViewOrder: cadenceDataViewOrder ?? this.cadenceDataViewOrder,
    );
  }

  /// Portable human-readable Markdown export of all structured operational
  /// data (`P-11`, `D-15`, `T-02`).
  String exportToMarkdown() {
    final buf = StringBuffer();
    buf.writeln('# Citrine Operational Data Export\n');
    buf.writeln('## Enabled Planning & Review Cadences');
    for (final c in CadenceKind.values) {
      final mark = enabledCadences.contains(c) ? 'x' : ' ';
      buf.writeln('- [$mark] **${c.label}** (`${c.docType}`) — ${c.description}');
    }
    buf.writeln('\n## Today\'s Focus Shelf Pins (Top 3)');
    if (topThreePinnedKeys.isEmpty) {
      buf.writeln('- *(None currently pinned)*');
    } else {
      for (final key in topThreePinnedKeys) {
        buf.writeln('- `$key`');
      }
    }
    buf.writeln('\n## Habit Completion History');
    if (habitCompletionsByDate.isEmpty) {
      buf.writeln('- *(No habit completions logged yet)*');
    } else {
      for (final entry in habitCompletionsByDate.entries) {
        buf.writeln('- **${entry.key}**: ${entry.value.join(', ')}');
      }
    }
    buf.writeln('\n## Recent Views & Documents');
    if (recentItems.isEmpty) {
      buf.writeln('- *(None)*');
    } else {
      for (final item in recentItems) {
        buf.writeln('- [[${item.relPath}|${item.displayLabel}]] (${item.docType})');
      }
    }
    buf.writeln('\n## Active Snoozes & Reminder Lead Times');
    if (snoozedUntilMsByTaskKey.isEmpty && reminderLeadMinutesByTaskKey.isEmpty) {
      buf.writeln('- *(Default lead time: ${ReminderLeadTime.fromStoredMinutes(defaultReminderLeadMinutes).label})*');
    } else {
      for (final e in snoozedUntilMsByTaskKey.entries) {
        final dt = DateTime.fromMillisecondsSinceEpoch(e.value).toIso8601String();
        buf.writeln('- **Snoozed `${e.key}`** until `$dt`');
      }
      for (final e in reminderLeadMinutesByTaskKey.entries) {
        final lt = ReminderLeadTime.fromStoredMinutes(e.value);
        buf.writeln('- **Lead time `${e.key}`**: ${lt.label}');
      }
    }
    buf.writeln('\n## Onboarding & Getting Started');
    buf.writeln('- **Checklist Dismissed**: $onboardingChecklistDismissed');
    if (completedOnboardingSteps.isEmpty) {
      buf.writeln('- *(No onboarding checklist steps completed yet)*');
    } else {
      for (final step in completedOnboardingSteps) {
        buf.writeln('- [x] `$step`');
      }
    }
    buf.writeln('\n## Weekly Review Ritual & Reminder (R-01, R-04, R-05)');
    buf.writeln('- **Current Review Step**: ${weeklyReviewStep == 0 ? "Not in progress (Step 0)" : "Resumable at Step $weeklyReviewStep"}');
    buf.writeln('- **Last Completed Review**: ${lastWeeklyReviewCompletedAt ?? "Never"}');
    buf.writeln('- **Weekly Reminder Enabled**: $weeklyReviewReminderEnabled (Day: $weeklyReviewReminderDay, Time: $weeklyReviewReminderTime)');
    buf.writeln('\n## Planning & Review Process & Progressive Guidance');
    buf.writeln('- **Progressive Guidance Enabled**: $guidanceEnabled');
    buf.writeln('- **Current Learning Stage**: ${learningStage.title} (`${learningStage.id}`)');
    if (ruleOfOneFloorDayDates.isNotEmpty) {
      buf.writeln('- **Rule of 1 (Floor Days)**: ${ruleOfOneFloorDayDates.join(", ")}');
    }
    for (final r in RitualKind.values) {
      final cfg = configForRitual(r);
      final count = completionCountForRitual(r);
      final last = lastCompletedIsoByRitual[r] ?? 'Never';
      buf.writeln(
        '- **${r.label}**: Mode=${cfg.executionMode.label}, Preset=`${cfg.selectedPresetId}`, Depth=${cfg.preferredDepth.label}, Completed=${count}x (Last: $last)',
      );
    }
    buf.writeln('\n## Plugins & Extensibility (PL-01, PL-04, PL-08)');
    buf.writeln('### Core Built-In Plugins');
    for (final coreId in const ['daily_notes', 'templates', 'gtd_clarify', 'hard_calendar']) {
      final enabled = enabledCorePlugins.contains(coreId);
      buf.writeln('- [${enabled ? "x" : " "}] `$coreId`');
    }
    buf.writeln('### Installed Community Plugins');
    if (installedPlugins.isEmpty) {
      buf.writeln('- *(No community plugins installed)*');
    } else {
      for (final p in installedPlugins.values) {
        buf.writeln('- **${p.pluginId}** (Enabled: ${p.isEnabled}, Permissions: ${p.grantedPermissions.join(", ")})');
      }
    }
    return buf.toString();
  }

  String exportToJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'captureDestination': captureDestination.name,
      'enabledCadences': [for (final c in enabledCadences) c.id],
      'topThreePinnedKeys': topThreePinnedKeys,
      'habitCompletionsByDate': habitCompletionsByDate,
      'recentItems': [for (final r in recentItems) r.toJson()],
      'lastActiveTimestampMs': lastActiveTimestampMs,
      'filterOlderUndatedTasks': filterOlderUndatedTasks,
      'historicalTaskCutoffDays': historicalTaskCutoffDays,
      'snoozedUntilMsByTaskKey': snoozedUntilMsByTaskKey,
      'reminderLeadMinutesByTaskKey': reminderLeadMinutesByTaskKey,
      'defaultReminderLeadMinutes': defaultReminderLeadMinutes,
      'notificationPermissionGranted': notificationPermissionGranted,
      'onboardingChecklistDismissed': onboardingChecklistDismissed,
      'completedOnboardingSteps': completedOnboardingSteps.toList(),
      'weeklyReviewStep': weeklyReviewStep,
      'lastWeeklyReviewCompletedAt': lastWeeklyReviewCompletedAt,
      'weeklyReviewReminderEnabled': weeklyReviewReminderEnabled,
      'weeklyReviewReminderDay': weeklyReviewReminderDay,
      'weeklyReviewReminderTime': weeklyReviewReminderTime,
      'installedPlugins': {for (final e in installedPlugins.entries) e.key: e.value.toJson()},
      'enabledCorePlugins': enabledCorePlugins.toList(),
      'guidanceEnabled': guidanceEnabled,
      'learningStage': learningStage.id,
      'ruleOfOneFloorDayDates': ruleOfOneFloorDayDates.toList(),
      'morningPlanCompletedDates': morningPlanCompletedDates.toList(),
      'shutdownCompletedDates': shutdownCompletedDates.toList(),
      'ritualCompletionCounts': {
        for (final e in ritualCompletionCounts.entries) e.key.id: e.value,
      },
      'resumableStepByRitual': {
        for (final e in resumableStepByRitual.entries) e.key.id: e.value,
      },
      'lastCompletedIsoByRitual': {
        for (final e in lastCompletedIsoByRitual.entries) e.key.id: e.value,
      },
      'ritualConfigs': {
        for (final r in RitualKind.values) r.id: configForRitual(r).toJson(),
      },
      'cadenceDataViewOrder': cadenceDataViewOrder,
    });
  }
}

const _prefsKeyWorkspace = 'citrine_workspace_state_v1';

class WorkspaceStateNotifier extends Notifier<WorkspaceState> {
  @override
  WorkspaceState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_prefsKeyWorkspace);
    if (raw == null || raw.isEmpty) {
      return WorkspaceState.initial();
    }
    try {
      final map = jsonDecode(raw) as Map<String, Object?>;
      final destStr = map['captureDestination'] as String?;
      final captureDestination = destStr == CaptureDestination.inbox.name
          ? CaptureDestination.inbox
          : CaptureDestination.today;

      final cadenceIds =
          (map['enabledCadences'] as List<Object?>?)?.whereType<String>();
      final enabledCadences = cadenceIds == null
          ? WorkspaceState.initial().enabledCadences
          : {
              for (final id in cadenceIds)
                if (CadenceKind.fromId(id) != null) CadenceKind.fromId(id)!,
            };

      final pins = (map['topThreePinnedKeys'] as List<Object?>?)
              ?.whereType<String>()
              .toList() ??
          const [];

      final habitsRaw = map['habitCompletionsByDate'] as Map<String, Object?>?;
      final habitMap = <String, List<String>>{};
      if (habitsRaw != null) {
        for (final e in habitsRaw.entries) {
          final dates = (e.value as List<Object?>?)
                  ?.whereType<String>()
                  .toList() ??
              const [];
          habitMap[e.key] = dates;
        }
      }

      final recentRaw = map['recentItems'] as List<Object?>?;
      final recentItems = <RecentWorkspaceItem>[];
      if (recentRaw != null) {
        for (final item in recentRaw) {
          if (item is Map<String, Object?>) {
            recentItems.add(RecentWorkspaceItem.fromJson(item));
          }
        }
      }

      final snoozeRaw = map['snoozedUntilMsByTaskKey'] as Map<String, Object?>?;
      final snoozeMap = <String, int>{};
      if (snoozeRaw != null) {
        for (final e in snoozeRaw.entries) {
          if (e.value is int) snoozeMap[e.key] = e.value! as int;
        }
      }

      final leadRaw =
          map['reminderLeadMinutesByTaskKey'] as Map<String, Object?>?;
      final leadMap = <String, int>{};
      if (leadRaw != null) {
        for (final e in leadRaw.entries) {
          if (e.value is int) leadMap[e.key] = e.value! as int;
        }
      }

      final pluginsRaw = map['installedPlugins'] as Map<String, Object?>?;
      final pluginsMap = <String, PluginInstallRecord>{};
      if (pluginsRaw != null) {
        for (final e in pluginsRaw.entries) {
          if (e.value is Map<String, Object?>) {
            pluginsMap[e.key] = PluginInstallRecord.fromJson(
              e.value! as Map<String, Object?>,
            );
          }
        }
      }

      final coreRaw = (map['enabledCorePlugins'] as List<Object?>?)
              ?.whereType<String>()
              .toSet() ??
          const {'daily_notes', 'templates', 'gtd_clarify', 'hard_calendar'};

      final countsRaw = map['ritualCompletionCounts'] as Map<String, Object?>?;
      final countsMap = <RitualKind, int>{};
      if (countsRaw != null) {
        for (final e in countsRaw.entries) {
          final k = RitualKind.fromId(e.key);
          if (k != null && e.value is int) countsMap[k] = e.value! as int;
        }
      }

      final resumableRaw =
          map['resumableStepByRitual'] as Map<String, Object?>?;
      final resumableMap = <RitualKind, int>{};
      if (resumableRaw != null) {
        for (final e in resumableRaw.entries) {
          final k = RitualKind.fromId(e.key);
          if (k != null && e.value is int) resumableMap[k] = e.value! as int;
        }
      }

      final lastIsoRaw =
          map['lastCompletedIsoByRitual'] as Map<String, Object?>?;
      final lastIsoMap = <RitualKind, String>{};
      if (lastIsoRaw != null) {
        for (final e in lastIsoRaw.entries) {
          final k = RitualKind.fromId(e.key);
          if (k != null && e.value is String) {
            lastIsoMap[k] = e.value! as String;
          }
        }
      }

      final configsRaw = map['ritualConfigs'] as Map<String, Object?>?;
      final configsMap = <RitualKind, RitualProcessConfig>{
        for (final r in RitualKind.values) r: RitualProcessConfig.defaultFor(r),
      };
      if (configsRaw != null) {
        for (final e in configsRaw.entries) {
          final k = RitualKind.fromId(e.key);
          if (k != null && e.value is Map<String, Object?>) {
            configsMap[k] = RitualProcessConfig.fromJson(
              k,
              e.value! as Map<String, Object?>,
            );
          }
        }
      }

      return WorkspaceState(
        captureDestination: captureDestination,
        enabledCadences: enabledCadences.isEmpty
            ? {CadenceKind.daily}
            : enabledCadences,
        topThreePinnedKeys: pins,
        habitCompletionsByDate: habitMap,
        recentItems: recentItems,
        lastActiveTimestampMs: map['lastActiveTimestampMs'] as int?,
        filterOlderUndatedTasks:
            (map['filterOlderUndatedTasks'] as bool?) ?? false,
        historicalTaskCutoffDays:
            (map['historicalTaskCutoffDays'] as int?) ?? 14,
        dismissedHistoricalPrompt:
            (map['dismissedHistoricalPrompt'] as bool?) ?? false,
        focusShelfExpanded: (map['focusShelfExpanded'] as bool?) ?? true,
        snoozedUntilMsByTaskKey: snoozeMap,
        reminderLeadMinutesByTaskKey: leadMap,
        defaultReminderLeadMinutes:
            (map['defaultReminderLeadMinutes'] as int?) ?? 0,
        notificationPermissionGranted:
            (map['notificationPermissionGranted'] as bool?) ?? false,
        onboardingChecklistDismissed:
            (map['onboardingChecklistDismissed'] as bool?) ?? false,
        completedOnboardingSteps: (map['completedOnboardingSteps'] as List<Object?>?)
                ?.whereType<String>()
                .toSet() ??
            const {},
        weeklyReviewStep: (map['weeklyReviewStep'] as int?) ?? 0,
        lastWeeklyReviewCompletedAt: map['lastWeeklyReviewCompletedAt'] as String?,
        weeklyReviewReminderEnabled:
            (map['weeklyReviewReminderEnabled'] as bool?) ?? false,
        weeklyReviewReminderDay:
            (map['weeklyReviewReminderDay'] as int?) ?? 7,
        weeklyReviewReminderTime:
            (map['weeklyReviewReminderTime'] as String?) ?? '17:00',
        installedPlugins: pluginsMap,
        enabledCorePlugins: coreRaw,
        guidanceEnabled: (map['guidanceEnabled'] as bool?) ?? true,
        learningStage: LearningStage.fromId(map['learningStage'] as String?),
        ruleOfOneFloorDayDates:
            (map['ruleOfOneFloorDayDates'] as List<Object?>?)
                    ?.whereType<String>()
                    .toSet() ??
                const {},
        morningPlanCompletedDates:
            (map['morningPlanCompletedDates'] as List<Object?>?)
                    ?.whereType<String>()
                    .toSet() ??
                const {},
        shutdownCompletedDates:
            (map['shutdownCompletedDates'] as List<Object?>?)
                    ?.whereType<String>()
                    .toSet() ??
                const {},
        ritualCompletionCounts: countsMap,
        resumableStepByRitual: resumableMap,
        lastCompletedIsoByRitual: lastIsoMap,
        ritualConfigs: configsMap,
        cadenceDataViewOrder: _parseCadenceDataViewOrder(
          map['cadenceDataViewOrder'],
        ),
      );
    } on Object {
      return WorkspaceState.initial();
    }
  }

  Future<void> _persist(WorkspaceState next) async {
    state = next;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      _prefsKeyWorkspace,
      jsonEncode({
        'captureDestination': next.captureDestination.name,
        'enabledCadences': [for (final c in next.enabledCadences) c.id],
        'topThreePinnedKeys': next.topThreePinnedKeys,
        'habitCompletionsByDate': next.habitCompletionsByDate,
        'recentItems': [for (final r in next.recentItems) r.toJson()],
        'lastActiveTimestampMs': next.lastActiveTimestampMs,
        'filterOlderUndatedTasks': next.filterOlderUndatedTasks,
        'historicalTaskCutoffDays': next.historicalTaskCutoffDays,
        'dismissedHistoricalPrompt': next.dismissedHistoricalPrompt,
        'focusShelfExpanded': next.focusShelfExpanded,
        'snoozedUntilMsByTaskKey': next.snoozedUntilMsByTaskKey,
        'reminderLeadMinutesByTaskKey': next.reminderLeadMinutesByTaskKey,
        'defaultReminderLeadMinutes': next.defaultReminderLeadMinutes,
        'notificationPermissionGranted': next.notificationPermissionGranted,
        'onboardingChecklistDismissed': next.onboardingChecklistDismissed,
        'completedOnboardingSteps': next.completedOnboardingSteps.toList(),
        'weeklyReviewStep': next.weeklyReviewStep,
        'lastWeeklyReviewCompletedAt': next.lastWeeklyReviewCompletedAt,
        'weeklyReviewReminderEnabled': next.weeklyReviewReminderEnabled,
        'weeklyReviewReminderDay': next.weeklyReviewReminderDay,
        'weeklyReviewReminderTime': next.weeklyReviewReminderTime,
        'installedPlugins': {for (final e in next.installedPlugins.entries) e.key: e.value.toJson()},
        'enabledCorePlugins': next.enabledCorePlugins.toList(),
        'guidanceEnabled': next.guidanceEnabled,
        'learningStage': next.learningStage.id,
        'ruleOfOneFloorDayDates': next.ruleOfOneFloorDayDates.toList(),
        'morningPlanCompletedDates': next.morningPlanCompletedDates.toList(),
        'shutdownCompletedDates': next.shutdownCompletedDates.toList(),
        'ritualCompletionCounts': {
          for (final e in next.ritualCompletionCounts.entries) e.key.id: e.value,
        },
        'resumableStepByRitual': {
          for (final e in next.resumableStepByRitual.entries) e.key.id: e.value,
        },
        'lastCompletedIsoByRitual': {
          for (final e in next.lastCompletedIsoByRitual.entries)
            e.key.id: e.value,
        },
        'ritualConfigs': {
          for (final r in RitualKind.values)
            r.id: next.configForRitual(r).toJson(),
        },
        'cadenceDataViewOrder': next.cadenceDataViewOrder,
      }),
    );
  }

  static Map<String, List<String>> _parseCadenceDataViewOrder(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, List<String>>{};
    for (final entry in raw.entries) {
      final k = entry.key;
      final v = entry.value;
      if (k is String && v is List) {
        out[k] = v.whereType<String>().toList();
      }
    }
    return out;
  }

  Future<void> reorderCadenceDataView(
    String cadenceName,
    List<String> orderedIds,
  ) async {
    final updated = Map<String, List<String>>.from(state.cadenceDataViewOrder);
    updated[cadenceName] = List<String>.unmodifiable(orderedIds);
    await _persist(state.copyWith(cadenceDataViewOrder: updated));
  }

  Future<void> setCaptureDestination(CaptureDestination destination) async {
    await _persist(state.copyWith(captureDestination: destination));
  }

  Future<void> toggleCadence(CadenceKind cadence, bool enabled) async {
    final updated = Set<CadenceKind>.from(state.enabledCadences);
    if (enabled) {
      updated.add(cadence);
    } else if (updated.length > 1) {
      updated.remove(cadence);
    }
    await _persist(state.copyWith(enabledCadences: updated));
  }

  /// Toggles pinning a task to Today's Top 3 Focus Shelf (`E-02`).
  /// Returns `false` if already at 3 pinned tasks and trying to add a 4th.
  Future<bool> togglePinToday(String uniqueKey, {bool allowOverThree = false}) async {
    final current = List<String>.from(state.topThreePinnedKeys);
    if (current.contains(uniqueKey)) {
      current.remove(uniqueKey);
      await _persist(state.copyWith(topThreePinnedKeys: current));
      return true;
    }
    if (current.length >= 3 && !allowOverThree) {
      return false;
    }
    current.add(uniqueKey);
    final nextSteps = Set<String>.from(state.completedOnboardingSteps)
      ..add('focus_shelf_pin');
    await _persist(
      state.copyWith(
        topThreePinnedKeys: current,
        completedOnboardingSteps: nextSteps,
      ),
    );
    return true;
  }

  /// Records or un-records a habit completion on [isoDate] (`D-17`) without
  /// duplicating rows in the source Markdown file.
  Future<void> toggleHabitCompletion(String habitKey, String isoDate) async {
    final nextMap = <String, List<String>>{
      for (final e in state.habitCompletionsByDate.entries)
        e.key: List<String>.from(e.value),
    };
    final list = nextMap.putIfAbsent(habitKey, () => <String>[]);
    if (list.contains(isoDate)) {
      list.remove(isoDate);
    } else {
      list.add(isoDate);
      list.sort();
    }
    await _persist(state.copyWith(habitCompletionsByDate: nextMap));
  }

  /// Records a visited document/view for the `🕒 Recent` switcher and updates
  /// the 2-hour session-continuity clock (`A-08`, `N-04`).
  Future<void> recordVisitedDocument({
    required String relPath,
    required String title,
    required String docType,
    DateTime? now,
  }) async {
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final item = RecentWorkspaceItem(
      relPath: relPath,
      title: title,
      docType: docType,
      visitedAtMs: ts,
    );
    final updated = <RecentWorkspaceItem>[
      item,
      for (final existing in state.recentItems)
        if (existing.relPath != relPath) existing,
    ].take(12).toList();

    await _persist(
      state.copyWith(
        recentItems: updated,
        lastActiveTimestampMs: ts,
      ),
    );
  }

  Future<void> setHistoricalTaskFilter({
    required bool filterOlderUndatedTasks,
    bool markPromptDismissed = true,
  }) async {
    await _persist(
      state.copyWith(
        filterOlderUndatedTasks: filterOlderUndatedTasks,
        dismissedHistoricalPrompt:
            markPromptDismissed ? true : state.dismissedHistoricalPrompt,
      ),
    );
  }

  Future<void> setFocusShelfExpanded(bool expanded) async {
    await _persist(state.copyWith(focusShelfExpanded: expanded));
  }

  /// Snoozes a task reminder until [snoozeUntil] (`E-12`, `A-03`).
  Future<void> snoozeTask(String uniqueKey, DateTime snoozeUntil) async {
    final nextMap = Map<String, int>.from(state.snoozedUntilMsByTaskKey);
    nextMap[uniqueKey] = snoozeUntil.millisecondsSinceEpoch;
    await _persist(state.copyWith(snoozedUntilMsByTaskKey: nextMap));
  }

  /// Clears any active snooze for [uniqueKey] (`E-12`).
  Future<void> clearSnooze(String uniqueKey) async {
    final nextMap = Map<String, int>.from(state.snoozedUntilMsByTaskKey);
    nextMap.remove(uniqueKey);
    await _persist(state.copyWith(snoozedUntilMsByTaskKey: nextMap));
  }

  /// Sets or clears a per-task reminder lead time in minutes (`E-10`).
  Future<void> setTaskReminderLeadMinutes(
    String uniqueKey,
    int? minutesBefore,
  ) async {
    final nextMap = Map<String, int>.from(state.reminderLeadMinutesByTaskKey);
    if (minutesBefore == null) {
      nextMap.remove(uniqueKey);
    } else {
      nextMap[uniqueKey] = minutesBefore;
    }
    await _persist(state.copyWith(reminderLeadMinutesByTaskKey: nextMap));
  }

  Future<void> setDefaultReminderLeadMinutes(int minutes) async {
    await _persist(state.copyWith(defaultReminderLeadMinutes: minutes));
  }

  Future<void> setNotificationPermissionGranted(bool granted) async {
    await _persist(state.copyWith(notificationPermissionGranted: granted));
  }

  Future<void> dismissOnboardingChecklist({bool dismissed = true}) async {
    await _persist(state.copyWith(onboardingChecklistDismissed: dismissed));
  }

  Future<void> completeOnboardingStep(String stepId) async {
    final next = Set<String>.from(state.completedOnboardingSteps)..add(stepId);
    await _persist(state.copyWith(completedOnboardingSteps: next));
  }

  Future<void> toggleOnboardingStep(String stepId, bool completed) async {
    final next = Set<String>.from(state.completedOnboardingSteps);
    if (completed) {
      next.add(stepId);
    } else {
      next.remove(stepId);
    }
    await _persist(state.copyWith(completedOnboardingSteps: next));
  }

  Future<void> setTopThreePinnedKeys(List<String> keys) async {
    await _persist(state.copyWith(topThreePinnedKeys: List<String>.from(keys)));
  }

  /// Sets the resumable step (0..3) for the Weekly Review ritual (`R-04`).
  Future<void> setWeeklyReviewStep(int step) async {
    await _persist(state.copyWith(weeklyReviewStep: step.clamp(0, 3)));
  }

  /// Resets the Weekly Review step to 0 (`R-04`).
  Future<void> resetWeeklyReview() async {
    await _persist(state.copyWith(weeklyReviewStep: 0));
  }

  /// Records completion of the Weekly Review ritual and resets step to 0 (`R-01`, `R-04`).
  Future<void> completeWeeklyReview(DateTime now) async {
    await _persist(
      state.copyWith(
        weeklyReviewStep: 0,
        lastWeeklyReviewCompletedAt: now.toIso8601String(),
      ),
    );
  }

  /// Configures the optional weekly review recurring reminder (`R-05`).
  Future<void> configureWeeklyReviewReminder({
    required bool enabled,
    int? day,
    String? time,
  }) async {
    await _persist(
      state.copyWith(
        weeklyReviewReminderEnabled: enabled,
        weeklyReviewReminderDay: day ?? state.weeklyReviewReminderDay,
        weeklyReviewReminderTime: time ?? state.weeklyReviewReminderTime,
      ),
    );
  }

  /// Registers a community plugin installation with granted permissions (`PL-02`, `PL-03`).
  Future<void> registerInstalledPlugin(PluginInstallRecord record) async {
    final next = Map<String, PluginInstallRecord>.from(state.installedPlugins);
    next[record.pluginId] = record;
    await _persist(state.copyWith(installedPlugins: next));
  }

  /// Toggles whether a community plugin is enabled without uninstalling it.
  Future<void> togglePlugin(String pluginId, bool enabled) async {
    final existing = state.installedPlugins[pluginId];
    if (existing == null) return;
    final next = Map<String, PluginInstallRecord>.from(state.installedPlugins);
    next[pluginId] = existing.copyWith(isEnabled: enabled);
    await _persist(state.copyWith(installedPlugins: next));
  }

  /// Revokes and uninstalls a community plugin completely (`PL-04`).
  Future<void> revokePlugin(String pluginId) async {
    final next = Map<String, PluginInstallRecord>.from(state.installedPlugins);
    next.remove(pluginId);
    await _persist(state.copyWith(installedPlugins: next));
  }

  /// Toggles a built-in core plugin (`PL-08`).
  Future<void> toggleCorePlugin(String coreId, bool enabled) async {
    final next = Set<String>.from(state.enabledCorePlugins);
    if (enabled) {
      next.add(coreId);
    } else {
      next.remove(coreId);
    }
    await _persist(state.copyWith(enabledCorePlugins: next));
  }

  /// Enables or disables progressive planning/review guidance (`A-06`, `P-07`).
  /// When disabled, unlocks all stages immediately so the user can use their
  /// own process without coaching prompts.
  Future<void> setGuidanceEnabled(bool enabled) async {
    await _persist(
      state.copyWith(
        guidanceEnabled: enabled,
        learningStage:
            enabled ? state.learningStage : LearningStage.stage4MultiHorizon,
      ),
    );
  }

  /// Explicitly sets the user's progressive [LearningStage].
  Future<void> setLearningStage(LearningStage stage) async {
    await _persist(state.copyWith(learningStage: stage));
  }

  /// Toggles "Rule of 1 (Floor Day)" anti-paralysis mode on [isoDate] (`P-04`).
  Future<void> toggleRuleOfOneFloorDay(String isoDate, {bool? enabled}) async {
    final next = Set<String>.from(state.ruleOfOneFloorDayDates);
    final shouldEnable = enabled ?? !next.contains(isoDate);
    if (shouldEnable) {
      next.add(isoDate);
      // If more than 1 task is pinned, keep only the #1 pinned task
      final trimmedPins = state.topThreePinnedKeys.take(1).toList();
      await _persist(
        state.copyWith(
          ruleOfOneFloorDayDates: next,
          topThreePinnedKeys: trimmedPins,
        ),
      );
    } else {
      next.remove(isoDate);
      await _persist(state.copyWith(ruleOfOneFloorDayDates: next));
    }
  }

  /// Saves the resumable step index for [kind] (`R-04`).
  Future<void> setRitualResumableStep(RitualKind kind, int step) async {
    final nextMap = Map<RitualKind, int>.from(state.resumableStepByRitual);
    nextMap[kind] = step < 0 ? 0 : step;
    await _persist(
      state.copyWith(
        resumableStepByRitual: nextMap,
        weeklyReviewStep: kind == RitualKind.weeklyReviewPlan
            ? step.clamp(0, 10)
            : state.weeklyReviewStep,
      ),
    );
  }

  /// Resets the resumable step for [kind] back to 0 (`R-04`).
  Future<void> resetRitualProgress(RitualKind kind) async {
    final nextMap = Map<RitualKind, int>.from(state.resumableStepByRitual);
    nextMap[kind] = 0;
    await _persist(
      state.copyWith(
        resumableStepByRitual: nextMap,
        weeklyReviewStep:
            kind == RitualKind.weeklyReviewPlan ? 0 : state.weeklyReviewStep,
      ),
    );
  }

  /// Records completion of [kind] at [now], increments its completion counter
  /// (so coach tips auto-collapse after 3 completions), resets its resumable
  /// step to 0, and advances [learningStage] progressively if applicable.
  Future<void> recordRitualCompleted(RitualKind kind, DateTime now) async {
    final isoDate = NlDateParser.formatIsoDate(now);
    final isoFull = now.toIso8601String();

    final nextCounts = Map<RitualKind, int>.from(state.ritualCompletionCounts);
    nextCounts[kind] = (nextCounts[kind] ?? 0) + 1;

    final nextResumable =
        Map<RitualKind, int>.from(state.resumableStepByRitual);
    nextResumable[kind] = 0;

    final nextLastIso =
        Map<RitualKind, String>.from(state.lastCompletedIsoByRitual);
    nextLastIso[kind] = isoFull;

    final nextMorning = Set<String>.from(state.morningPlanCompletedDates);
    final nextShutdown = Set<String>.from(state.shutdownCompletedDates);
    if (kind == RitualKind.dailyMorningPlan) {
      nextMorning.add(isoDate);
    } else if (kind == RitualKind.dailyEveningShutdown) {
      nextShutdown.add(isoDate);
    }

    // Progressive learning stage advancement
    var nextStage = state.learningStage;
    if (kind == RitualKind.dailyMorningPlan &&
        nextStage == LearningStage.stage1DailyLaunch) {
      nextStage = LearningStage.stage2EveningShutdown;
    } else if (kind == RitualKind.dailyEveningShutdown &&
        nextStage.indexOrder < LearningStage.stage3WeeklyReview.indexOrder) {
      nextStage = LearningStage.stage3WeeklyReview;
    } else if (kind == RitualKind.weeklyReviewPlan &&
        nextStage.indexOrder < LearningStage.stage4MultiHorizon.indexOrder) {
      nextStage = LearningStage.stage4MultiHorizon;
    }

    await _persist(
      state.copyWith(
        ritualCompletionCounts: nextCounts,
        resumableStepByRitual: nextResumable,
        lastCompletedIsoByRitual: nextLastIso,
        morningPlanCompletedDates: nextMorning,
        shutdownCompletedDates: nextShutdown,
        learningStage: nextStage,
        weeklyReviewStep:
            kind == RitualKind.weeklyReviewPlan ? 0 : state.weeklyReviewStep,
        lastWeeklyReviewCompletedAt: kind == RitualKind.weeklyReviewPlan
            ? isoFull
            : state.lastWeeklyReviewCompletedAt,
      ),
    );
  }

  /// Updates the [RitualProcessConfig] for [kind] (preset selection, custom
  /// steps, depth mode, or freeform Markdown mode).
  Future<void> updateRitualProcessConfig(
    RitualKind kind,
    RitualProcessConfig config,
  ) async {
    final next = <RitualKind, RitualProcessConfig>{
      for (final r in RitualKind.values) r: state.configForRitual(r),
    };
    next[kind] = config;
    await _persist(state.copyWith(ritualConfigs: next));
  }
}

final workspaceStateProvider =
    NotifierProvider<WorkspaceStateNotifier, WorkspaceState>(
  WorkspaceStateNotifier.new,
);
