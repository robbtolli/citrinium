import 'dart:io';

import 'package:citrinium_core/parser.dart';
import 'package:citrinium_core/vault.dart';
import 'package:test/test.dart';

/// Unlike `fixture_roundtrip_test.dart` (byte-identity) and
/// `mutation_locality_property_test.dart` (edit-locality), these assert on
/// the actual *meaning* extracted from specific hostile fixtures --
/// pinning down exactly what W2's "code-fence and indented-code awareness"
/// requirement should produce, fixture by fixture.
void main() {
  MarkdownDocument load(String name) {
    final contents = readVaultFileSync(File('test/fixtures/parser/$name'));
    return MarkdownDocument.parse(contents.text);
  }

  test('code-fences.md: only the 3 real tasks outside any fence are tasks', () {
    final doc = load('code-fences.md');
    expect(doc.tasks, hasLength(3));
    for (final task in doc.tasks) {
      expect(task.span.of(doc.rawText), startsWith('- [ ] Real task'));
    }
  });

  test('code-fences.md: no wikilinks or tags leak out of fenced code', () {
    final doc = load('code-fences.md');
    // "[[not a link]]" and "#not-a-tag" only ever appear inside fences.
    expect(doc.allLinks, isEmpty);
    expect(
      doc.allMetadata.where((m) => m.metadata.value == 'not-a-tag'),
      isEmpty,
    );
  });

  test(
    'code-fences.md: fenced lines are classified as code/codeFenceDelimiter',
    () {
      final doc = load('code-fences.md');
      final fenceDelimiters = doc.lines.where(
        (l) => l.kind == LineKind.codeFenceDelimiter,
      );
      final codeLines = doc.lines.where((l) => l.kind == LineKind.code);
      // 4 fences opened/closed (3-backtick, tilde, 4-backtick-with-nested-3s,
      // plus the final unterminated fence's opening delimiter) = 7 delimiter
      // lines (the unterminated one never closes).
      expect(fenceDelimiters.length, 7);
      expect(codeLines, isNotEmpty);
    },
  );

  test(
    'tabs.md: tab-indented nested tasks are tasks; tab-indented post-blank-line content is code',
    () {
      final doc = load('tabs.md');
      expect(doc.lines[0].kind, LineKind.task); // parent
      expect(doc.lines[1].kind, LineKind.task); // tab child
      expect(doc.lines[2].kind, LineKind.task); // tab grandchild
      final codeLines = doc.lines.where((l) => l.kind == LineKind.code);
      expect(
        codeLines,
        hasLength(2),
      ); // the two tab-indented lines after the blank line
      expect(
        doc.allLinks,
        isEmpty,
      ); // "[[not a link]]" is inside the indented code block
    },
  );

  test(
    'nested-lists.md: every nested bullet/task/event line parses without corruption',
    () {
      final doc = load('nested-lists.md');
      expect(doc.tasks, hasLength(9));
      expect(doc.lines.where((l) => l.kind == LineKind.listItem), hasLength(2));
      expect(doc.lines.where((l) => l.kind == LineKind.event), hasLength(1));
    },
  );

  test(
    'emoji-dense.md: surrogate-pair-heavy lines still extract correct metadata spans',
    () {
      final doc = load('emoji-dense.md');
      for (final ref in doc.allMetadata) {
        expect(ref.metadata.valueSpan.of(doc.rawText), ref.metadata.value);
      }
      final dates = doc.allMetadata.where(
        (m) => m.metadata.kind == InlineMetadataKind.date,
      );
      expect(dates.length, greaterThanOrEqualTo(5));
    },
  );

  test(
    'nfc-nfd.md: NFC and NFD wikilink targets are preserved distinctly, not normalized',
    () {
      final doc = load('nfc-nfd.md');
      final targets = doc.allLinks.map((l) => l.link.target).toList();
      expect(targets[0], isNot(targets[1]));
      expect(
        targets[0].length,
        isNot(targets[1].length),
      ); // NFD is longer (combining marks)
    },
  );

  test(
    'long-lines.md: a task metadata span on a very long line is still exact',
    () {
      final doc = load('long-lines.md');
      final task = doc.tasks.single;
      final date = task.metadata.singleWhere(
        (m) => m.kind == InlineMetadataKind.date,
      );
      expect(date.valueSpan.of(doc.rawText), '2026-08-10');
      final blockId = task.metadata.singleWhere(
        (m) => m.kind == InlineMetadataKind.blockId,
      );
      expect(blockId.value, 'longline1');
    },
  );

  test(
    'callouts.md: callout body lines are not corrupted and still round-trip',
    () {
      final doc = load('callouts.md');
      // The wikilink inside the callout body is still found (callouts aren't
      // given special code-like treatment -- only fences/indented code are).
      expect(doc.allLinks, isNotEmpty);
      expect(
        doc.tasks,
        hasLength(1),
      ); // only the un-quoted task outside the callouts
    },
  );

  test(
    'unknown-task-markers.md: every custom marker char is preserved verbatim',
    () {
      final doc = load('unknown-task-markers.md');
      final unknown = doc.tasks
          .where((t) => t.task!.stateKind == TaskStateKind.unknown)
          .toList();
      expect(unknown.map((t) => t.task!.markerChar), ['?', '!', 'i']);
    },
  );
}
