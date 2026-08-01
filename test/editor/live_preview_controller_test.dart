import 'package:citrinium/core/editor/live_preview_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cursor at index 0 and boundaries tests', () {
    testWidgets('caret at index 0 does not throw RangeError on buildTextSpan',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = LivePreviewController(text: '# Heading\n- Item 1');

                // Caret at position 0
                controller.selection = const TextSelection.collapsed(offset: 0);

                final span = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                expect(span, isNotNull);
                expect(span.children, isNotEmpty);
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('caret at -1 (invalid) does not throw RangeError on buildTextSpan',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = LivePreviewController(text: 'Some text');

                // Caret invalid (-1)
                controller.selection = const TextSelection.collapsed(offset: -1);

                final span = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                expect(span, isNotNull);
                return Container();
              },
            ),
          ),
        ),
      );
    });
  });
}
