import 'package:citrinium_core/decoration.dart';
import 'package:test/test.dart';

void main() {
  group('MarkdownDecorator unit tests', () {
    test('ATX headings emit openMarker and content decorations', () {
      final res = MarkdownDecorator.decorateLine(
        lineText: '### Heading 3 text',
        lineOffset: 0,
        lineNumber: 0,
        enteringContext: BlockContext.initial,
        startNodeId: 1,
      );

      expect(res.decorations, hasLength(2));
      expect(res.decorations[0].kind, DecorationKind.heading);
      expect(res.decorations[0].role, DecorationRole.openMarker);
      expect(res.decorations[0].level, 3);
      expect(res.decorations[0].start, 0);
      expect(res.decorations[0].end, 3);

      expect(res.decorations[1].kind, DecorationKind.heading);
      expect(res.decorations[1].role, DecorationRole.content);
      expect(res.decorations[1].level, 3);
      expect(res.decorations[1].start, 3);
      expect(res.decorations[1].end, 18);
    });

    test('Fenced code block suppresses inline decoration inside code', () {
      final line1 = MarkdownDecorator.decorateLine(
        lineText: '```dart',
        lineOffset: 0,
        lineNumber: 0,
        enteringContext: BlockContext.initial,
        startNodeId: 1,
      );
      expect(line1.exitingContext.fenceContext, isNotNull);
      expect(line1.decorations[0].kind, DecorationKind.fenceDelimiter);

      final line2 = MarkdownDecorator.decorateLine(
        lineText: 'var x = "[[wikilink_inside_code]]";',
        lineOffset: 8,
        lineNumber: 1,
        enteringContext: line1.exitingContext,
        startNodeId: line1.nextNodeId,
      );

      expect(line2.decorations, hasLength(1));
      expect(line2.decorations[0].kind, DecorationKind.inlineCode);
      expect(line2.decorations[0].role, DecorationRole.content);

      final line3 = MarkdownDecorator.decorateLine(
        lineText: '```',
        lineOffset: 43,
        lineNumber: 2,
        enteringContext: line2.exitingContext,
        startNodeId: line2.nextNodeId,
      );
      expect(line3.exitingContext.fenceContext, isNull);
      expect(line3.decorations[0].kind, DecorationKind.fenceDelimiter);
      expect(line3.decorations[0].role, DecorationRole.closeMarker);
    });

    test('Flanking rules: snake_case_word does NOT italicise, but *bold* works', () {
      final resSnake = MarkdownDecorator.decorateLine(
        lineText: 'this_is_a_snake_case_variable',
        lineOffset: 0,
        lineNumber: 0,
        enteringContext: BlockContext.initial,
        startNodeId: 1,
      );
      expect(
        resSnake.decorations
            .where((d) => d.kind == DecorationKind.emphasis),
        isEmpty,
      );

      final resBold = MarkdownDecorator.decorateLine(
        lineText: 'this is **bold text** and *italic*',
        lineOffset: 0,
        lineNumber: 0,
        enteringContext: BlockContext.initial,
        startNodeId: 1,
      );
      final strongDecs = resBold.decorations
          .where((d) => d.kind == DecorationKind.strong)
          .toList();
      expect(strongDecs, hasLength(3)); // openMarker, content, closeMarker

      final italicDecs = resBold.decorations
          .where((d) => d.kind == DecorationKind.emphasis)
          .toList();
      expect(italicDecs, hasLength(3));
    });

    test('Wikilinks and embeds emit targets and alias decorations', () {
      final res = MarkdownDecorator.decorateLine(
        lineText: 'See [[Note Title|My Alias]] and ![[Image.png]]',
        lineOffset: 0,
        lineNumber: 0,
        enteringContext: BlockContext.initial,
        startNodeId: 1,
      );

      final wikilinks = res.decorations
          .where((d) => d.kind == DecorationKind.wikilink)
          .toList();
      expect(wikilinks, isNotEmpty);
      expect(wikilinks[0].payload, 'Note Title');

      final aliases = res.decorations
          .where((d) => d.kind == DecorationKind.wikilinkAlias)
          .toList();
      expect(aliases, isNotEmpty);
      expect(aliases[1].payload, 'My Alias');

      final embeds = res.decorations
          .where((d) => d.kind == DecorationKind.embed)
          .toList();
      expect(embeds, isNotEmpty);
      expect(embeds[0].payload, 'Image.png');
    });

    test('Task checkbox and Citrinium metadata parsing', () {
      final res = MarkdownDecorator.decorateLine(
        lineText: '- [x] Complete task 📅 2026-08-01 ⏰17:00 @work #project/c1',
        lineOffset: 0,
        lineNumber: 0,
        enteringContext: BlockContext.initial,
        startNodeId: 1,
      );

      expect(
        res.decorations.any((d) => d.kind == DecorationKind.taskMarker),
        isTrue,
      );
      expect(
        res.decorations.any((d) => d.kind == DecorationKind.dueDate),
        isTrue,
      );
      expect(
        res.decorations.any((d) => d.kind == DecorationKind.dueTime),
        isTrue,
      );
      expect(
        res.decorations.any((d) => d.kind == DecorationKind.context),
        isTrue,
      );
      expect(
        res.decorations.any((d) => d.kind == DecorationKind.tag),
        isTrue,
      );
    });
  });
}
