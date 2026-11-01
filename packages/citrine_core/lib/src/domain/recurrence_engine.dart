import 'package:meta/meta.dart';

import '../parser/nl_date_parser.dart';

/// Frequency family for a [`RecurrenceRule`] (`D-16`).
enum RecurrenceFrequency {
  daily,
  weekdays,
  weekends,
  weekly,
  monthly,
  nthWeekdayOfMonth,
  yearly,
}

/// Parsed representation of a `🔁 <rule>` inline recurrence rule (`D-16`),
/// supporting daily, every N days, weekdays, weekends, weekly (including
/// specific weekday sets like `every Mon, Wed, Fri`), monthly, custom Nth
/// weekday of month (`every 1st Monday`, `every last Friday`), and yearly.
@immutable
class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.weekdays = const {},
    this.dayOfMonth,
    this.nthOccurrenceInMonth,
    required this.rawText,
  });

  final RecurrenceFrequency frequency;

  /// Step interval (`1` for every period, `2` for every 2 days/weeks/months/years).
  final int interval;

  /// ISO weekday numbers (`1 = Monday` .. `7 = Sunday`) when applicable.
  final Set<int> weekdays;

  /// Day of month (`1..31`) for monthly rules when specified.
  final int? dayOfMonth;

  /// `1..4` for 1st..4th weekday of month, or `-1` for `last` weekday of month.
  final int? nthOccurrenceInMonth;

  /// Original human-readable text after `🔁`.
  final String rawText;

  static const Map<String, int> _weekdayTokens = {
    'mon': DateTime.monday,
    'monday': DateTime.monday,
    'tue': DateTime.tuesday,
    'tues': DateTime.tuesday,
    'tuesday': DateTime.tuesday,
    'wed': DateTime.wednesday,
    'wednesday': DateTime.wednesday,
    'thu': DateTime.thursday,
    'thur': DateTime.thursday,
    'thurs': DateTime.thursday,
    'thursday': DateTime.thursday,
    'fri': DateTime.friday,
    'friday': DateTime.friday,
    'sat': DateTime.saturday,
    'saturday': DateTime.saturday,
    'sun': DateTime.sunday,
    'sunday': DateTime.sunday,
  };

  static const List<String> _weekdayShortNames = [
    '',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Parses a free-text recurrence string (from `🔁 ...`) into a structured
  /// [RecurrenceRule] (`D-16`). Returns `null` if [raw] is null or empty.
  static RecurrenceRule? tryParse(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim().replaceFirst(RegExp(r'^🔁\s*'), '').trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();

    // 1. Simple aliases
    if (lower == 'daily' || lower == 'every day' || lower == 'everyday') {
      return RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        rawText: trimmed,
      );
    }
    if (lower == 'every weekday' ||
        lower == 'weekdays' ||
        lower == 'every workday') {
      return RecurrenceRule(
        frequency: RecurrenceFrequency.weekdays,
        weekdays: const {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        },
        rawText: trimmed,
      );
    }
    if (lower == 'every weekend' || lower == 'weekends') {
      return RecurrenceRule(
        frequency: RecurrenceFrequency.weekends,
        weekdays: const {DateTime.saturday, DateTime.sunday},
        rawText: trimmed,
      );
    }
    if (lower == 'weekly' || lower == 'every week') {
      return RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        rawText: trimmed,
      );
    }
    if (lower == 'monthly' || lower == 'every month') {
      return RecurrenceRule(
        frequency: RecurrenceFrequency.monthly,
        rawText: trimmed,
      );
    }
    if (lower == 'yearly' ||
        lower == 'annually' ||
        lower == 'every year') {
      return RecurrenceRule(
        frequency: RecurrenceFrequency.yearly,
        rawText: trimmed,
      );
    }

    // 2. "every N days|weeks|months|years"
    final intervalMatch = RegExp(
      r'^every\s+(\d+)\s+(day|days|week|weeks|month|months|year|years)$',
    ).firstMatch(lower);
    if (intervalMatch != null) {
      final n = int.tryParse(intervalMatch.group(1)!) ?? 1;
      final unit = intervalMatch.group(2)!;
      final safeInterval = n < 1 ? 1 : n;
      if (unit.startsWith('day')) {
        return RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          interval: safeInterval,
          rawText: trimmed,
        );
      }
      if (unit.startsWith('week')) {
        return RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: safeInterval,
          rawText: trimmed,
        );
      }
      if (unit.startsWith('month')) {
        return RecurrenceRule(
          frequency: RecurrenceFrequency.monthly,
          interval: safeInterval,
          rawText: trimmed,
        );
      }
      if (unit.startsWith('year')) {
        return RecurrenceRule(
          frequency: RecurrenceFrequency.yearly,
          interval: safeInterval,
          rawText: trimmed,
        );
      }
    }

    // 3. "every 1st|2nd|3rd|4th|last <weekday>" (e.g. "every 1st Monday")
    final nthMatch = RegExp(
      r'^every\s+(1st|first|2nd|second|3rd|third|4th|fourth|last)\s+([a-z]+)$',
    ).firstMatch(lower);
    if (nthMatch != null) {
      final ordToken = nthMatch.group(1)!;
      final dayToken = nthMatch.group(2)!;
      final weekday = _weekdayTokens[dayToken];
      if (weekday != null) {
        final nth = switch (ordToken) {
          '1st' || 'first' => 1,
          '2nd' || 'second' => 2,
          '3rd' || 'third' => 3,
          '4th' || 'fourth' => 4,
          'last' => -1,
          _ => 1,
        };
        return RecurrenceRule(
          frequency: RecurrenceFrequency.nthWeekdayOfMonth,
          weekdays: {weekday},
          nthOccurrenceInMonth: nth,
          rawText: trimmed,
        );
      }
    }

    // 4. "every <weekday list>" (e.g. "every Monday", "every Mon, Wed, Fri", "every Tue/Thu")
    if (lower.startsWith('every ')) {
      final rest = lower.substring(6).trim();
      final parts = rest
          .split(RegExp(r'[\s,/&]+|and'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final matchedDays = <int>{};
      var allValid = parts.isNotEmpty;
      for (final p in parts) {
        final wd = _weekdayTokens[p];
        if (wd == null) {
          allValid = false;
          break;
        }
        matchedDays.add(wd);
      }
      if (allValid && matchedDays.isNotEmpty) {
        return RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          weekdays: matchedDays,
          rawText: trimmed,
        );
      }
    }

    // 5. Fallback: treat unknown non-empty recurrence text as a weekly/custom
    // rule so user-authored recurrence strings are preserved without error.
    return RecurrenceRule(
      frequency: RecurrenceFrequency.daily,
      rawText: trimmed,
    );
  }

  /// Canonical human-readable string (without the leading `🔁`).
  String toCanonicalText() {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return interval == 1 ? 'every day' : 'every $interval days';
      case RecurrenceFrequency.weekdays:
        return 'every weekday';
      case RecurrenceFrequency.weekends:
        return 'every weekend';
      case RecurrenceFrequency.weekly:
        if (weekdays.isNotEmpty) {
          final sorted = weekdays.toList()..sort();
          final names = sorted.map((d) => _weekdayShortNames[d]).join(', ');
          return interval == 1
              ? 'every $names'
              : 'every $interval weeks on $names';
        }
        return interval == 1 ? 'every week' : 'every $interval weeks';
      case RecurrenceFrequency.monthly:
        return interval == 1 ? 'every month' : 'every $interval months';
      case RecurrenceFrequency.nthWeekdayOfMonth:
        final wd = weekdays.isEmpty ? DateTime.monday : weekdays.first;
        final ord = switch (nthOccurrenceInMonth) {
          1 => '1st',
          2 => '2nd',
          3 => '3rd',
          4 => '4th',
          -1 => 'last',
          _ => '1st',
        };
        return 'every $ord ${_weekdayShortNames[wd]}';
      case RecurrenceFrequency.yearly:
        return interval == 1 ? 'every year' : 'every $interval years';
    }
  }

  /// Returns true if [date] (local calendar date) matches this recurrence rule,
  /// using [anchorDate] (if provided) for multi-day/week/month/year intervals.
  bool matchesDate(DateTime date, {DateTime? anchorDate}) {
    final target = DateTime.utc(date.year, date.month, date.day);
    final anchor = anchorDate != null
        ? DateTime.utc(anchorDate.year, anchorDate.month, anchorDate.day)
        : target;

    switch (frequency) {
      case RecurrenceFrequency.daily:
        if (interval <= 1) return true;
        final diffDays = target.difference(anchor).inDays;
        return diffDays >= 0 && diffDays % interval == 0;

      case RecurrenceFrequency.weekdays:
        return target.weekday >= DateTime.monday &&
            target.weekday <= DateTime.friday;

      case RecurrenceFrequency.weekends:
        return target.weekday == DateTime.saturday ||
            target.weekday == DateTime.sunday;

      case RecurrenceFrequency.weekly:
        final allowedDays =
            weekdays.isNotEmpty ? weekdays : {anchor.weekday};
        if (!allowedDays.contains(target.weekday)) return false;
        if (interval <= 1) return true;
        final anchorMonday =
            anchor.subtract(Duration(days: anchor.weekday - 1));
        final targetMonday =
            target.subtract(Duration(days: target.weekday - 1));
        final diffWeeks = targetMonday.difference(anchorMonday).inDays ~/ 7;
        return diffWeeks >= 0 && diffWeeks % interval == 0;

      case RecurrenceFrequency.monthly:
        final expectedDay = dayOfMonth ?? anchor.day;
        final lastDayOfTargetMonth =
            DateTime.utc(target.year, target.month + 1, 0).day;
        final clampedDay = expectedDay > lastDayOfTargetMonth
            ? lastDayOfTargetMonth
            : expectedDay;
        if (target.day != clampedDay) return false;
        if (interval <= 1) return true;
        final monthsDiff =
            (target.year - anchor.year) * 12 + (target.month - anchor.month);
        return monthsDiff >= 0 && monthsDiff % interval == 0;

      case RecurrenceFrequency.nthWeekdayOfMonth:
        final wd = weekdays.isEmpty ? DateTime.monday : weekdays.first;
        if (target.weekday != wd) return false;
        final nth = nthOccurrenceInMonth ?? 1;
        if (nth > 0) {
          final occurrenceIndex = ((target.day - 1) ~/ 7) + 1;
          return occurrenceIndex == nth;
        } else {
          // Last weekday of month: adding 7 days lands in the next month
          final nextWeek = target.add(const Duration(days: 7));
          return nextWeek.month != target.month;
        }

      case RecurrenceFrequency.yearly:
        final lastDayOfTargetMonth =
            DateTime.utc(target.year, anchor.month + 1, 0).day;
        final expectedDay = anchor.day > lastDayOfTargetMonth
            ? lastDayOfTargetMonth
            : anchor.day;
        if (target.month != anchor.month || target.day != expectedDay) {
          return false;
        }
        final yearsDiff = target.year - anchor.year;
        return yearsDiff >= 0 && yearsDiff % interval == 0;
    }
  }

  /// Computes the next calendar date strictly after [fromDate] that matches
  /// this rule (`D-16`).
  DateTime nextOccurrenceAfter(DateTime fromDate, {DateTime? anchorDate}) {
    final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final effectiveAnchor = anchorDate ?? start;
    // Search up to 8 years forward (covers multi-year and leap-year rules)
    final maxDays = 366 * (interval < 1 ? 1 : interval) + 366;
    for (var offset = 1; offset <= maxDays; offset++) {
      final candidate = DateTime(
        start.year,
        start.month,
        start.day + offset,
      );
      if (matchesDate(candidate, anchorDate: effectiveAnchor)) {
        return candidate;
      }
    }
    return DateTime(start.year, start.month, start.day + 1);
  }

  /// Expands occurrences within `[start, end]` inclusive, capped at [maxCount]
  /// (`D-16`, `E-10`, `design.md` §8 rolling-window scheduling).
  List<DateTime> expandOccurrencesInWindow({
    required DateTime start,
    required DateTime end,
    DateTime? anchorDate,
    int maxCount = 64,
  }) {
    final firstDay = DateTime(start.year, start.month, start.day);
    final lastDay = DateTime(end.year, end.month, end.day);
    if (lastDay.isBefore(firstDay) || maxCount <= 0) return const [];

    final effectiveAnchor = anchorDate ?? firstDay;
    final results = <DateTime>[];
    final totalDays = DateTime.utc(
      lastDay.year,
      lastDay.month,
      lastDay.day,
    ).difference(DateTime.utc(firstDay.year, firstDay.month, firstDay.day)).inDays;
    for (var i = 0; i <= totalDays && results.length < maxCount; i++) {
      final d = DateTime(firstDay.year, firstDay.month, firstDay.day + i);
      if (matchesDate(d, anchorDate: effectiveAnchor)) {
        results.add(d);
      }
    }
    return results;
  }
}

