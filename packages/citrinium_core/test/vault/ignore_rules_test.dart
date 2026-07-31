import 'package:citrinium_core/vault.dart';
import 'package:test/test.dart';

void main() {
  group('isIgnoredName', () {
    test('dotfiles/dotdirs are ignored', () {
      expect(isIgnoredName('.git'), isTrue);
      expect(isIgnoredName('.obsidian'), isTrue);
      expect(isIgnoredName('.citrinium'), isTrue);
      expect(isIgnoredName('.trash'), isTrue);
      expect(isIgnoredName('.DS_Store'), isTrue);
      expect(isIgnoredName('.hidden.md'), isTrue);
    });

    test('node_modules is ignored despite not being a dotdir', () {
      expect(isIgnoredName('node_modules'), isTrue);
    });

    test('ordinary names are not ignored', () {
      expect(isIgnoredName('Notes'), isFalse);
      expect(isIgnoredName('todo.md'), isFalse);
    });

    test('custom ignoredDirNames are respected', () {
      expect(isIgnoredName('build', ignoredDirNames: {'build'}), isTrue);
      expect(isIgnoredName('node_modules', ignoredDirNames: {'build'}), isFalse);
    });
  });

  group('isMarkdownFileName', () {
    test('accepts .md case-insensitively', () {
      expect(isMarkdownFileName('a.md'), isTrue);
      expect(isMarkdownFileName('A.MD'), isTrue);
    });

    test('rejects non-.md files', () {
      expect(isMarkdownFileName('a.png'), isFalse);
      expect(isMarkdownFileName('a.markdown'), isFalse);
    });
  });

  group('isTrackedVaultPath', () {
    test('a plain top-level note is tracked', () {
      expect(isTrackedVaultPath(VaultPath('note.md')), isTrue);
    });

    test('a note nested under a normal directory is tracked', () {
      expect(isTrackedVaultPath(VaultPath('Projects/note.md')), isTrue);
    });

    test('files under an ignored ancestor directory are not tracked', () {
      expect(isTrackedVaultPath(VaultPath('.obsidian/workspace.md')), isFalse);
      expect(isTrackedVaultPath(VaultPath('.git/COMMIT_EDITMSG.md')), isFalse);
      expect(isTrackedVaultPath(VaultPath('.citrinium/config.md')), isFalse);
      expect(isTrackedVaultPath(VaultPath('.trash/deleted.md')), isFalse);
      expect(isTrackedVaultPath(VaultPath('node_modules/pkg/readme.md')), isFalse);
      expect(isTrackedVaultPath(VaultPath('Projects/.git/note.md')), isFalse);
    });

    test('a hidden file itself is not tracked', () {
      expect(isTrackedVaultPath(VaultPath('.hidden.md')), isFalse);
    });

    test('non-markdown files are not tracked', () {
      expect(isTrackedVaultPath(VaultPath('image.png')), isFalse);
    });
  });
}
