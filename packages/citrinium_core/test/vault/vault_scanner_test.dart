import 'dart:io';

import 'package:citrinium_core/vault.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<void> _write(String path, String content) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}

void main() {
  group('VaultScanner', () {
    late Directory vault;

    setUp(() async {
      vault = await Directory.systemTemp.createTemp('citrinium_scanner_test');
    });

    tearDown(() async {
      await vault.delete(recursive: true);
    });

    Set<String> relPaths(VaultScanResult result) => result.files.map((f) => f.path.value).toSet();

    test('finds top-level and nested .md files', () async {
      await _write(p.join(vault.path, 'inbox.md'), '# Inbox\n');
      await _write(p.join(vault.path, 'Projects', 'citrinium.md'), '# Citrinium\n');
      await _write(p.join(vault.path, 'Projects', 'Nested', 'deep.md'), '# Deep\n');

      final result = await const VaultScanner().scan(vault.path);

      expect(relPaths(result), {
        'inbox.md',
        'Projects/citrinium.md',
        'Projects/Nested/deep.md',
      });
    });

    test('ignores .git, .obsidian, .citrinium, .trash, and node_modules', () async {
      await _write(p.join(vault.path, 'note.md'), '# Note\n');
      await _write(p.join(vault.path, '.git', 'HEAD'), 'ref: refs/heads/main\n');
      await _write(p.join(vault.path, '.obsidian', 'workspace.md'), '{}');
      await _write(p.join(vault.path, '.citrinium', 'config.md'), 'citrinium: {}');
      await _write(p.join(vault.path, '.trash', 'deleted.md'), '# Deleted\n');
      await _write(p.join(vault.path, 'node_modules', 'pkg', 'readme.md'), '# Readme\n');

      final result = await const VaultScanner().scan(vault.path);

      expect(relPaths(result), {'note.md'});
      expect(result.skipped, isEmpty);
    });

    test('ignores dotfiles generically, including hidden .md files', () async {
      await _write(p.join(vault.path, 'note.md'), '# Note\n');
      await _write(p.join(vault.path, '.hidden.md'), '# Hidden\n');
      await _write(p.join(vault.path, '.config', 'note.md'), '# Config note\n');

      final result = await const VaultScanner().scan(vault.path);

      expect(relPaths(result), {'note.md'});
    });

    test('ignores non-markdown files', () async {
      await _write(p.join(vault.path, 'note.md'), '# Note\n');
      await _write(p.join(vault.path, 'image.png'), 'not really a png');

      final result = await const VaultScanner().scan(vault.path);

      expect(relPaths(result), {'note.md'});
    });

    test('skips files over the size cap and reports why', () async {
      await _write(p.join(vault.path, 'small.md'), '# Small\n');
      await _write(p.join(vault.path, 'big.md'), 'x' * 100);

      final result = await VaultScanner(
        options: const VaultScanOptions(maxFileSizeBytes: 50),
      ).scan(vault.path);

      expect(relPaths(result), {'small.md'});
      expect(result.skipped, hasLength(1));
      expect(result.skipped.single.path, VaultPath('big.md'));
      expect(result.skipped.single.reason, VaultScanSkipReason.tooLarge);
    });

    test('does not follow symlinks by default, and reports why', () async {
      await _write(p.join(vault.path, 'real.md'), '# Real\n');
      final link = Link(p.join(vault.path, 'linked.md'));
      await link.create(p.join(vault.path, 'real.md'));

      final result = await const VaultScanner().scan(vault.path);

      expect(relPaths(result), {'real.md'});
      expect(result.skipped, hasLength(1));
      expect(result.skipped.single.path, VaultPath('linked.md'));
      expect(result.skipped.single.reason, VaultScanSkipReason.symlinkNotFollowed);
    }, testOn: '!windows');

    test('follows symlinks when opted in', () async {
      await _write(p.join(vault.path, 'Target', 'real.md'), '# Real\n');
      final link = Link(p.join(vault.path, 'linked.md'));
      await link.create(p.join(vault.path, 'Target', 'real.md'));

      final result = await VaultScanner(
        options: const VaultScanOptions(followSymlinks: true),
      ).scan(vault.path);

      expect(relPaths(result), {'Target/real.md', 'linked.md'});
    }, testOn: '!windows');

    test('NFC- and NFD-named files resolve to equal VaultPaths', () async {
      const nfcName = 'Café.md';
      final nfdName = toNfd(nfcName);
      await _write(p.join(vault.path, nfdName), '# Café\n');

      final result = await const VaultScanner().scan(vault.path);

      expect(result.files, hasLength(1));
      expect(result.files.single.path, equals(VaultPath(nfcName)));
    });

    test('an empty vault yields no files and no skips', () async {
      final result = await const VaultScanner().scan(vault.path);
      expect(result.files, isEmpty);
      expect(result.skipped, isEmpty);
    });
  });
}
