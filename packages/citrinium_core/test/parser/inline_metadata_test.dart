import 'package:citrinium_core/parser.dart';
import 'package:test/test.dart';

void main() {
  group('extractInlineMetadata (via MarkdownDocument line parsing)', () {
    ParsedLine firstLine(String text) =>
        MarkdownDocument.parse(text).lines.first;

    test('extracts a date field with its span', () {
      const text = '- [ ] Call pharmacy 📅 2026-08-01\n';
      final line = firstLine(text);
      final date = line.metadata.singleWhere(
        (m) => m.kind == InlineMetadataKind.date,
      );
      expect(date.value, '2026-08-01');
      expect(date.valueSpan.of(text), '2026-08-01');
      expect(date.span.of(text), '📅 2026-08-01');
    });

    test('extracts a time field with no space before the value', () {
      const text = '- [ ] Stretch ⏰08:00\n';
      final line = firstLine(text);
      final time = line.metadata.singleWhere(
        (m) => m.kind == InlineMetadataKind.time,
      );
      expect(time.value, '08:00');
      expect(time.span.of(text), '⏰08:00');
    });

    test('extracts a recurrence field bounded by the next marker', () {
      const text = '- [ ] Stretch 🔁 every weekday ⏰08:00 #habit\n';
      final line = firstLine(text);
      final rec = line.metadata.singleWhere(
        (m) => m.kind == InlineMetadataKind.recurrence,
      );
      expect(rec.value, 'every weekday');
    });

    test('extracts a recurrence field that runs to end of line', () {
      const text = '- [ ] Stretch 🔁 every 1st Monday\n';
      final line = firstLine(text);
      final rec = line.metadata.singleWhere(
        (m) => m.kind == InlineMetadataKind.recurrence,
      );
      expect(rec.value, 'every 1st Monday');
    });

    test('extracts context, tag, and block ID', () {
      const text = '- [ ] Call pharmacy @phone #waiting-for/dr-lee ^t7f3a2b\n';
      final line = firstLine(text);
      expect(
        line.metadata
            .singleWhere((m) => m.kind == InlineMetadataKind.context)
            .value,
        'phone',
      );
      expect(
        line.metadata
            .singleWhere((m) => m.kind == InlineMetadataKind.tag)
            .value,
        'waiting-for/dr-lee',
      );
      expect(
        line.metadata
            .singleWhere((m) => m.kind == InlineMetadataKind.blockId)
            .value,
        't7f3a2b',
      );
    });

    test('extracts multiple tags and contexts on the same line', () {
      const text = '- [ ] Multi #tag1 #tag2 @home @errands\n';
      final line = firstLine(text);
      final tags = line.metadata
          .where((m) => m.kind == InlineMetadataKind.tag)
          .map((m) => m.value);
      final contexts = line.metadata
          .where((m) => m.kind == InlineMetadataKind.context)
          .map((m) => m.value);
      expect(tags, ['tag1', 'tag2']);
      expect(contexts, ['home', 'errands']);
    });

    test('an ATX heading marker is not misparsed as a tag', () {
      const text = '# Heading #still-a-tag\n';
      final line = firstLine(text);
      expect(line.kind, LineKind.heading);
      expect(line.metadata.single.kind, InlineMetadataKind.tag);
      expect(line.metadata.single.value, 'still-a-tag');
    });

    test(
      'a standalone tag line (no heading) is recognized as a tag, not a heading',
      () {
        const text = '#standalone-tag\n';
        final line = firstLine(text);
        expect(line.kind, isNot(LineKind.heading));
        expect(line.metadata.single.value, 'standalone-tag');
      },
    );

    test('the #heading fragment of a wikilink is not misparsed as a tag', () {
      const text =
          '- [ ] See [[Some Note#Some Heading]] for details #real-tag\n';
      final line = firstLine(text);
      final tags = line.metadata
          .where((m) => m.kind == InlineMetadataKind.tag)
          .toList();
      expect(tags, hasLength(1));
      expect(tags.single.value, 'real-tag');
    });

    test(
      'metadata offsets are correct even with emoji earlier on the line (surrogate pairs)',
      () {
        const text = '- [ ] 🎉 Celebrate 📅 2026-08-01\n';
        final line = firstLine(text);
        final date = line.metadata.singleWhere(
          (m) => m.kind == InlineMetadataKind.date,
        );
        expect(date.valueSpan.of(text), '2026-08-01');
      },
    );

    test('returns metadata sorted by position', () {
      const text = '- [ ] Task ^blk1 📅 2026-08-01 @ctx #tag\n';
      final line = firstLine(text);
      final positions = line.metadata.map((m) => m.span.start).toList();
      expect(positions, equals([...positions]..sort()));
    });

    test('no metadata is extracted from a blank line', () {
      final line = firstLine('\n');
      expect(line.metadata, isEmpty);
    });

    test('no metadata is extracted from lines inside a fenced code block', () {
      const text = '```\n#tag @ctx 📅 2026-08-01\n```\n';
      final doc = MarkdownDocument.parse(text);
      expect(doc.lines[1].kind, LineKind.code);
      expect(doc.lines[1].metadata, isEmpty);
    });
  });
}
