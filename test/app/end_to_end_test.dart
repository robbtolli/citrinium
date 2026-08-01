import 'dart:io';

import 'package:citrinium/app/citrinium_app.dart';
import 'package:citrinium/core/vault/vault_path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fakes `path_provider` (used by `openAppServices` for the index-db
/// location) to point at a temp directory instead of hitting real platform
/// channels, which aren't available under `flutter test`.
class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this._dir);

  final Directory _dir;

  @override
  Future<String?> getApplicationSupportPath() async => _dir.path;

  @override
  Future<String?> getTemporaryPath() async => _dir.path;
}

/// Waits for [condition] to become true, polling with real wall-clock
/// delays. Must be called from inside [WidgetTester.runAsync] -- the vault
/// watcher/index pipeline uses real `Timer`s (debounce) and a real
/// background `Isolate` (the full-scan rebuild), neither of which the
/// standard fake-async `flutter_test` binding advances on its own the way
/// it does for widget animations.
Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Reads a settings-screen `ListTile`'s `trailing` text given its `title`
/// text -- several rows there coincidentally share the same trailing value
/// in this test's fixture vault (2 documents, 2 entries), so `find.text`
/// alone can't disambiguate them.
String? _trailingTextOf(WidgetTester tester, String titleText) {
  final tile = tester.widget<ListTile>(find.widgetWithText(ListTile, titleText));
  return (tile.trailing as Text?)?.data;
}

/// End-to-end proof of every M0 exit criterion that's about the *running
/// app* rather than the core package in isolation: booting straight to the
/// document list for an already-chosen vault, opening the read-only raw
/// file view, the settings screen's stats + "Rebuild index" button, and
/// -- the star of the show -- exit criterion #5: editing a `.md` file
/// externally (plain `dart:io`, standing in for an external editor)
/// updates the already-running app's document list with no restart and no
/// app-initiated write in between.
///
/// Every test body runs inside [WidgetTester.runAsync]: real `Isolate`s and
/// `Timer`s (the index rebuild + file watcher) need the real event loop,
/// not `flutter_test`'s fake-clock zone.
void main() {
  late Directory vault;
  late Directory appSupport;

  setUp(() async {
    vault = await Directory.systemTemp.createTemp('citrinium_e2e_vault');
    appSupport = await Directory.systemTemp.createTemp(
      'citrinium_e2e_appsupport',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(appSupport);

    await File(
      p.join(vault.path, 'inbox.md'),
    ).writeAsString('- [ ] Buy milk\n- [x] Done thing\n');
    await File(
      p.join(vault.path, 'note.md'),
    ).writeAsString('# A Note\n\nSome body text.\n');
  });

  tearDown(() async {
    await vault.delete(recursive: true);
    await appSupport.delete(recursive: true);
  });

  Future<void> pumpAppWithVault(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'vaultPath': vault.path});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CitriniumApp(),
      ),
    );
    await tester.pump();
    await _waitUntil(tester, () {
      // Wait past the initial full-index-rebuild scan (an Isolate.run
      // round trip) rather than assuming a fixed number of pumps.
      return find.text('inbox.md · note').evaluate().isNotEmpty ||
          find.textContaining('Could not load documents').evaluate().isNotEmpty;
    });
  }

  testWidgets(
    'boots straight to the document list for an already-chosen vault',
    (tester) async {
      await tester.runAsync(() async {
        await pumpAppWithVault(tester);

        // "inbox.md" has no heading/frontmatter title, so it falls back to
        // showing its relative path as the tile's title too.
        expect(find.text('inbox.md'), findsOneWidget);
        expect(find.text('inbox.md · note'), findsOneWidget);
        // "note.md" has an H1 heading ("A Note"), used as its title.
        expect(find.text('A Note'), findsOneWidget);
        expect(find.text('note.md · note'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'opening a document shows its literal raw file content in live preview editor',
    (tester) async {
      await tester.runAsync(() async {
        await pumpAppWithVault(tester);

        await tester.tap(find.text('A Note'));
        await _waitUntil(
          tester,
          () => find.byType(EditableText).evaluate().isNotEmpty,
        );

        expect(find.byType(EditableText), findsOneWidget);
        expect(find.textContaining('Some body text.'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'settings screen shows index stats and rebuilds the index on demand',
    (tester) async {
      await tester.runAsync(() async {
        await pumpAppWithVault(tester);

        await tester.tap(find.byIcon(Icons.settings_outlined));
        await _waitUntil(
          tester,
          () => find.text(vault.path).evaluate().isNotEmpty,
        );

        expect(_trailingTextOf(tester, 'Documents indexed'), '2');
        expect(_trailingTextOf(tester, 'Entries indexed'), '2');
        expect(find.text(vault.path), findsOneWidget);

        await tester.tap(find.text('Rebuild index'));
        await tester.pump();
        await _waitUntil(
          tester,
          () => find.textContaining('Rebuilt index').evaluate().isNotEmpty,
        );

        expect(
          find.textContaining('Rebuilt index: 2 documents'),
          findsWidgets,
        );
      });
    },
  );

  testWidgets(
    'exit criterion #5: an external edit updates the running document list '
    'without restarting the app',
    (tester) async {
      await tester.runAsync(() async {
        await pumpAppWithVault(tester);
        expect(find.text('external.md · note'), findsNothing);

        // Not an app-initiated write: plain dart:io, standing in for "an
        // external editor" per the exit criterion's wording.
        await File(
          p.join(vault.path, 'external.md'),
        ).writeAsString('- [ ] added from outside the app\n');

        await _waitUntil(
          tester,
          () => find.text('external.md · note').evaluate().isNotEmpty,
        );

        expect(find.text('external.md · note'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'exit criterion #5: an external delete removes a document from the '
    'running list',
    (tester) async {
      await tester.runAsync(() async {
        await pumpAppWithVault(tester);
        expect(find.text('A Note'), findsOneWidget);

        await File(p.join(vault.path, 'note.md')).delete();

        await _waitUntil(
          tester,
          () => find.text('A Note').evaluate().isEmpty,
        );

        expect(find.text('A Note'), findsNothing);
      });
    },
  );
}
