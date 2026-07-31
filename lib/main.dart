import 'package:flutter/material.dart';

/// Entry point for the Citrinium app.
///
/// This is intentionally a minimal placeholder: the real app shell
/// (routing, Riverpod providers, vault picker, Material 3 theming) is
/// M0/W4 work and hasn't landed yet. This file exists so the repo boots
/// to *something* other than the `flutter create` counter template while
/// the foundational vault/index layers (W1-W3) are built out in
/// `packages/citrinium_core`.
void main() {
  runApp(const CitriniumApp());
}

/// Root widget of the Citrinium app.
class CitriniumApp extends StatelessWidget {
  const CitriniumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Citrinium',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber)),
      home: const _PlaceholderHomePage(),
    );
  }
}

class _PlaceholderHomePage extends StatelessWidget {
  const _PlaceholderHomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Citrinium')),
      body: const Center(
        child: Text('Citrinium is under construction.'),
      ),
    );
  }
}
