import 'package:citrinium_core/parser.dart';
import 'package:citrinium_core/vault.dart';
import 'package:test/test.dart';

/// Asserts that [edited] differs from [original] only within
/// `[changeStart, changeEnd)` -- i.e. every byte/char before and after that
/// range is untouched. This is the mutation-locality property required by
/// `docs/milestones/m0.md` W2/W6 and `design.md` §10.
void expectMutationLocality(
  String original,
  String edited,
  int changeStart,
  int changeEnd,
) {
  expect(
    edited.substring(0, changeStart),
    original.substring(0, changeStart),
    reason: 'prefix changed',
  );
  expect(
    edited.substring(edited.length - (original.length - changeEnd)),
    original.substring(changeEnd),
    reason: 'suffix changed',
  );
}

void main() {
  group('setTaskState', () {
    test('flips a single character and nothing else', () {
      const original = '# Tasks\n\n- [ ] one\n- [ ] two\n- [ ] three\n';
      final doc = MarkdownDocument.parse(original);
      final lineIndex = doc.lines.indexWhere(
        (l) => l.span.of(original) == '- [ ] two',
      );

      final edited = doc.setTaskState(lineIndex, TaskStateKind.completed);

      expect(edited.rawText, contains('- [x] two'));
      final markerOffset = original.indexOf('- [ ] two') + 3;
      expectMutationLocality(
        original,
        edited.rawText,
        markerOffset,
        markerOffset + 1,
      );
    });

    test('every known TaskStateKind writes its canonical character', () {
      const original = '- [ ] task\n';
      final doc = MarkdownDocument.parse(original);
      for (final kind in TaskStateKind.values) {
        if (kind == TaskStateKind.unknown) continue;
        final edited = doc.setTaskState(0, kind);
        expect(edited.lines.single.task!.stateKind, kind);
      }
    });

    test('throws when the target line is not a task', () {
      final doc = MarkdownDocument.parse('Just prose\n');
      expect(
        () => doc.setTaskState(0, TaskStateKind.completed),
        throwsA(isA<MarkdownEditException>()),
      );
    });

    test('setTaskMarkerChar preserves a custom/unknown marker verbatim', () {
      final doc = MarkdownDocument.parse('- [ ] task\n');
      final edited = doc.setTaskMarkerChar(0, '!');
      expect(edited.lines.single.task!.markerChar, '!');
      expect(edited.lines.single.task!.stateKind, TaskStateKind.unknown);
    });

    test(
      'is idempotent when reparsed: setting the same state twice converges',
      () {
        final doc = MarkdownDocument.parse('- [ ] task\n');
        final once = doc.setTaskState(0, TaskStateKind.completed);
        final twice = once.setTaskState(0, TaskStateKind.completed);
        expect(twice.rawText, once.rawText);
      },
    );
  });

  group('upsertInlineField', () {
    test('appends a date field to a line with none', () {
      const original = '- [ ] Call pharmacy\n';
      final doc = MarkdownDocument.parse(original);
      final edited = doc.upsertInlineField(
        0,
        InlineMetadataKind.date,
        '2026-08-01',
      );
      expect(edited.rawText, '- [ ] Call pharmacy 📅 2026-08-01\n');
    });

    test('replaces an existing date field value in place', () {
      const original = '- [ ] Call pharmacy 📅 2026-08-01 @phone\n';
      final doc = MarkdownDocument.parse(original);
      final edited = doc.upsertInlineField(
        0,
        InlineMetadataKind.date,
        '2026-09-15',
      );
      expect(edited.rawText, '- [ ] Call pharmacy 📅 2026-09-15 @phone\n');
    });

    test('inserts a new field before an existing block ID', () {
      const original = '- [ ] Call pharmacy ^t7f3a2b\n';
      final doc = MarkdownDocument.parse(original);
      final edited = doc.upsertInlineField(
        0,
        InlineMetadataKind.date,
        '2026-08-01',
      );
      expect(edited.rawText, '- [ ] Call pharmacy 📅 2026-08-01 ^t7f3a2b\n');
    });

    test('adding a tag that already exists on the line is a no-op', () {
      const original = '- [ ] task #tag\n';
      final doc = MarkdownDocument.parse(original);
      final edited = doc.upsertInlineField(0, InlineMetadataKind.tag, 'tag');
      expect(identical(edited, doc), isTrue);
    });

    test('adding a second, distinct tag appends it', () {
      const original = '- [ ] task #tag1\n';
      final doc = MarkdownDocument.parse(original);
      final edited = doc.upsertInlineField(0, InlineMetadataKind.tag, 'tag2');
      expect(edited.rawText, '- [ ] task #tag1 #tag2\n');
    });

    test(
      'mutation locality: prefix before the insertion point is untouched',
      () {
        const original =
            '- [ ] Call pharmacy about the refill\n- [ ] Unrelated task\n';
        final doc = MarkdownDocument.parse(original);
        final edited = doc.upsertInlineField(
          0,
          InlineMetadataKind.date,
          '2026-08-01',
        );
        final insertionPoint = original.indexOf('\n- [ ] Unrelated');
        expect(
          edited.rawText.substring(0, insertionPoint),
          original.substring(0, insertionPoint),
        );
        expect(edited.rawText, endsWith('- [ ] Unrelated task\n'));
      },
    );

    test('throws on a code line', () {
      final doc = MarkdownDocument.parse('```\ncode\n```\n');
      expect(
        () => doc.upsertInlineField(1, InlineMetadataKind.tag, 'x'),
        throwsA(isA<MarkdownEditException>()),
      );
    });
  });

  group('removeInlineField', () {
    test('removes a singleton field and collapses the extra space', () {
      const original = '- [ ] Call pharmacy 📅 2026-08-01 @phone\n';
      final doc = MarkdownDocument.parse(original);
      final edited = doc.removeInlineField(0, InlineMetadataKind.date);
      expect(edited.rawText, '- [ ] Call pharmacy @phone\n');
    });

    test('removes only the matching tag value, leaving others intact', () {
      const original = '- [ ] task #tag1 #tag2 #tag3\n';
      final doc = MarkdownDocument.parse(original);
      final edited = doc.removeInlineField(
        0,
        InlineMetadataKind.tag,
        value: 'tag2',
      );
      expect(edited.rawText, '- [ ] task #tag1 #tag3\n');
    });

    test('removes every tag of a kind when no value is given', () {
      const original = '- [ ] task #tag1 #tag2\n';
      final doc = MarkdownDocument.parse(original);
      final edited = doc.removeInlineField(0, InlineMetadataKind.tag);
      expect(edited.rawText, '- [ ] task\n');
    });

    test('is a no-op when the field is not present', () {
      const original = '- [ ] task\n';
      final doc = MarkdownDocument.parse(original);
      final edited = doc.removeInlineField(0, InlineMetadataKind.date);
      expect(identical(edited, doc), isTrue);
    });

    test(
      'removing the last remaining field before a block ID collapses correctly',
      () {
        const original = '- [ ] task 📅 2026-08-01 ^blk1\n';
        final doc = MarkdownDocument.parse(original);
        final edited = doc.removeInlineField(0, InlineMetadataKind.date);
        expect(edited.rawText, '- [ ] task ^blk1\n');
      },
    );

    test('mutation locality: unrelated lines are untouched', () {
      const original = '- [ ] one 📅 2026-08-01\n- [ ] two 📅 2026-08-02\n';
      final doc = MarkdownDocument.parse(original);
      final edited = doc.removeInlineField(0, InlineMetadataKind.date);
      expect(edited.rawText, endsWith('- [ ] two 📅 2026-08-02\n'));
    });
  });

  group('appendLine', () {
    test(
      'adds a trailing newline before appending if the document lacked one',
      () {
        const original = '- [ ] existing task';
        final doc = MarkdownDocument.parse(original);
        final edited = doc.appendLine('- [ ] new task');
        expect(edited.rawText, '- [ ] existing task\n- [ ] new task\n');
      },
    );

    test(
      'does not add an extra blank line if the document already ends with a newline',
      () {
        const original = '- [ ] existing task\n';
        final doc = MarkdownDocument.parse(original);
        final edited = doc.appendLine('- [ ] new task');
        expect(edited.rawText, '- [ ] existing task\n- [ ] new task\n');
      },
    );

    test('matches the document\'s dominant CRLF line ending by default', () {
      const original = '- [ ] one\r\n- [ ] two\r\n';
      final doc = MarkdownDocument.parse(original);
      final edited = doc.appendLine('- [ ] three');
      expect(edited.rawText, '- [ ] one\r\n- [ ] two\r\n- [ ] three\r\n');
    });

    test('an explicit lineEnding override takes precedence', () {
      const original = '- [ ] one\n';
      final doc = MarkdownDocument.parse(original);
      final edited = doc.appendLine(
        '- [ ] two',
        lineEnding: LineEndingStyle.crlf,
      );
      expect(edited.rawText, '- [ ] one\n- [ ] two\r\n');
    });

    test('appending to a completely empty document', () {
      final doc = MarkdownDocument.parse('');
      final edited = doc.appendLine('- [ ] first task');
      expect(edited.rawText, '- [ ] first task\n');
    });

    test('preserves everything before it, mutation-locality style', () {
      const original = '# Log\n\n- [ ] existing\n';
      final doc = MarkdownDocument.parse(original);
      final edited = doc.appendLine('- [ ] appended');
      expect(edited.rawText, startsWith(original));
    });
  });
}
