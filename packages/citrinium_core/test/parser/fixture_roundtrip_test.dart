import 'dart:io';

import 'package:citrinium_core/parser.dart';
import 'package:citrinium_core/vault.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `docs/milestones/m0.md` exit criterion #2: "Parsing any fixture file and
/// re-serializing returns byte-identical output. Enforced as a property
/// test over a deliberately nasty fixture corpus."
///
/// This exercises the full pipeline end to end: W1's byte-preserving
/// `readVaultFile`/`writeVaultFileAtomic` (BOM, line endings, trailing
/// newline) composed with W2's `MarkdownDocument.parse` (whose `rawText`
/// *is* the serialization) -- over every hostile fixture from both W1 and
/// W2's corpora, since a real vault file goes through both layers.
void main() {
  final fixtureDirs = ['test/fixtures/vault', 'test/fixtures/parser'];
  final fixtureFiles = <File>[
    for (final dir in fixtureDirs)
      ...Directory(
        dir,
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.md')),
  ]..sort((a, b) => a.path.compareTo(b.path));

  group('round-trip byte-identity over the full hostile fixture corpus', () {
    test(
      'the corpus is non-trivially sized (fixtures are actually being picked up)',
      () {
        expect(fixtureFiles.length, greaterThanOrEqualTo(15));
      },
    );

    for (final file in fixtureFiles) {
      test(
        '${p.relative(file.path)}: read -> parse -> rawText -> write is byte-identical',
        () async {
          final originalBytes = await file.readAsBytes();

          final contents = readVaultFileSync(file);
          final doc = MarkdownDocument.parse(contents.text);

          // The parser's "serialization" is exactly rawText: no separate
          // serialize() step, so this is really just confirming parsing
          // didn't (and structurally can't) touch the string.
          expect(
            doc.rawText,
            contents.text,
            reason: 'MarkdownDocument.rawText must equal its input exactly',
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'citrinium_parser_roundtrip_test',
          );
          addTearDown(() => tempDir.delete(recursive: true));
          final target = File(p.join(tempDir.path, p.basename(file.path)));
          await writeVaultFileAtomic(
            target,
            VaultFileContents(text: doc.rawText, hadBom: contents.hadBom),
          );

          final rewrittenBytes = await target.readAsBytes();
          expect(rewrittenBytes, equals(originalBytes));
        },
      );
    }
  });

  group('parsing never throws on any fixture', () {
    for (final file in fixtureFiles) {
      test('${p.relative(file.path)}: parses without throwing', () {
        final contents = readVaultFileSync(file);
        expect(() => MarkdownDocument.parse(contents.text), returnsNormally);
      });
    }
  });
}
