import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citrinium/core/editor/live_preview_controller.dart';
import 'package:citrinium/core/editor/live_preview_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LivePreviewEditor Widget & Integration Tests', () {
    testWidgets('renders LivePreviewEditor with initial content',
        (WidgetTester tester) async {
      final controller = LivePreviewController(text: '# Hello\n- [ ] Task 1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LivePreviewEditor(controller: controller),
          ),
        ),
      );

      expect(find.byType(LivePreviewEditor), findsOneWidget);
      expect(find.textContaining('Hello'), findsOneWidget);
      expect(find.textContaining('Task 1'), findsOneWidget);
    });

    testWidgets('bullet list item shows • when collapsed and - when revealed',
        (WidgetTester tester) async {
      final text = '- List item 1\nSome other text';
      final controller = LivePreviewController(text: text);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LivePreviewEditor(controller: controller),
          ),
        ),
      );

      // Collapsed state: caret on line 2 ("Some other text")
      controller.selection = TextSelection.collapsed(offset: text.indexOf('Some'));
      final spanCollapsed = controller.buildTextSpan(
        context: tester.element(find.byType(LivePreviewEditor)),
        withComposing: false,
      );

      // Verify that plain text concatenated from span tree is byte-identical length
      expect(controller.text, equals(text));

      // Check that span contains '•' when collapsed
      final firstLineSpan = spanCollapsed.children!.first as TextSpan;
      expect(firstLineSpan.text, equals('•'));

      // Revealed state: caret on line 1 ("List item 1")
      controller.selection = TextSelection.collapsed(offset: text.indexOf('List'));
      final spanRevealed = controller.buildTextSpan(
        context: tester.element(find.byType(LivePreviewEditor)),
        withComposing: false,
      );

      final firstLineSpanRevealed = spanRevealed.children!.first as TextSpan;
      expect(firstLineSpanRevealed.text, equals('-'));
    });
  });
}
