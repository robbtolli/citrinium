import 'package:flutter/material.dart';

/// Material 3, calm-default theming (P-07 "calm defaults, progressive
/// disclosure", A-07 "avoid decoration-first templates; functional
/// defaults first"): a single neutral-ish seed color, no bespoke
/// typography/iconography, nothing that competes with the content for
/// attention. Both light and dark variants exist so the OS-level
/// preference is honored out of the box.
ThemeData buildCitriniumTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFAD8B00), // muted amber -- matches the app icon
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    appBarTheme: const AppBarTheme(centerTitle: false),
    visualDensity: VisualDensity.standard,
  );
}
