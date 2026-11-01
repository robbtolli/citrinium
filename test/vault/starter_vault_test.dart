import 'dart:io';

import 'package:citrine/core/vault/starter_vault_seeder.dart';
import 'package:citrine/core/vault/vault_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('StarterVaultSeeder', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('citrine_starter_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('seeds all curriculum files with rich, non-filler content', () async {
      final now = DateTime(2026, 10, 31, 10, 30);
      final taskKey = await StarterVaultSeeder.seedStarterVault(
        tempDir.path,
        now: now,
      );

      expect(taskKey, isNotNull);
      expect(taskKey, startsWith('daily/2026-10-31.md:'));

      // Check daily log
      final dailyFile = File(p.join(tempDir.path, 'daily', '2026-10-31.md'));
      expect(await dailyFile.exists(), isTrue);
      final dailyContent = await dailyFile.readAsString();
      expect(dailyContent, contains('citrine.type: daily'));
      expect(dailyContent, contains('Tap this task to edit it in-place'));
      expect(dailyContent, contains('#habit 🔁 daily'));
      expect(dailyContent, contains('- ○ Welcome to Citrine'));
      expect(dailyContent, contains('[[guides/getting-started]]'));

      // Check inbox
      final inboxFile = File(p.join(tempDir.path, 'inbox.md'));
      expect(await inboxFile.exists(), isTrue);
      final inboxContent = await inboxFile.readAsString();
      expect(inboxContent, contains('citrine.type: inbox'));
      expect(inboxContent, contains('Practice GTD Clarify'));

      // Check project
      final projectFile = File(
        p.join(tempDir.path, 'projects', 'setup-personal-workflow.md'),
      );
      expect(await projectFile.exists(), isTrue);
      final projectContent = await projectFile.readAsString();
      expect(projectContent, contains('citrine.type: project'));
      expect(
        projectContent,
        contains('outcome: Have a calm, trusted place for my daily tasks and notes'),
      );

      // Check weekly log
      final weeklyFile = File(p.join(tempDir.path, 'weekly', '2026-W44.md'));
      expect(await weeklyFile.exists(), isTrue);

      // Check future log
      final futureFile = File(p.join(tempDir.path, 'future.md'));
      expect(await futureFile.exists(), isTrue);

      // Check collection
      final collectionFile = File(
        p.join(tempDir.path, 'collections', 'books-media-and-ideas.md'),
      );
      expect(await collectionFile.exists(), isTrue);
      expect(
        await collectionFile.readAsString(),
        contains('citrine.type: collection'),
      );

      // Check reference and guides
      expect(await File(p.join(tempDir.path, 'reference.md')).exists(), isTrue);
      expect(
        await File(p.join(tempDir.path, 'guides', 'getting-started.md')).exists(),
        isTrue,
      );
      expect(
        await File(p.join(tempDir.path, 'guides', 'bujo-and-gtd-guide.md')).exists(),
        isTrue,
      );
      expect(
        await File(p.join(tempDir.path, 'guides', 'markdown-cheatsheet.md')).exists(),
        isTrue,
      );
    });

    test('never overwrites existing user files', () async {
      final now = DateTime(2026, 10, 31);
      final dailyFile = File(
        p.join(tempDir.path, 'daily', '2026-10-31.md'),
      );
      await dailyFile.parent.create(recursive: true);
      await dailyFile.writeAsString('CUSTOM USER LOG');

      await StarterVaultSeeder.seedStarterVault(tempDir.path, now: now);

      expect(await dailyFile.readAsString(), 'CUSTOM USER LOG');
    });

    test('seedGuidesOnly seeds only guides and reference', () async {
      await StarterVaultSeeder.seedGuidesOnly(tempDir.path);

      expect(await File(p.join(tempDir.path, 'reference.md')).exists(), isTrue);
      expect(
        await File(p.join(tempDir.path, 'guides', 'getting-started.md')).exists(),
        isTrue,
      );
      expect(await File(p.join(tempDir.path, 'inbox.md')).exists(), isFalse);
    });
  });

  group('VaultSetup helpers', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('citrine_setup_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('createNamedVaultInDirectory creates named subdirectory', () async {
      final path = await createNamedVaultInDirectory(
        parentDirectoryPath: tempDir.path,
        vaultName: 'my-personal-vault',
      );

      expect(path, p.join(tempDir.path, 'my-personal-vault'));
      expect(await Directory(path).exists(), isTrue);
    });

    test('createNamedVaultInDirectory rejects invalid names', () async {
      expect(
        () => createNamedVaultInDirectory(
          parentDirectoryPath: tempDir.path,
          vaultName: '',
        ),
        throwsArgumentError,
      );
      expect(
        () => createNamedVaultInDirectory(
          parentDirectoryPath: tempDir.path,
          vaultName: '../escape',
        ),
        throwsArgumentError,
      );
      expect(
        () => createNamedVaultInDirectory(
          parentDirectoryPath: tempDir.path,
          vaultName: 'sub/folder',
        ),
        throwsArgumentError,
      );
    });

    test('resolveDefaultStarterVaultPath returns valid directory path', () async {
      final defaultPath = await resolveDefaultStarterVaultPath();
      expect(defaultPath.isNotEmpty, isTrue);
      expect(
        defaultPath.endsWith('citrine') || defaultPath.endsWith('vault'),
        isTrue,
      );
    });
  });
}
