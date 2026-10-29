import 'package:citrinium_core/citrinium_core.dart';
import 'package:test/test.dart';

void main() {
  group('EntryHierarchy & Child Note/Comment Block (W1, W7, D-01, D-14, D-18)', () {
    test('groups single-level indented note body and comments beneath parent entry', () {
      const md = '''
# Daily Log

- [ ] Call pharmacy @phone
  Ask about refill status
  Bring prescription number #health
- ○ Team sync ⏰14:00
  Agenda:
    - Q4 roadmap
- – Idea for garden layout
''';

      final doc = MarkdownDocument.parse(md);
      final grouped = EntryHierarchy.groupDocumentEntries(
        doc,
        documentId: 1,
        relPath: 'daily/2026-10-29.md',
      );

      expect(grouped, hasLength(3));

      expect(grouped[0].kind, DomainEntryKind.task);
      expect(grouped[0].hasChildren, isTrue);
      expect(
        grouped[0].childBodyText,
        'Ask about refill status\nBring prescription number #health',
      );

      expect(grouped[1].kind, DomainEntryKind.event);
      expect(grouped[1].hasChildren, isTrue);
      // Single-level nesting rule: strips the 2-column child indent while
      // keeping deeper relative indentation inside the child block intact.
      expect(
        grouped[1].childBodyText,
        'Agenda:\n  - Q4 roadmap',
      );

      expect(grouped[2].kind, DomainEntryKind.note);
      expect(grouped[2].hasChildren, isFalse);
      expect(grouped[2].childBodyText, '');
    });

    test('handles mixed tab and space indentation for child note blocks', () {
      const md = '- [ ] Parent task\n\tIndented with tab\n  Indented with two spaces\n- [ ] Sibling task\n';
      final doc = MarkdownDocument.parse(md);

      expect(
        doc.readChildBlockText(0),
        'Indented with tab\nIndented with two spaces',
      );
      expect(doc.readChildBlockText(3), '');
    });

    test('replaceChildBlockText inserts, updates, and removes child note blocks byte-stably', () {
      const initial = '- [ ] Buy groceries @errands\n- [ ] Call dentist\n';
      final doc0 = MarkdownDocument.parse(initial);

      // 1. Insert new indented note body beneath line 0
      final doc1 = doc0.replaceChildBlockText(0, 'Milk, eggs, bread\nUse coupon');
      expect(
        doc1.rawText,
        '- [ ] Buy groceries @errands\n  Milk, eggs, bread\n  Use coupon\n- [ ] Call dentist\n',
      );

      // 2. Update existing indented note body beneath line 0
      final doc2 = doc1.replaceChildBlockText(0, 'Just oat milk');
      expect(
        doc2.rawText,
        '- [ ] Buy groceries @errands\n  Just oat milk\n- [ ] Call dentist\n',
      );

      // 3. Remove indented note body when empty string is passed
      final doc3 = doc2.replaceChildBlockText(0, '');
      expect(doc3.rawText, initial);
    });

    test('rematchEntry preserves identity across line insertions above entry', () {
      const before = '- [ ] Target task\n  Important detail\n';
      const after = '- [ ] Newly inserted task above\n- [ ] Target task\n  Important detail\n';

      final groupedBefore = EntryHierarchy.groupDocumentEntries(
        MarkdownDocument.parse(before),
      );
      final groupedAfter = EntryHierarchy.groupDocumentEntries(
        MarkdownDocument.parse(after),
      );

      final rematched = EntryHierarchy.rematchEntry(
        groupedAfter,
        previousLineIndex: groupedBefore.first.lineIndex,
        previousContentHash: groupedBefore.first.contentHash,
      );

      expect(rematched, isNotNull);
      expect(rematched!.lineIndex, 1);
      expect(rematched.contentHash, groupedBefore.first.contentHash);
    });
  });
}
