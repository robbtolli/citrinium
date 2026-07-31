import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citrinium/main.dart';

void main() {
  testWidgets('app boots and shows the placeholder home page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CitriniumApp());

    expect(find.text('Citrinium'), findsOneWidget);
    expect(find.text('Citrinium is under construction.'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
