import 'package:flutter/material.dart';

/// Warm Paper, Deep Fountain-Pen Ink & Golden Citrine theming (`A-01`).
///
/// Replaces Material 3's olive-tinted seed generation with explicit, high-craft
/// light (warm ivory paper + deep ink + citrine highlights) and dark
/// (deep slate-obsidian + parchment text + luminous gold) palettes.
ThemeData buildCitrineTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final colorScheme = isDark
      ? const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFFFBBF24), // Luminous Citrine Gold
          onPrimary: Color(0xFF1C1502),
          primaryContainer: Color(0xFF3E300B),
          onPrimaryContainer: Color(0xFFFDE68A),
          secondary: Color(0xFF93C5FD), // Soft Fountain-Pen Blue
          onSecondary: Color(0xFF0C1A2E),
          secondaryContainer: Color(0xFF1E304A),
          onSecondaryContainer: Color(0xFFDBEAFE),
          tertiary: Color(0xFFF59E0B),
          onTertiary: Color(0xFF1C1202),
          tertiaryContainer: Color(0xFF452905),
          onTertiaryContainer: Color(0xFFFEF3C7),
          error: Color(0xFFF87171),
          onError: Color(0xFF2B0A0A),
          errorContainer: Color(0xFF5B1717),
          onErrorContainer: Color(0xFFFEE2E2),
          surface: Color(0xFF11161F), // Deep Slate-Obsidian Ink
          onSurface: Color(0xFFF3F0E8), // Soft Parchment Text
          onSurfaceVariant: Color(0xFFA8B2C1),
          surfaceContainerLowest: Color(0xFF0D1118),
          surfaceContainerLow: Color(0xFF161D29),
          surfaceContainer: Color(0xFF1C2433),
          surfaceContainerHigh: Color(0xFF242E40),
          surfaceContainerHighest: Color(0xFF2C384D),
          outline: Color(0xFF3B475C),
          outlineVariant: Color(0xFF263042),
          shadow: Color(0xFF000000),
          scrim: Color(0xFF000000),
          inverseSurface: Color(0xFFF3F0E8),
          onInverseSurface: Color(0xFF1C2430),
          inversePrimary: Color(0xFFB45309),
        )
      : const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF1C2430), // Deep Fountain-Pen Ink Navy
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFE5EAF2),
          onPrimaryContainer: Color(0xFF141B26),
          secondary: Color(0xFFB45309), // Warm Amber Ink
          onSecondary: Color(0xFFFFFFFF),
          secondaryContainer: Color(0xFFFEF3C7),
          onSecondaryContainer: Color(0xFF78350F),
          tertiary: Color(0xFFD97706), // Golden Citrine
          onTertiary: Color(0xFFFFFFFF),
          tertiaryContainer: Color(0xFFFDE68A),
          onTertiaryContainer: Color(0xFF451A03),
          error: Color(0xFFB91C1C),
          onError: Color(0xFFFFFFFF),
          errorContainer: Color(0xFFFEE2E2),
          onErrorContainer: Color(0xFF7F1D1D),
          surface: Color(0xFFFAF7F2), // Warm Ivory Paper
          onSurface: Color(0xFF1C2430), // Deep Fountain-Pen Ink
          onSurfaceVariant: Color(0xFF555E6D),
          surfaceContainerLowest: Color(0xFFFFFFFF),
          surfaceContainerLow: Color(0xFFF5F1E9),
          surfaceContainer: Color(0xFFEFEAE0),
          surfaceContainerHigh: Color(0xFFE8E1D4),
          surfaceContainerHighest: Color(0xFFDFD7C8),
          outline: Color(0xFFCFC7B8),
          outlineVariant: Color(0xFFE4DDD0),
          shadow: Color(0xFF000000),
          scrim: Color(0xFF000000),
          inverseSurface: Color(0xFF1C2430),
          onInverseSurface: Color(0xFFFAF7F2),
          inversePrimary: Color(0xFFFBBF24),
        );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      indicatorColor: colorScheme.tertiaryContainer,
      surfaceTintColor: Colors.transparent,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      indicatorColor: colorScheme.tertiaryContainer,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: colorScheme.outlineVariant),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    visualDensity: VisualDensity.standard,
  );
}
