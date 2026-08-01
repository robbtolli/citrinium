import 'package:citrinium_core/src/parser/code_blocks.dart';
import 'package:citrinium_core/src/parser/raw_lines.dart';
import 'package:test/test.dart';

List<CodeLineStatus> statusesFor(String text) =>
    computeCodeLineStatuses(splitRawLines(text));

void main() {
  group('computeCodeLineStatuses', () {
    test('a simple backtick fence', () {
      const text = '```\ncode\n```\n';
      final statuses = statusesFor(text);
      expect(statuses, [
        CodeLineStatus.fenceDelimiter,
        CodeLineStatus.code,
        CodeLineStatus.fenceDelimiter,
      ]);
    });

    test('a tilde fence', () {
      const text = '~~~\ncode\n~~~\n';
      expect(statusesFor(text), [
        CodeLineStatus.fenceDelimiter,
        CodeLineStatus.code,
        CodeLineStatus.fenceDelimiter,
      ]);
    });

    test('a fence with a language info string', () {
      const text = '```dart\ncode\n```\n';
      expect(statusesFor(text)[0], CodeLineStatus.fenceDelimiter);
    });

    test(
      'a shorter fence character run inside a longer fence does not close it',
      () {
        const text = '````\n```\ninner\n```\n````\n';
        expect(statusesFor(text), [
          CodeLineStatus.fenceDelimiter, // ````
          CodeLineStatus.code, // ```
          CodeLineStatus.code, // inner
          CodeLineStatus.code, // ```
          CodeLineStatus.fenceDelimiter, // ````
        ]);
      },
    );

    test('an unterminated fence treats the rest of the document as code', () {
      const text = '```\nunterminated\nstill code\n';
      expect(statusesFor(text), [
        CodeLineStatus.fenceDelimiter,
        CodeLineStatus.code,
        CodeLineStatus.code,
      ]);
    });

    test('indented code after a blank line', () {
      const text = 'Paragraph.\n\n    indented code\n    more code\n';
      expect(statusesFor(text), [
        CodeLineStatus.none,
        CodeLineStatus.none, // blank line
        CodeLineStatus.code,
        CodeLineStatus.code,
      ]);
    });

    test('indented code at the very start of the document', () {
      const text = '    indented from the start\n';
      expect(statusesFor(text), [CodeLineStatus.code]);
    });

    test(
      'a 4-space-indented line directly after a non-blank list line is NOT code',
      () {
        const text = '- parent\n    - nested child\n';
        expect(statusesFor(text), [CodeLineStatus.none, CodeLineStatus.none]);
      },
    );

    test(
      'a 2-space nested list is never mistaken for code regardless of context',
      () {
        const text = '- parent\n  - nested child\n';
        expect(statusesFor(text), [CodeLineStatus.none, CodeLineStatus.none]);
      },
    );

    test('tabs expand to 4-column stops for indented-code detection', () {
      const text = 'Paragraph.\n\n\ttab-indented code\n';
      expect(statusesFor(text), [
        CodeLineStatus.none,
        CodeLineStatus.none,
        CodeLineStatus.code,
      ]);
    });

    test('a 3-space indent is not enough to be indented code', () {
      const text = 'Paragraph.\n\n   only three spaces\n';
      expect(statusesFor(text), [
        CodeLineStatus.none,
        CodeLineStatus.none,
        CodeLineStatus.none,
      ]);
    });
  });
}
