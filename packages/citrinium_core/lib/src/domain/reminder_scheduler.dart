import 'package:meta/meta.dart';

import '../index/index_operations.dart';
import '../parser/nl_date_parser.dart';
import 'recurrence_engine.dart';

/// Sentinel lead-time value indicating "Morning of due date at 09:00" (`E-10`).
const int kLeadTimeMorningOfSentinel = -900;

/// Preset and custom reminder lead-time configurations (`E-10`).
@immutable
class ReminderLeadTime {
  const ReminderLeadTime._({
    required this.minutesBefore,
    required this.label,
  });

  /// Fires at the exact due time (`⏰ HH:MM`, or `09:00` if date-only).
  static const ReminderLeadTime atDueTime = ReminderLeadTime._(
    minutesBefore: 0,
    label: 'At due time',
  );

  /// Fires 10 minutes before due time (`E-10`).
  static const ReminderLeadTime tenMinutesBefore = ReminderLeadTime._(
    minutesBefore: 10,
    label: '10 minutes before',
  );

  /// Fires 30 minutes before due time (`E-10`).
  static const ReminderLeadTime thirtyMinutesBefore = ReminderLeadTime._(
    minutesBefore: 30,
    label: '30 minutes before',
  );

  /// Fires 1 hour before due time (`E-10`).
  static const ReminderLeadTime oneHourBefore = ReminderLeadTime._(
    minutesBefore: 60,
    label: '1 hour before',
  );

  /// Fires on the morning of the due date at 09:00 (`E-10`).
  static const ReminderLeadTime morningOf = ReminderLeadTime._(
    minutesBefore: kLeadTimeMorningOfSentinel,
    label: 'Morning of (09:00)',
  );

  static const List<ReminderLeadTime> presets = [
    atDueTime,
    tenMinutesBefore,
    thirtyMinutesBefore,
    oneHourBefore,
    morningOf,
  ];

  /// Creates a custom lead-time offset of [minutes] before due time (`E-10`).
  factory ReminderLeadTime.fromStoredMinutes(int minutes) {
    if (minutes == kLeadTimeMorningOfSentinel) return morningOf;
    for (final preset in presets) {
      if (preset.minutesBefore == minutes) return preset;
    }
    final clamped = minutes < 0 ? 0 : minutes;
    return ReminderLeadTime._(
      minutesBefore: clamped,
      label: '$clamped min before',
    );
  }

  final int minutesBefore;
  final String label;

  /// Computes the trigger [DateTime] for a due occurrence at [dueDate] and
  /// optional [dueTime] (`HH:MM`).
  DateTime computeTriggerTime({
    required DateTime dueDate,
    String? dueTime,
  }) {
    var hour = 9;
    var minute = 0;
    if (dueTime != null && dueTime.trim().isNotEmpty) {
      final parts = dueTime.trim().split(':');
      if (parts.length >= 2) {
        hour = int.tryParse(parts[0]) ?? 9;
        minute = int.tryParse(parts[1]) ?? 0;
      }
    }
    final baseDue = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      hour,
      minute,
    );
    if (minutesBefore == kLeadTimeMorningOfSentinel) {
      return DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
    }
    return baseDue.subtract(Duration(minutes: minutesBefore));
  }
}

/// A single derived reminder ready for native OS scheduling (`E-08`, `E-10`,
/// `E-11`, `E-12`, `design.md` §8).
@immutable
class ScheduledReminder {
  const ScheduledReminder({
    required this.notificationId,
    required this.entryUniqueKey,
    required this.relPath,
    required this.lineIndex,
    required this.title,
    required this.scheduledAt,
    required this.dueDateIso,
    this.dueTime,
    required this.leadTime,
    required this.isRecurring,
    this.recurrenceText,
    required this.isSnoozed,
  });

  /// Deterministic 31-bit positive integer ID for `flutter_local_notifications`
  /// / OS notification center.
  final int notificationId;

  /// `relPath:lineIndex` key identifying the source vault entry.
  final String entryUniqueKey;
  final String relPath;
  final int lineIndex;
  final String title;
  final DateTime scheduledAt;
  final String dueDateIso;
  final String? dueTime;
  final ReminderLeadTime leadTime;
  final bool isRecurring;
  final String? recurrenceText;
  final bool isSnoozed;
}

/// Re-derives upcoming reminders from vault entries (`📅`, `⏰`, `🔁`) and
/// operational snooze/lead-time overrides into a forward rolling window capped
/// at [maxPendingNotifications] (64 by default per `design.md` §8 iOS cap).
class ReminderDerivationEngine {
  const ReminderDerivationEngine._();

  /// Maximum pending local notifications scheduled at once (`design.md` §8).
  static const int defaultMaxPendingNotifications = 64;

  /// Default forward rolling window for expanding recurring reminders (`design.md` §8).
  static const Duration defaultRollingWindow = Duration(days: 14);

