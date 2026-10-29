import 'package:citrinium_core/citrinium_core.dart';
import 'package:test/test.dart';

void main() {
  group('NlDateParser (C-04)', () {
    final referenceNow = DateTime(2026, 10, 28, 10, 0); // Wed Oct 28, 2026

    test('detects "tomorrow 5pm" and splices structured 📅 and ⏰ tokens', () {
      const input = 'Call pharmacy about refill tomorrow 5pm @phone';
      final match = NlDateParser.detect(input, referenceNow: referenceNow);

      expect(match, isNotNull);
      expect(match!.dueDate, '2026-10-29');
      expect(match.dueTime, '17:00');
      expect(match.matchedText, 'tomorrow 5pm');

      final rewritten = match.applyToLineText(input).trim();
      expect(
        rewritten,
        '- [ ] Call pharmacy about refill @phone 📅 2026-10-29 ⏰17:00',
      );
    });

    test('detects "in 3 days" and "next monday"', () {
      final in3 = NlDateParser.detect(
        'Follow up in 3 days',
        referenceNow: referenceNow,
      );
      expect(in3, isNotNull);
      expect(in3!.dueDate, '2026-10-31');

      final nextMon = NlDateParser.detect(
        'Weekly sync next monday at 9:30am',
        referenceNow: referenceNow,
      );
      expect(nextMon, isNotNull);
      expect(nextMon!.dueDate, '2026-11-02');
      expect(nextMon.dueTime, '09:30');
    });

    test('does not false-positive on ordinary text or existing 📅 metadata', () {
      expect(
        NlDateParser.detect(
          'Review architecture doc for version 2',
          referenceNow: referenceNow,
        ),
        isNull,
      );
      expect(
        NlDateParser.detect(
          '- [ ] Existing task 📅 2026-10-30',
          referenceNow: referenceNow,
        ),
        isNull,
      );
    });
  });

  group('MarkdownDocument in-place editing (D-19)', () {
    test('replaceEntryContent preserves prefix and untouched lines byte-for-byte', () {
      const raw = '# Heading\n- [ ] Old task description\n- – A note line\n';
      final doc = MarkdownDocument.parse(raw);

      final updated = doc.replaceEntryContent(
        1,
        'Updated task description @computer',
      );
      expect(
        updated.rawText,
        '# Heading\n- [ ] Updated task description @computer\n- – A note line\n',
      );
    });

    test('convertToTask turns an untyped list item or BuJo line into a task', () {
      const raw = '- Raw inbox item\n- – Note item\n';
      final doc = MarkdownDocument.parse(raw);

      final step1 = doc.convertToTask(0, state: TaskStateKind.open);
      expect(step1.rawText, '- [ ] Raw inbox item\n- – Note item\n');

      final step2 = step1.convertToTask(1, state: TaskStateKind.waitingFor);
      expect(step2.rawText, '- [ ] Raw inbox item\n- [w] Note item\n');
    });
  });

  group('CadenceFiles paths & ISO week (B-01, B-02, B-12)', () {
    test('formats daily, weekly, monthly, quarterly, and yearly paths', () {
      final date = DateTime(2026, 10, 28);
      expect(CadenceFiles.dailyRelPath(date), 'daily/2026-10-28.md');
      expect(CadenceFiles.weeklyRelPath(date), 'weekly/2026-W44.md');
      expect(CadenceFiles.monthlyRelPath(date), 'monthly/2026-10.md');
      expect(CadenceFiles.quarterlyRelPath(date), 'quarterly/2026-Q4.md');
      expect(CadenceFiles.yearlyRelPath(date), 'yearly/2026.md');
    });
  });
}
