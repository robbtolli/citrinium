import 'dart:convert';

import 'package:citrinium_core/citrinium_core.dart';
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
    );
  }

  /// Portable human-readable Markdown export of all structured operational
  /// data (`P-11`, `D-15`, `T-02`).
  String exportToMarkdown() {
    final buf = StringBuffer();
    buf.writeln('# Citrinium Operational Data Export\n');
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
    });
  }
}

const _prefsKeyWorkspace = 'citrinium_workspace_state_v1';

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
    await _persist(state.copyWith(topThreePinnedKeys: current));
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
}

final workspaceStateProvider =
    NotifierProvider<WorkspaceStateNotifier, WorkspaceState>(
  WorkspaceStateNotifier.new,
);
