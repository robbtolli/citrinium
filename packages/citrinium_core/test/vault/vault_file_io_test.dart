import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:citrinium_core/vault.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// `dart test` runs with the package root as the working directory, so
// fixtures can be located relative to it.
const String _fixturesDir = 'test/fixtures/vault';

void main() {
  group('readVaultFile / fixture round-trips', () {
    for (final fixture in const [
      'crlf.md',
      'bom.md',
      'no-trailing-newline.md',
      'mixed-line-endings.md',
      'lf.md',
    ]) {
      test('$fixture reads and writes back byte-identical', () async {
        final source = File(p.join(_fixturesDir, fixture));
        final originalBytes = await source.readAsBytes();

        final contents = await readVaultFile(source);

        final tempDir = await Directory.systemTemp.createTemp('citrinium_vault_io_test');
        addTearDown(() => tempDir.delete(recursive: true));
        final target = File(p.join(tempDir.path, fixture));

        await writeVaultFileAtomic(target, contents);

        final rewrittenBytes = await target.readAsBytes();
        expect(rewrittenBytes, equals(originalBytes));
      });
    }

    test('bom.md is detected as having a BOM and its text excludes it', () async {
      final contents = await readVaultFile(File(p.join(_fixturesDir, 'bom.md')));
      expect(contents.hadBom, isTrue);
      expect(contents.text, startsWith('# BOM fixture'));
      expect(contents.text.codeUnitAt(0), isNot(0xFEFF));
    });

    test('crlf.md preserves \\r\\n in the decoded text', () async {
      final contents = await readVaultFile(File(p.join(_fixturesDir, 'crlf.md')));
      expect(contents.hadBom, isFalse);
      expect(contents.text, contains('\r\n'));
      expect(detectLineEndingStyle(contents.text), LineEndingStyle.crlf);
    });

    test('mixed-line-endings.md is detected as mixed', () async {
      final contents = await readVaultFile(File(p.join(_fixturesDir, 'mixed-line-endings.md')));
      expect(detectLineEndingStyle(contents.text), LineEndingStyle.mixed);
    });

    test('no-trailing-newline.md round-trips without gaining a newline', () async {
      final contents = await readVaultFile(File(p.join(_fixturesDir, 'no-trailing-newline.md')));
      expect(hasTrailingNewline(contents.text), isFalse);
      expect(contents.text, endsWith('newline'));
    });

    test('lf.md is detected as lf with a trailing newline', () async {
      final contents = await readVaultFile(File(p.join(_fixturesDir, 'lf.md')));
      expect(detectLineEndingStyle(contents.text), LineEndingStyle.lf);
      expect(hasTrailingNewline(contents.text), isTrue);
    });
  });

  group('writeVaultFileAtomic', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('citrinium_vault_io_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('writes content without a BOM by default', () async {
      final target = File(p.join(tempDir.path, 'note.md'));
      await writeVaultFileAtomic(target, const VaultFileContents(text: 'hello\n', hadBom: false));

      final bytes = await target.readAsBytes();
      expect(bytes, equals(utf8.encode('hello\n')));
    });

    test('writes a BOM when requested', () async {
      final target = File(p.join(tempDir.path, 'note.md'));
      await writeVaultFileAtomic(target, const VaultFileContents(text: 'hello\n', hadBom: true));

      final bytes = await target.readAsBytes();
      expect(bytes.sublist(0, 3), equals([0xEF, 0xBB, 0xBF]));
      expect(utf8.decode(bytes.sublist(3)), 'hello\n');
    });

    test('overwrites existing content atomically and leaves no temp files behind', () async {
      final target = File(p.join(tempDir.path, 'note.md'));
      await writeVaultFileAtomic(target, const VaultFileContents(text: 'first\n', hadBom: false));
      await writeVaultFileAtomic(target, const VaultFileContents(text: 'second\n', hadBom: false));

      expect(await target.readAsString(), 'second\n');

      final leftovers = await tempDir
          .list()
          .where((e) => p.basename(e.path) != 'note.md')
          .toList();
      expect(leftovers, isEmpty);
    });

    test('a mutation-locality edit changes only the expected byte range', () async {
      // Simulates a single-line task-state edit: flip "[ ]" to "[x]" via a
      // splice, then confirm the prefix/suffix bytes are untouched -- the
      // property W2's edit API depends on, exercised here at the file-I/O
      // boundary rather than through the (not-yet-built) parser.
      final target = File(p.join(tempDir.path, 'task.md'));
      const original = '# Tasks\n\n- [ ] one\n- [ ] two\n- [ ] three\n';
      await writeVaultFileAtomic(target, const VaultFileContents(text: original, hadBom: false));

      final idx = original.indexOf('- [ ] two');
      final spliceStart = idx + 3; // just after "- ["
      final edited = original.replaceRange(spliceStart, spliceStart + 1, 'x');

      await writeVaultFileAtomic(target, VaultFileContents(text: edited, hadBom: false));

      final rewritten = await target.readAsString();
      expect(rewritten.substring(0, spliceStart), original.substring(0, spliceStart));
      expect(
        rewritten.substring(spliceStart + 1),
        original.substring(spliceStart + 1),
      );
      expect(rewritten, contains('- [x] two'));
    });
  });

  group('VaultFileDecodeException', () {
    test('is thrown for invalid UTF-8 bytes', () async {
      final tempDir = await Directory.systemTemp.createTemp('citrinium_vault_io_test');
      addTearDown(() => tempDir.delete(recursive: true));
      final target = File(p.join(tempDir.path, 'bad.md'));
      await target.writeAsBytes(Uint8List.fromList([0xFF, 0xFE, 0x00, 0x80]));

      await expectLater(readVaultFile(target), throwsA(isA<VaultFileDecodeException>()));
    });
  });
}