  static int _deterministicId(String key, int timestampMs) {
    final input = '$key@$timestampMs';
    var hash = 0x811c9dc5;
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  static DateTime? _parseIsoDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    final parts = iso.trim().split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Derives the sorted rolling window of upcoming reminders from [entries]
  /// (`E-08`, `E-10`, `E-12`, `design.md` §8).
  static List<ScheduledReminder> deriveRollingWindow({
    required Iterable<IndexedEntryWithDocument> entries,
    required DateTime now,
    Map<String, int> snoozedUntilMsByTaskKey = const {},
    Map<String, int> reminderLeadMinutesByTaskKey = const {},
    int defaultLeadMinutes = 0,
    Duration rollingWindow = defaultRollingWindow,
    int maxPendingNotifications = defaultMaxPendingNotifications,
  }) {
    final windowEnd = now.add(rollingWindow);
    final candidates = <ScheduledReminder>[];

    for (final item in entries) {
      // Only active tasks, events, or habits generate reminders
      if (item.isCompletedTask ||
          item.entry.taskState == 'dropped' ||
          item.entry.taskState == 'migrated') {
        continue;
      }

      final uniqueKey = item.uniqueKey;
      final leadMinutes =
          reminderLeadMinutesByTaskKey[uniqueKey] ?? defaultLeadMinutes;
      final leadTime = ReminderLeadTime.fromStoredMinutes(leadMinutes);
      final rule = RecurrenceRule.tryParse(item.entry.recurrenceRaw);

      // 1. If actively snoozed into the future (`E-12`), schedule the snoozed
      // reminder directly.
      final snoozeMs = snoozedUntilMsByTaskKey[uniqueKey];
      if (snoozeMs != null) {
        final snoozeTime = DateTime.fromMillisecondsSinceEpoch(snoozeMs);
        if (snoozeTime.isAfter(now) && !snoozeTime.isAfter(windowEnd)) {
          final iso = item.entry.dueDate ?? NlDateParser.formatIsoDate(snoozeTime);
          candidates.add(
            ScheduledReminder(
              notificationId: _deterministicId(uniqueKey, snoozeMs),
              entryUniqueKey: uniqueKey,
              relPath: item.document.relPath,
              lineIndex: item.entry.lineIndex,
              title: item.entry.textContent,
              scheduledAt: snoozeTime,
              dueDateIso: iso,
              dueTime: item.entry.dueTime,
              leadTime: leadTime,
              isRecurring: rule != null,
              recurrenceText: rule?.toCanonicalText(),
              isSnoozed: true,
            ),
          );
          continue;
        }
      }

      final explicitDate = _parseIsoDate(item.entry.dueDate);
      final dueTime = item.entry.dueTime;

      // 2. Recurring task/event/habit (`D-16`, `D-17`, `E-10`): expand inside
      // the rolling window `[today, windowEnd]`.
      if (rule != null && (dueTime != null || explicitDate != null || item.isHabit)) {
        final occurrences = rule.expandOccurrencesInWindow(
          start: now,
          end: windowEnd,
          anchorDate: explicitDate ?? now,
          maxCount: maxPendingNotifications,
        );
        for (final occDate in occurrences) {
          final trigger = leadTime.computeTriggerTime(
            dueDate: occDate,
            dueTime: dueTime,
          );
          if (trigger.isAfter(now) && !trigger.isAfter(windowEnd)) {
            final occIso = NlDateParser.formatIsoDate(occDate);
            candidates.add(
              ScheduledReminder(
                notificationId: _deterministicId(
                  uniqueKey,
                  trigger.millisecondsSinceEpoch,
                ),
                entryUniqueKey: uniqueKey,
                relPath: item.document.relPath,
                lineIndex: item.entry.lineIndex,
                title: item.entry.textContent,
                scheduledAt: trigger,
                dueDateIso: occIso,
                dueTime: dueTime,
                leadTime: leadTime,
                isRecurring: true,
                recurrenceText: rule.toCanonicalText(),
                isSnoozed: false,
              ),
            );
          }
        }
        continue;
      }

      // 3. Single dated/timed task or event (`E-08`, `E-10`)
      if (explicitDate != null || dueTime != null) {
        final targetDate = explicitDate ?? DateTime(now.year, now.month, now.day);
        final trigger = leadTime.computeTriggerTime(
          dueDate: targetDate,
          dueTime: dueTime,
        );
        if (trigger.isAfter(now) && !trigger.isAfter(windowEnd)) {
          candidates.add(
            ScheduledReminder(
              notificationId: _deterministicId(
                uniqueKey,
                trigger.millisecondsSinceEpoch,
              ),
              entryUniqueKey: uniqueKey,
              relPath: item.document.relPath,
              lineIndex: item.entry.lineIndex,
              title: item.entry.textContent,
              scheduledAt: trigger,
              dueDateIso: NlDateParser.formatIsoDate(targetDate),
              dueTime: dueTime,
              leadTime: leadTime,
              isRecurring: false,
              isSnoozed: false,
            ),
          );
        }
      }
    }

    candidates.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    if (candidates.length > maxPendingNotifications) {
      return candidates.sublist(0, maxPendingNotifications);
    }
    return candidates;
  }
}
