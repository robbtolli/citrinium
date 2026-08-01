import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

/// Root widget: `ProviderScope` lives in `main.dart` (so tests can override
/// `sharedPreferencesProvider` before pumping this), everything below is
/// just routing + theming (`docs/milestones/m0.md` W4).
class CitriniumApp extends ConsumerWidget {
  const CitriniumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Citrinium',
      theme: buildCitriniumTheme(Brightness.light),
      darkTheme: buildCitriniumTheme(Brightness.dark),
      routerConfig: router,
    );
  }
}
