import 'package:citrine/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Citrine Theme (A-01)', () {
    test('light theme uses Warm Paper, Deep Fountain-Pen Ink & Golden Citrine', () {
      final theme = buildCitrineTheme(Brightness.light);
      expect(theme.colorScheme.surface, const Color(0xFFFAF7F2));
      expect(theme.colorScheme.primary, const Color(0xFF1C2430));
      expect(theme.colorScheme.tertiary, const Color(0xFFD97706));
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFAF7F2));
    });

    test('dark theme uses Deep Slate-Obsidian, Parchment Ink & Citrine Gold', () {
      final theme = buildCitrineTheme(Brightness.dark);
      expect(theme.colorScheme.surface, const Color(0xFF11161F));
      expect(theme.colorScheme.primary, const Color(0xFFFBBF24));
      expect(theme.colorScheme.onSurface, const Color(0xFFF3F0E8));
      expect(theme.scaffoldBackgroundColor, const Color(0xFF11161F));
    });
  });
}
