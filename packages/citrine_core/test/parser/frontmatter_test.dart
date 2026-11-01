import 'package:citrine_core/parser.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('MarkdownDocument frontmatter recognition', () {
    test('parses a simple frontmatter block', () {
      const text =
          '---\ncitrine:\n  type: note\ntags: [a, b]\n---\nBody text\n';
      final doc = MarkdownDocument.parse(text);
      final fm = doc.frontmatter;
      expect(fm, isNotNull);
      expect(fm!.data, isA<YamlMap>());
      expect((fm.data!['citrine'] as YamlMap)['type'], 'note');
      expect(fm.data!['tags'], ['a', 'b']);
      expect(
        fm.span.of(text),
        '---\ncitrine:\n  type: note\ntags: [a, b]\n---\n',
      );
      expect(doc.lines.first.span.of(text), 'Body text');
    });

    test('is not recognized unless at offset 0', () {
      const text = 'Some prose\n---\ncitrine:\n  type: note\n---\nMore\n';
      final doc = MarkdownDocument.parse(text);
      expect(doc.frontmatter, isNull);
    });

    test('is not recognized without a matching closing delimiter', () {
      const text =
          '---\ncitrine:\n  type: note\nBody, no closing delimiter\n';
      final doc = MarkdownDocument.parse(text);
      expect(doc.frontmatter, isNull);
    });

    test('an empty frontmatter block parses with a null data map', () {
      const text = '---\n---\nBody\n';
      final doc = MarkdownDocument.parse(text);
      expect(doc.frontmatter, isNotNull);
      expect(doc.frontmatter!.data, isNull);
      expect(doc.frontmatter!.rawYaml, isEmpty);
    });

    test('malformed YAML still round-trips (data is null, not a crash)', () {
      const text = '---\ncitrine: [unterminated\n---\nBody\n';
      final doc = MarkdownDocument.parse(text);
      expect(doc.frontmatter, isNotNull);
      expect(doc.frontmatter!.data, isNull);
      expect(doc.rawText, text);
    });

    test('comments and anchors/aliases are preserved and parse', () {
      const text =
          '---\n'
          '# a comment\n'
          'citrine:\n'
          '  type: project # inline comment\n'
          'anchors_demo: &shared\n'
          '  note: hello\n'
          'alias_demo: *shared\n'
          '---\n'
          'Body\n';
      final doc = MarkdownDocument.parse(text);
      final fm = doc.frontmatter!;
      expect((fm.data!['citrine'] as YamlMap)['type'], 'project');
      expect((fm.data!['alias_demo'] as YamlMap)['note'], 'hello');
      expect(doc.rawText, text);
    });

    test(
      'a body line consisting only of "---" is not treated as a second frontmatter block',
      () {
        const text = '---\ntype: note\n---\nBody\n\n---\n\nMore body\n';
        final doc = MarkdownDocument.parse(text);
        expect(doc.frontmatter!.rawYaml, 'type: note\n');
        // The second "---" shows up as an ordinary body line.
        final thematicBreakLine = doc.lines.firstWhere(
          (l) => l.span.of(text) == '---',
        );
        expect(thematicBreakLine.kind, LineKind.text);
      },
    );
  });

  group('MarkdownDocument.setFrontmatterValue / removeFrontmatterValue', () {
    test(
      'sets a nested value on existing frontmatter, preserving other keys/comments',
      () {
        const text =
            '---\n# top comment\ncitrine:\n  type: note\ntags: [a, b]\n---\nBody\n';
        final doc = MarkdownDocument.parse(text);
        final updated = doc.setFrontmatterValue([
          'citrine',
          'status',
        ], 'active');
        final fm = updated.frontmatter!;
        expect((fm.data!['citrine'] as YamlMap)['status'], 'active');
        expect((fm.data!['citrine'] as YamlMap)['type'], 'note');
        expect(fm.data!['tags'], ['a', 'b']);
        // Body untouched.
        expect(updated.rawText, endsWith('---\nBody\n'));
      },
    );

    test(
      'creates an intermediate map when the parent key does not exist yet',
      () {
        const text = '---\ntags: [a, b]\n---\nBody\n';
        final doc = MarkdownDocument.parse(text);
        final updated = doc.setFrontmatterValue([
          'citrine',
          'status',
        ], 'active');
        final citrine = updated.frontmatter!.data!['citrine'] as YamlMap;
        expect(citrine['status'], 'active');
      },
    );

    test('creates a new frontmatter block when none exists', () {
      const text = 'Just a body, no frontmatter.\n';
      final doc = MarkdownDocument.parse(text);
      final updated = doc.setFrontmatterValue(['citrine', 'type'], 'note');
      expect(updated.frontmatter, isNotNull);
      final citrine = updated.frontmatter!.data!['citrine'] as YamlMap;
      expect(citrine['type'], 'note');
      expect(updated.rawText, contains('Just a body, no frontmatter.'));
    });

    test('removeFrontmatterValue removes a key and preserves the rest', () {
      const text =
          '---\ncitrine:\n  type: note\n  status: active\n---\nBody\n';
      final doc = MarkdownDocument.parse(text);
      final updated = doc.removeFrontmatterValue(['citrine', 'status']);
      final citrine = updated.frontmatter!.data!['citrine'] as YamlMap;
      expect(citrine.containsKey('status'), isFalse);
      expect(citrine['type'], 'note');
    });

    test(
      'removeFrontmatterValue on a document with no frontmatter is a no-op',
      () {
        const text = 'Body only\n';
        final doc = MarkdownDocument.parse(text);
        final updated = doc.removeFrontmatterValue(['citrine', 'status']);
        expect(updated.rawText, text);
      },
    );

    test('removeFrontmatterValue on a missing key is a no-op', () {
      const text = '---\ncitrine:\n  type: note\n---\nBody\n';
      final doc = MarkdownDocument.parse(text);
      final updated = doc.removeFrontmatterValue(['citrine', 'nonexistent']);
      expect(updated.rawText, text);
    });
  });
}
