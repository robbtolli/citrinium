import 'dart:io';

import 'package:citrinium_core/parser.dart';
import 'package:citrinium_core/vault.dart';
import 'package:test/test.dart';

/// `docs/milestones/m0.md` exit criterion #3: "A single-line edit (e.g.
/// task state change) provably alters only the expected byte range,"
/// exercised here as a property over every task line in the fixture
/// corpus, not just a single hand-picked example.
void main() {
  final fixtureFiles =
      Directory('test/fixtures/parser')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  group('setTaskState mutation locality across the whole fixture corpus', () {
    for (final file in fixtureFiles) {
      final contents = readVaultFileSync(file);
      final doc = MarkdownDocument.parse(contents.text);
      final taskIndices = [
        for (var i = 0; i < doc.lines.length; i++)
          if (doc.lines[i].kind == LineKind.task) i,
      ];

      if (taskIndices.isEmpty) continue;

      for (final lineIndex in taskIndices) {
        test('${file.path} line $lineIndex: only its marker char changes', () {
          final original = doc.rawText;
          final markerSpan = doc.lines[lineIndex].task!.markerSpan;

          final edited = doc.setTaskState(lineIndex, TaskStateKind.completed);

          expect(
            edited.rawText.length,
            original.length,
            reason: 'setTaskState must not change document length',
          );
          expect(
            edited.rawText.substring(0, markerSpan.start),
            original.substring(0, markerSpan.start),
          );
          expect(
            edited.rawText.substring(markerSpan.end),
            original.substring(markerSpan.end),
          );
          expect(
            edited.rawText.substring(markerSpan.start, markerSpan.end),
            'x',
          );
        });
      }
    }
  });

  group('appendLine mutation locality across the whole fixture corpus', () {
    for (final file in fixtureFiles) {
      test('${file.path}: appendLine never touches existing bytes', () {
        final contents = readVaultFileSync(file);
        final doc = MarkdownDocument.parse(contents.text);
        final original = doc.rawText;

        final edited = doc.appendLine('- [ ] appended by property test');

        expect(edited.rawText, startsWith(original));
      });
    }
  });
}
