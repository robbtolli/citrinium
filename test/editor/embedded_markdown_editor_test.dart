import 'dart:io';

import 'package:citrine/core/vault/vault_path_provider.dart';
import 'package:citrine/shared/widgets/embedded_markdown_editor.dart';
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

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late Directory vault;
  late Directory appSupport;

  setUp(() async {
    vault = await Directory.systemTemp.createTemp('citrine_embed_editor_vault');
    appSupport = await Directory.systemTemp.createTemp(
      'citrine_embed_editor_appsupport',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(appSupport);
  });

  tearDown(() async {
    await vault.delete(recursive: true);
    await appSupport.delete(recursive: true);
  });

  testWidgets(
    'EmbeddedMarkdownEditor keeps typed text after debounced save and index refresh',
    timeout: const Timeout(Duration(seconds: 15)),
    (tester) async {
      await tester.runAsync(() async {
        const relPath = 'daily/2026-11-15.md';
        final initialContent = CadenceFiles.defaultContentForCadence(
          CadenceKind.daily,
          DateTime(2026, 11, 15),
        );
        final dailyFile = File(p.join(vault.path, relPath));
        await dailyFile.parent.create(recursive: true);
        await dailyFile.writeAsString(initialContent);

        SharedPreferences.setMockInitialValues({'vaultPath': vault.path});
        final prefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: EmbeddedMarkdownEditor(
                    relPath: relPath,
                    shrinkWrap: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Wait for the interleaved tail segment's EditableText to mount.
        await _waitUntil(
          tester,
          () => find.byType(EditableText).evaluate().isNotEmpty,
        );

        final editableFinder = find.byType(EditableText).last;
        final editable = tester.widget<EditableText>(editableFinder);
        final originalSegmentText = editable.controller.text;
        const typedSuffix = 'Remember to buy coffee';

        // Simulate typing into the daily note tail segment.
        editable.controller.value = TextEditingValue(
          text: '$originalSegmentText$typedSuffix',
          selection: TextSelection.collapsed(
            offset: originalSegmentText.length + typedSuffix.length,
          ),
        );
        await tester.pump();

        // Wait past the 800ms save debounce and allow index refresh + rebuilds.
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        // Typed text must remain in the editor AND be persisted on disk.
        expect(
          tester.widget<EditableText>(editableFinder).controller.text,
          contains(typedSuffix),
        );
        expect(await dailyFile.readAsString(), contains(typedSuffix));
      });
    },
  );
}
