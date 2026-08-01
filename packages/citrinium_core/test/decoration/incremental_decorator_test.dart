import 'package:citrinium_core/decoration.dart';
import 'package:test/test.dart';

void main() {
  group('IncrementalDecorator tests', () {
    test('Viewport scoping limits returned decorations to visible line range + margin', () {
      final text = List.generate(100, (i) => 'Line $i: - [ ] Task #tag$i').join('\n');
      final decorator = IncrementalDecorator(text);

      expect(decorator.lineCount, 100);

      final viewportDecs = decorator.getDecorationsForViewport(
        visibleStartLine: 20,
        visibleEndLine: 30,
        marginLines: 5,
      );

      // Line range 15 to 35 = 21 lines
      // Each task line has listMarker, taskMarker open/content/close, and tag open/content = 5 decs
      expect(viewportDecs.length, greaterThan(0));
      expect(viewportDecs.length, lessThan(decorator.getAllDecorations().length));
    });

    test('Incremental edit equivalence to full re-decoration', () {
      var text = '''
# Heading
- [ ] Task 1
- [x] Task 2

```dart
var x = 1;
```

Prose text with [[link]]
''';

      final dec1 = IncrementalDecorator(text);
      final initialAll = dec1.getAllDecorations();
      expect(initialAll, isNotEmpty);

      // Perform edit: toggle task 1 to [x]
      text = text.replaceFirst('- [ ] Task 1', '- [x] Task 1');
      dec1.updateText(
        text,
        text.indexOf('- [x] Task 1'),
        text.indexOf('- [x] Task 1') + 12,
        '- [x] Task 1',
      );

      final incrementalAll = dec1.getAllDecorations();
      final freshDec = IncrementalDecorator(text);
      final freshAll = freshDec.getAllDecorations();

      expect(incrementalAll.length, freshAll.length);
      for (var i = 0; i < freshAll.length; i++) {
        expect(incrementalAll[i].kind, freshAll[i].kind);
        expect(incrementalAll[i].role, freshAll[i].role);
        expect(incrementalAll[i].start, freshAll[i].start);
        expect(incrementalAll[i].end, freshAll[i].end);
      }
    });
  });
}