/// Non-punitive status of a single day in a habit's recent history (`D-17`, `P-04`, `A-02`).
enum HabitDayState {
  /// Completed on this date (`●`).
  completed,

  /// Scheduled on this date, not logged (`·` — neutral history, never a failure).
  unloggedScheduled,

  /// Not scheduled on this date (e.g. weekend for a weekday habit — `○` rest day).
  restDay,
}

@immutable
class HabitDayRecord {
  const HabitDayRecord({
    required this.isoDate,
    required this.state,
  });

  final String isoDate;
  final HabitDayState state;
}

/// Non-punitive summary of a habit's completion history (`D-17`, `P-04`, `A-02`).
///
/// Missed days are represented as neutral history (`unloggedScheduled`), never
/// as "broken streaks" or punitive resets.
@immutable
class HabitHistorySummary {
  const HabitHistorySummary({
    required this.totalCompletions,
    required this.completedInWindow,
    required this.scheduledInWindow,
    required this.recentConsecutiveScheduled,
    required this.recentDays,
  });

  /// Total all-time completions logged for this habit.
  final int totalCompletions;

  /// Number of completions within the recent rolling window (e.g. 14 days).
  final int completedInWindow;

  /// Number of scheduled days within the recent rolling window.
  final int scheduledInWindow;

