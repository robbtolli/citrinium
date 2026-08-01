import 'dart:math';

import 'package:citrinium_core/decoration.dart';
import 'package:test/test.dart';

void main() {
  group('Exit Criterion #5: Property Test - Incremental vs Full re-decoration', () {
    test('Randomized edit sequences produce identical decoration output', () {
      final rand = Random(42);
      final initialLines = [
        '# Heading 1',
        '- [ ] Open task',
        '- [x] Completed task',
        'Some prose with **bold** and *italic* and [[link|alias]]',
        '```dart',
        'void main() { print("hello"); }',
        '```',
        '📅 2026-08-01 ⏰12:00 @work #tag',
      ];

      var text = initialLines.join('\n');

      final incremental = IncrementalDecorator(text);

      for (var step = 0; step < 50; step++) {
        final lineIdx = rand.nextInt(initialLines.length);
        final oldLine = initialLines[lineIdx];
        final newLine = '$oldLine modified $step';
        initialLines[lineIdx] = newLine;

        final newText = initialLines.join('\n');
        final editStart = newText.indexOf(newLine);

        incremental.updateText(
          newText,
          editStart,
          editStart + newLine.length,
          newLine,
        );

        final incDecs = incremental.getAllDecorations();
        final fresh = IncrementalDecorator(newText);
        final freshDecs = fresh.getAllDecorations();

        expect(incDecs.length, equals(freshDecs.length),
            reason: 'Failed at edit step $step on line $lineIdx');

        for (var d = 0; d < freshDecs.length; d++) {
          expect(incDecs[d].kind, equals(freshDecs[d].kind));
          expect(incDecs[d].role, equals(freshDecs[d].role));
          expect(incDecs[d].start, equals(freshDecs[d].start));
          expect(incDecs[d].end, equals(freshDecs[d].end));
        }
      }
    });
  });
}
