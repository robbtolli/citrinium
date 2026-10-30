import 'dart:io';

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
      const falsePositiveCorpus = [
        'Review architecture doc for version 2',
        'May 3rd project retrospective notes',
        'May I ask a question about the API',
        'March forward with the migration plan',
        'Sat on the patio and read chapter 4',
        'Buy sun block and 5 apples',
        '- [ ] Existing task 📅 2026-10-30',
        '- [ ] Existing time ⏰14:30',
      ];

      for (final phrase in falsePositiveCorpus) {
        expect(
          NlDateParser.detect(phrase, referenceNow: referenceNow),
          isNull,
          reason: 'Should not false-positive on: "$phrase"',
        );
      }
    });

    test('replaces existing 📅 singleton field when a new NL date is confirmed', () {
      const input = '- [ ] Submit report 📅 2026-10-20 tomorrow @work';
      final match = NlDateParser.detect(input, referenceNow: referenceNow);
      expect(match, isNotNull);
      expect(match!.dueDate, '2026-10-29');

      final rewritten = match.applyToLineText(input);
      expect(rewritten, '- [ ] Submit report 📅 2026-10-29 @work');
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
      expect(CadenceFiles.projectRelPath('Renew Passport!'), 'projects/renew-passport.md');
      expect(CadenceFiles.collectionRelPath('Books to Read'), 'collections/books-to-read.md');

      final projMd = CadenceFiles.defaultProjectContent(
        title: 'Renew Passport',
        outcome: 'Passport in hand before July',
        firstNextAction: 'Download form @computer',
      );
      expect(projMd, contains('type: project'));
      expect(projMd, contains('outcome: Passport in hand before July'));
      expect(projMd, contains('- [ ] Download form @computer'));

      final refMd = CadenceFiles.defaultReferenceContent();
      expect(refMd, contains('type: reference'));
    });

    test('bridges horizon links across disabled cadences (B-12, QY-04)', () {
      final date = DateTime(2026, 10, 28);
      // When Monthly is disabled, Weekly links down to Daily and bridges up to Quarterly
      final links = CadenceFiles.horizonLinksForCadence(
        CadenceKind.weekly,
        date,
        {
          CadenceKind.daily,
          CadenceKind.weekly,
          CadenceKind.quarterly,
          CadenceKind.yearly,
        },
      );
      expect(links, ['[[daily/2026-10-28]]', '[[quarterly/2026-Q4]]']);
    });

    test('saves, expands, and resets custom cadence templates while preserving frontmatter (B-11)', () async {
      final tempDir = await Directory.systemTemp.createTemp('citrinium_tpl_');
      addTearDown(() => tempDir.delete(recursive: true));

      final date = DateTime(2026, 10, 28);
      expect(
        CadenceFiles.hasCustomTemplate(
          vaultRootPath: tempDir.path,
          cadence: CadenceKind.weekly,
        ),
        isFalse,
      );

      // Save a custom template WITHOUT YAML frontmatter -> defaultContentForCadence
      // must prepend citrinium.type so the underlying feature is never disabled (B-11)
      await CadenceFiles.saveCustomTemplateForCadence(
        vaultRootPath: tempDir.path,
        cadence: CadenceKind.weekly,
        templateText: '# Custom Week {{week}}\nHorizons: {{horizons}}\n- [ ] Custom priority\n',
      );

      expect(
        CadenceFiles.hasCustomTemplate(
          vaultRootPath: tempDir.path,
          cadence: CadenceKind.weekly,
        ),
        isTrue,
      );

      final rendered = CadenceFiles.defaultContentForCadence(
        CadenceKind.weekly,
        date,
        vaultRootPath: tempDir.path,
        enabledCadences: {CadenceKind.daily, CadenceKind.weekly, CadenceKind.monthly},
      );
      expect(rendered, contains('type: weeklyLog'));
      expect(rendered, contains('# Custom Week 2026-W44'));
      expect(rendered, contains('[[daily/2026-10-28]] · [[monthly/2026-10]]'));

      await CadenceFiles.resetTemplateForCadence(
        vaultRootPath: tempDir.path,
        cadence: CadenceKind.weekly,
      );
      expect(
        CadenceFiles.hasCustomTemplate(
          vaultRootPath: tempDir.path,
          cadence: CadenceKind.weekly,
        ),
        isFalse,
      );
    });
  });
}
