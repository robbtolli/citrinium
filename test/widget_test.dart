import 'package:citrine/app/citrine_app.dart';
import 'package:citrine/core/vault/vault_path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'a fresh install boots to the first-launch intro screen with 4 pillars & 3 vault options',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const CitrineApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Header & welcome
      expect(find.text('Welcome to Citrine'), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);

      // The 4 Main Areas / Pillars
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Actions & Inbox'), findsOneWidget);
      expect(find.text('Horizons & Review'), findsOneWidget);
      expect(find.text('Notes & Index'), findsOneWidget);

      // The 3 Entry Action Buttons
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Open an existing Vault'), findsOneWidget);
      expect(find.text('Create a blank vault'), findsOneWidget);

      // Test "Create a blank vault" dialog prompt
      await tester.ensureVisible(find.text('Create a blank vault'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create a blank vault'));
      await tester.pumpAndSettle();

      expect(find.text('Vault folder name'), findsOneWidget);
      expect(find.text('Choose Location & Create'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Create a blank vault'), findsOneWidget);
    },
  );
}
