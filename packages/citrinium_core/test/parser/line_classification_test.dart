import 'package:citrinium_core/parser.dart';
import 'package:test/test.dart';

void main() {
  group('task line classification (D-02, design.md §3.1)', () {
    const cases = {
      '- [ ] open': TaskStateKind.open,
      '- [/] in progress': TaskStateKind.inProgress,
      '- [x] done': TaskStateKind.completed,
      '- [X] done capital': TaskStateKind.completed,
      '- [>] migrated': TaskStateKind.migrated,
      '- [<] scheduled': TaskStateKind.scheduled,
      '- [-] dropped': TaskStateKind.dropped,
      '- [w] waiting': TaskStateKind.waitingFor,
      '- [W] waiting capital': TaskStateKind.waitingFor,
    };

    cases.forEach((line, expectedState) {
      test('"$line" classifies as task/$expectedState', () {
        final doc = MarkdownDocument.parse('$line\n');
        final parsed = doc.lines.single;
        expect(parsed.kind, LineKind.task);
        expect(parsed.task!.stateKind, expectedState);
      });
    });

    test('an unrecognized marker char is preserved verbatim as unknown', () {
      final doc = MarkdownDocument.parse('- [?] custom status\n');
      final task = doc.lines.single.task!;
      expect(task.stateKind, TaskStateKind.unknown);
      expect(task.markerChar, '?');
    });

    test('*, and + bullets are recognized as tasks too', () {
      for (final bullet in ['-', '*', '+']) {
        final doc = MarkdownDocument.parse('$bullet [ ] task\n');
        expect(
          doc.lines.single.kind,
          LineKind.task,
          reason: 'bullet "$bullet"',
        );
      }
    });

    test('task content span covers the description text', () {
      const text = '- [ ] Call pharmacy 📅 2026-08-01\n';
      final task = MarkdownDocument.parse(text).lines.single.task!;
      expect(task.contentSpan.of(text), 'Call pharmacy 📅 2026-08-01');
    });

    test('a bare checkbox with no description has an empty content span', () {
      const text = '- [ ]\n';
      final task = MarkdownDocument.parse(text).lines.single.task!;
      expect(task.contentSpan.isEmpty, isTrue);
    });

    test(
      'checkboxSpan and markerSpan cover exactly the brackets and marker char',
      () {
        const text = '- [x] done\n';
        final task = MarkdownDocument.parse(text).lines.single.task!;
        expect(task.checkboxSpan.of(text), '[x]');
        expect(task.markerSpan.of(text), 'x');
        expect(task.bulletSpan.of(text), '-');
      },
    );
  });

  group('BuJo event/note classification (design.md §3.2)', () {
    test('an event line', () {
      const text = '- ○ Dentist appointment 📅 2026-08-03 15:00\n';
      final line = MarkdownDocument.parse(text).lines.single;
      expect(line.kind, LineKind.event);
      expect(line.bujo!.kind, BujoKind.event);
      expect(
        line.bujo!.contentSpan.of(text),
        'Dentist appointment 📅 2026-08-03 15:00',
      );
    });

    test('a note line', () {
      const text = '- – Idea: batch prescription refills quarterly\n';
      final line = MarkdownDocument.parse(text).lines.single;
      expect(line.kind, LineKind.note);
      expect(line.bujo!.kind, BujoKind.note);
    });
  });

  group('other line kinds', () {
    test('blank lines', () {
      final doc = MarkdownDocument.parse('\n   \n\t\n');
      expect(doc.lines.every((l) => l.kind == LineKind.blank), isTrue);
    });

    test('ATX headings level 1-6', () {
      for (var level = 1; level <= 6; level++) {
        final hashes = '#' * level;
        final doc = MarkdownDocument.parse('$hashes Heading\n');
        expect(doc.lines.single.kind, LineKind.heading, reason: 'level $level');
      }
    });

    test('a generic untyped bullet is a listItem', () {
      final doc = MarkdownDocument.parse('- just a bullet, no checkbox\n');
      expect(doc.lines.single.kind, LineKind.listItem);
    });

    test('ordinary prose is text', () {
      final doc = MarkdownDocument.parse('Just a paragraph of prose.\n');
      expect(doc.lines.single.kind, LineKind.text);
    });
  });

  group('nested lists', () {
    test('a 2-space-nested task under a task is still a task, not code', () {
      const text = '- [ ] parent\n  - [x] child\n';
      final doc = MarkdownDocument.parse(text);
      expect(doc.lines[0].kind, LineKind.task);
      expect(doc.lines[1].kind, LineKind.task);
      expect(doc.lines[1].task!.stateKind, TaskStateKind.completed);
    });

    test(
      'a 4-space-nested task directly under a non-blank list line is still a task',
      () {
        const text = '- [ ] parent\n    - [ ] grandchild\n';
        final doc = MarkdownDocument.parse(text);
        expect(doc.lines[1].kind, LineKind.task);
      },
    );
  });

  group('tab-indented lines', () {
    test(
      'a tab-indented nested task under a non-blank line is still a task',
      () {
        const text = '- [ ] parent\n\t- [ ] tab child\n';
        final doc = MarkdownDocument.parse(text);
        expect(doc.lines[1].kind, LineKind.task);
      },
    );

    test(
      'a tab-indented line after a blank line is indented code, not a task',
      () {
        const text = 'Paragraph.\n\n\t- [ ] this is code\n';
        final doc = MarkdownDocument.parse(text);
        expect(doc.lines[2].kind, LineKind.code);
      },
    );
  });
}
