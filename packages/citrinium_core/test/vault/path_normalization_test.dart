import 'package:citrinium_core/vault.dart';
import 'package:test/test.dart';

void main() {
  group('toNfc/toNfd', () {
    test('NFC and NFD forms of the same visible string normalize to NFC', () {
      const nfc = 'Café'; // U+00E9 (composed é)
      final nfd = toNfd(nfc); // decomposes to e + combining acute

      expect(nfc.codeUnits, isNot(equals(nfd.codeUnits)));
      expect(toNfc(nfd), equals(nfc));
      expect(toNfc(nfc), equals(nfc));
    });
  });

  group('VaultPath', () {
    test('NFC and NFD variants of the same path are equal', () {
      const nfc = 'Notes/Café.md';
      final nfd = toNfd(nfc);

      expect(VaultPath(nfc), equals(VaultPath(nfd)));
      expect(VaultPath(nfc).hashCode, equals(VaultPath(nfd).hashCode));
    });

    test('backslash separators are normalized to forward slashes', () {
      expect(VaultPath(r'Projects\Home\todo.md'), equals(VaultPath('Projects/Home/todo.md')));
    });

    test('leading slash and dot segments are normalized away', () {
      expect(VaultPath('/Notes/./a.md'), equals(VaultPath('Notes/a.md')));
    });

    test('segments, fileName, and directorySegments', () {
      final path = VaultPath('Projects/Home/todo.md');
      expect(path.segments, ['Projects', 'Home', 'todo.md']);
      expect(path.fileName, 'todo.md');
      expect(path.directorySegments, ['Projects', 'Home']);
    });

    test('root-level file has no directory segments', () {
      final path = VaultPath('todo.md');
      expect(path.segments, ['todo.md']);
      expect(path.fileName, 'todo.md');
      expect(path.directorySegments, isEmpty);
    });

    test('fromAbsolute computes a normalized relative path', () {
      final path = VaultPath.fromAbsolute('/vault', '/vault/Notes/a.md');
      expect(path, equals(VaultPath('Notes/a.md')));
    });

    test('toAbsolute round-trips against the vault root', () {
      final path = VaultPath('Notes/a.md');
      expect(path.toAbsolute('/vault'), '/vault/Notes/a.md');
    });

    test('toString returns the canonical value', () {
      expect(VaultPath('Notes/a.md').toString(), 'Notes/a.md');
    });
  });
}
