import 'package:citrinium/app/citrinium_app.dart';
import 'package:citrinium/core/vault/vault_path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `docs/milestones/m0.md` W6: "one widget smoke test: app boots to vault
/// picker." `SharedPreferences.setMockInitialValues({})` means no vault
/// path has ever been persisted, so `goRouterProvider`'s redirect sends a
/// fresh app straight to `/vault-setup`.
void main() {
  testWidgets('a fresh install boots to the vault picker', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const CitriniumApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Citrinium'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
