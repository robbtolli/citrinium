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
      }),
    );
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
}

final workspaceStateProvider =
    NotifierProvider<WorkspaceStateNotifier, WorkspaceState>(
  WorkspaceStateNotifier.new,
);