  /// Consecutive scheduled occurrences completed up to today (or yesterday if
  /// today is not yet logged).
  final int recentConsecutiveScheduled;

  /// Chronological day records for the rolling window (oldest to newest).
  final List<HabitDayRecord> recentDays;

  /// Supportive, non-shaming summary copy (`A-02`, `P-04`, `D-17`).
  String get supportiveSummaryText {
    if (totalCompletions == 0) {
      return 'Ready whenever you are — every check-in counts';
    }
    return '$completedInWindow of last $scheduledInWindow scheduled days · $totalCompletions total logged';
  }
}

/// Domain helper for evaluating non-punitive habit history (`D-17`).
class HabitTrackerEngine {
  const HabitTrackerEngine._();

  /// Summarizes completion history for a habit over [windowDays] ending at
  /// [referenceDate] (`D-17`, `P-04`, `A-02`).
  static HabitHistorySummary summarize({
    required RecurrenceRule? rule,
    required Iterable<String> completedIsoDates,
    required DateTime referenceDate,
    int windowDays = 14,
  }) {
    final effectiveRule =
        rule ?? const RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          rawText: 'every day',
        );
    final completedSet = completedIsoDates.toSet();
    final endDay = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final startDay = DateTime(
      endDay.year,
      endDay.month,
      endDay.day - (windowDays - 1),
    );

