import 'dart:async';
import 'dart:io';

import 'package:citrine/app/citrine_app.dart';
import 'package:citrine/core/background/background_work_manager.dart';
import 'package:citrine/core/vault/vault_path_provider.dart';
import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this._dir);

  final Directory _dir;

  @override
  Future<String?> getApplicationSupportPath() async => _dir.path;

  @override
  Future<String?> getTemporaryPath() async => _dir.path;
}

void main() {
  group('Data Ownership & Background Work Manager (M16 — FR-16, T-02)', () {
    late Directory tempDir;
    late Directory supportDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('citrine_m16_test_');
      supportDir = await Directory.systemTemp.createTemp('citrine_m16_sup_');
      PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir);
      await Directory(p.join(tempDir.path, 'daily')).create(recursive: true);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      if (await supportDir.exists()) {
        await supportDir.delete(recursive: true);
      }
    });

    testWidgets(
      'External untagged task banner imports on Yes and dismisses on No',
      (tester) async {
        await tester.runAsync(() async {
          SharedPreferences.setMockInitialValues({'vaultPath': tempDir.path});
          final prefs = await SharedPreferences.getInstance();
          final container = ProviderContainer(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          );
          addTearDown(container.dispose);
          final externalFile = File(p.join(tempDir.path, 'external.md'));
          await externalFile.writeAsString('- [ ] External task one\n');

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const CitrineApp(),
            ),
          );
          for (var i = 0; i < 20; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 25));
            await tester.pump();
          }
          container
              .read(externalUntaggedTasksProvider.notifier)
              .addPendingFiles(['external.md']);
          await tester.pump();

          expect(
            find.textContaining(
              'Citrine has detected new markdown files in the vault that contain tasks.',
            ),
            findsOneWidget,
          );

          // Tapping No dismisses without modifying the file
          await tester.tap(find.text('No'));
          await tester.pump();
          expect(
            find.textContaining(
              'Citrine has detected new markdown files in the vault that contain tasks.',
            ),
            findsNothing,
          );
          expect(
            citrineTaskCommentRegExp.hasMatch(await externalFile.readAsString()),
            isFalse,
          );

          // Re-trigger and tap Yes -> imports & tags file
          container
              .read(externalUntaggedTasksProvider.notifier)
              .addPendingFiles(['external.md']);
          await tester.pump();
          await tester.tap(find.text('Yes'));
          for (var i = 0; i < 20; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 25));
            await tester.pump();
          }

          final updatedText = await externalFile.readAsString();
          expect(citrineTaskCommentRegExp.hasMatch(updatedText), isTrue);
        });
      },
    );

    testWidgets(
      'BackgroundWorkManager shows unobtrusive progress bar while running',
      (tester) async {
        await tester.runAsync(() async {
          SharedPreferences.setMockInitialValues({'vaultPath': tempDir.path});
          final prefs = await SharedPreferences.getInstance();
          final container = ProviderContainer(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const CitrineApp(),
            ),
          );
          for (var i = 0; i < 15; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await tester.pump();
          }
          final completer = Completer<void>();
          final future = container
              .read(backgroundWorkManagerProvider.notifier)
              .runTask<void>(
                label: 'Importing tasks...',
                totalUnits: 2,
                work: (reportProgress) async {
                  reportProgress(1, 2);
                  await completer.future;
                },
              );
          await tester.pump();

          expect(find.byType(LinearProgressIndicator), findsOneWidget);
          expect(find.text('Importing tasks...'), findsOneWidget);

          completer.complete();
          await future;
          await tester.pump();

          expect(find.text('Importing tasks...'), findsNothing);
        });
      },
    );

    testWidgets(
      'Snapshot export dialog displays static snapshot notice and writes .md file',
      (tester) async {
        await tester.runAsync(() async {
          SharedPreferences.setMockInitialValues({'vaultPath': tempDir.path});
          final prefs = await SharedPreferences.getInstance();
          final container = ProviderContainer(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          );
          addTearDown(container.dispose);
          final now = DateTime.now();
          final todayIso = NlDateParser.formatIsoDate(now);
          final dailyFile = File(p.join(tempDir.path, 'daily', '$todayIso.md'));
          await dailyFile.writeAsString(
            '# $todayIso\n- [ ] Snapshot item 📅 $todayIso\n\n```citrine\nview: dueToday\n```\n',
          );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const CitrineApp(),
            ),
          );
          for (var i = 0; i < 25; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 25));
            await tester.pump();
          }

          final exportButtons = find.byTooltip('Export Static Snapshot (.md)');
          expect(exportButtons, findsWidgets);
          await tester.ensureVisible(exportButtons.first);
          await tester.pump();
          await tester.tap(exportButtons.first);
          await tester.pump();

          expect(
            find.textContaining('static snapshots of the current data'),
            findsOneWidget,
          );
          await tester.tap(find.text('Export Snapshot'));
          for (var i = 0; i < 15; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await tester.pump();
          }

          final exportsDir = Directory(p.join(tempDir.path, 'exports'));
          expect(await exportsDir.exists(), isTrue);
          final files = exportsDir.listSync().whereType<File>().toList();
          expect(files, isNotEmpty);
          final exportedText = await files.first.readAsString();
          expect(exportedText, contains('Static snapshot generated by Citrine'));
          expect(exportedText, contains('Snapshot item'));
        });
      },
    );
  });
}
