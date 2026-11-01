import 'package:citrine_core/citrine_core.dart';
import 'package:test/test.dart';

void main() {
  group('RecurrenceRule & HabitTrackerEngine (M7 — D-16, D-17)', () {
    test('parses and evaluates daily, weekday, custom interval, and Nth weekday rules (D-16)', () {
      final weekdayRule = RecurrenceRule.tryParse('every weekday')!;
      expect(weekdayRule.frequency, RecurrenceFrequency.weekdays);
      // 2026-10-30 is Friday -> next occurrence is Monday 2026-11-02
      final fri = DateTime(2026, 10, 30);
      expect(weekdayRule.matchesDate(fri), isTrue);
      expect(weekdayRule.matchesDate(DateTime(2026, 10, 31)), isFalse);
      expect(weekdayRule.nextOccurrenceAfter(fri), DateTime(2026, 11, 2));

      final every3Days = RecurrenceRule.tryParse('every 3 days')!;
      expect(every3Days.frequency, RecurrenceFrequency.daily);
      expect(every3Days.interval, 3);
      final anchor = DateTime(2026, 10, 1);
      expect(every3Days.nextOccurrenceAfter(anchor, anchorDate: anchor), DateTime(2026, 10, 4));

      final firstMonday = RecurrenceRule.tryParse('every 1st Monday')!;
      expect(firstMonday.frequency, RecurrenceFrequency.nthWeekdayOfMonth);
      // Nov 2, 2026 is the 1st Monday of November 2026
      expect(firstMonday.matchesDate(DateTime(2026, 11, 2)), isTrue);
      expect(firstMonday.matchesDate(DateTime(2026, 11, 9)), isFalse);
      expect(firstMonday.nextOccurrenceAfter(DateTime(2026, 10, 6)), DateTime(2026, 11, 2));

      final lastFriday = RecurrenceRule.tryParse('every last Friday')!;
      // Oct 30, 2026 is the last Friday of October 2026
      expect(lastFriday.matchesDate(DateTime(2026, 10, 30)), isTrue);
      expect(lastFriday.matchesDate(DateTime(2026, 10, 23)), isFalse);

      final customDays = RecurrenceRule.tryParse('every Mon, Wed, Fri')!;
      expect(customDays.weekdays, {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      });
    });

    test('summarizes habit history non-punitively with rest days and neutral unlogged days (D-17, P-04)', () {
      final weekdayRule = RecurrenceRule.tryParse('every weekday');
      // Reference: Monday 2026-11-02; completed Friday 2026-10-30 and Thursday 2026-10-29
      final summary = HabitTrackerEngine.summarize(
        rule: weekdayRule,
        completedIsoDates: const ['2026-10-29', '2026-10-30'],
        referenceDate: DateTime(2026, 11, 2),
        windowDays: 7,
      );

      expect(summary.totalCompletions, 2);
      // Even though today (Monday) isn't logged yet and Sat/Sun were rest days,
      // recentConsecutiveScheduled preserves Thursday+Friday (2 days)!
      expect(summary.recentConsecutiveScheduled, 2);
      expect(
        summary.recentDays.any((d) => d.state == HabitDayState.restDay),
        isTrue,
      );
      expect(
        summary.supportiveSummaryText,
        contains('2 total logged'),
      );
    });
  });

  group('ReminderDerivationEngine rolling-window scheduler (M8 — E-08, E-10, E-12)', () {
    Document fakeDoc(String relPath) => Document(
      id: 1,
      relPath: relPath,
      title: 'Test',
      docType: 'dailyLog',
      frontmatterJson: '{}',
      sha256: 'abc',
      mtimeMs: 1000,
      sizeBytes: 100,
      indexedAtMs: 1000,
    );

    test('derives recurring and lead-time-adjusted reminders capped at 64 items', () {
      final now = DateTime(2026, 10, 29, 8, 0);
      final habitEntry = IndexedEntryWithDocument(
        entry: const Entry(
          id: 1,
          documentId: 1,
          lineIndex: 0,
          charStart: 0,
          charEnd: 40,
          kind: 'task',
          taskState: 'open',
          textContent: 'Morning meds',
          dueDate: '2026-10-29',
          dueTime: '09:00',
          recurrenceRaw: 'every day',
          signifier: null,
          blockId: null,
        ),
        document: fakeDoc('daily/2026-10-29.md'),
        contexts: const [],
        tags: const ['habit'],
      );

      final window = ReminderDerivationEngine.deriveRollingWindow(
        entries: [habitEntry],
        now: now,
        reminderLeadMinutesByTaskKey: const {
          'daily/2026-10-29.md:0': 30, // 30 minutes before 09:00 -> 08:30
        },
        rollingWindow: const Duration(days: 100),
        maxPendingNotifications: 64,
      );

      // Capped at 64 (iOS pending notification cap per design.md §8)
      expect(window.length, 64);
      expect(window.first.scheduledAt, DateTime(2026, 10, 29, 8, 30));
      expect(window.first.leadTime.minutesBefore, 30);
      expect(window.first.isRecurring, isTrue);
    });

    test('honors active snooze override (E-12)', () {
      final now = DateTime(2026, 10, 29, 8, 0);
      final snoozeTarget = now.add(const Duration(minutes: 15));
      final entry = IndexedEntryWithDocument(
        entry: const Entry(
          id: 2,
          documentId: 1,
          lineIndex: 3,
          charStart: 0,
          charEnd: 30,
          kind: 'task',
          taskState: 'open',
          textContent: 'Call dentist',
          dueDate: '2026-10-29',
          dueTime: '08:00',
          recurrenceRaw: null,
          signifier: null,
          blockId: null,
        ),
        document: fakeDoc('inbox.md'),
        contexts: const ['phone'],
        tags: const [],
      );

      final window = ReminderDerivationEngine.deriveRollingWindow(
        entries: [entry],
        now: now,
        snoozedUntilMsByTaskKey: {
          'inbox.md:3': snoozeTarget.millisecondsSinceEpoch,
        },
      );

      expect(window, hasLength(1));
      expect(window.single.isSnoozed, isTrue);
      expect(window.single.scheduledAt, snoozeTarget);
    });
  });
}