    var completedInWindow = 0;
    var scheduledInWindow = 0;
    final recentDays = <HabitDayRecord>[];

    for (var i = 0; i < windowDays; i++) {
      final day = DateTime(startDay.year, startDay.month, startDay.day + i);
      final iso = NlDateParser.formatIsoDate(day);
      final isDone = completedSet.contains(iso);
      final isScheduled = effectiveRule.matchesDate(day);

      if (isDone) {
        completedInWindow++;
        if (isScheduled) scheduledInWindow++;
        recentDays.add(
          HabitDayRecord(isoDate: iso, state: HabitDayState.completed),
        );
      } else if (isScheduled) {
        scheduledInWindow++;
        recentDays.add(
          HabitDayRecord(
            isoDate: iso,
            state: HabitDayState.unloggedScheduled,
          ),
        );
      } else {
        recentDays.add(
          HabitDayRecord(isoDate: iso, state: HabitDayState.restDay),
        );
      }
    }

    // Compute consecutive scheduled days completed up to today (allowing today
    // to be still in progress without dropping yesterday's run).
    var consecutive = 0;
    for (var offset = 0; offset < 365; offset++) {
      final day = DateTime(endDay.year, endDay.month, endDay.day - offset);
      final iso = NlDateParser.formatIsoDate(day);
      if (completedSet.contains(iso)) {
        consecutive++;
      } else if (effectiveRule.matchesDate(day)) {
        if (offset == 0) {
          // Today isn't over yet — don't penalize an unlogged today!
          continue;
        }
        break;
      }
    }

    return HabitHistorySummary(
      totalCompletions: completedSet.length,
      completedInWindow: completedInWindow,
      scheduledInWindow: scheduledInWindow == 0 ? 1 : scheduledInWindow,
      recentConsecutiveScheduled: consecutive,
      recentDays: recentDays,
    );
  }
}
