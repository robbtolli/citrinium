import 'package:citrinium_core/parser.dart';
import 'package:test/test.dart';

void main() {
  group('extractWikiLinks (via MarkdownDocument line parsing)', () {
    ParsedLine firstLine(String text) =>
        MarkdownDocument.parse(text).lines.first;

    test('a plain wikilink', () {
      const text = 'See [[Some Note]] for details\n';
      final link = firstLine(text).links.single;
      expect(link.isEmbed, isFalse);
      expect(link.target, 'Some Note');
      expect(link.targetSpan.of(text), 'Some Note');
      expect(link.heading, isNull);
      expect(link.alias, isNull);
      expect(link.span.of(text), '[[Some Note]]');
    });

    test('a wikilink with an alias', () {
      const text = 'See [[Some Note|display text]] for details\n';
      final link = firstLine(text).links.single;
      expect(link.target, 'Some Note');
      expect(link.alias, 'display text');
      expect(link.aliasSpan!.of(text), 'display text');
    });

    test('a wikilink with a heading fragment', () {
      const text = 'See [[Some Note#A Heading]] for details\n';
      final link = firstLine(text).links.single;
      expect(link.target, 'Some Note');
      expect(link.heading, 'A Heading');
      expect(link.headingSpan!.of(text), 'A Heading');
    });

    test('a wikilink with both a heading and an alias', () {
      const text = 'See [[Some Note#A Heading|display text]] for details\n';
      final link = firstLine(text).links.single;
      expect(link.target, 'Some Note');
      expect(link.heading, 'A Heading');
      expect(link.alias, 'display text');
    });

    test('an embed', () {
      const text = 'Here: ![[image.png]]\n';
      final link = firstLine(text).links.single;
      expect(link.isEmbed, isTrue);
      expect(link.target, 'image.png');
      expect(link.span.of(text), '![[image.png]]');
    });

    test('multiple wikilinks on one line, in order', () {
      const text = '[[First]] and [[Second]] and ![[Third]]\n';
      final links = firstLine(text).links;
      expect(links.map((l) => l.target), ['First', 'Second', 'Third']);
      expect(links.map((l) => l.isEmbed), [false, false, true]);
    });

    test('no wikilinks inside a fenced code block', () {
      const text = '```\n[[not a link]]\n```\n';
      final doc = MarkdownDocument.parse(text);
      expect(doc.lines[1].kind, LineKind.code);
      expect(doc.lines[1].links, isEmpty);
    });

    test('no wikilinks inside an indented code block', () {
      const text = 'Paragraph.\n\n    [[not a link]]\n';
      final doc = MarkdownDocument.parse(text);
      final codeLine = doc.lines.firstWhere(
        (l) => l.span.of(text).trim() == '[[not a link]]',
      );
      expect(codeLine.kind, LineKind.code);
      expect(codeLine.links, isEmpty);
    });

    test(
      'a wikilink on a task line is still extracted alongside task info',
      () {
        const text =
            '- [x] Done thing [[Some Note|alias]] and ![[embed.png]]\n';
        final line = firstLine(text);
        expect(line.kind, LineKind.task);
        expect(line.links, hasLength(2));
      },
    );
  });
}
