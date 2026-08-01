import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citrinium/core/editor/live_preview_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String extractPlainText(InlineSpan span) {
    if (span is TextSpan) {
      final buffer = StringBuffer();
      if (span.text != null) {
        buffer.write(span.text);
      }
      if (span.children != null) {
        for (final child in span.children!) {
          buffer.write(extractPlainText(child));
        }
      }
      return buffer.toString();
    } else if (span is WidgetSpan) {
      // A 1-char WidgetSpan in Flutter PlaceholderSpan accounting occupies exactly 1 character/placeholder
      return ' '; // 1 character
    }
    return '';
  }

  group('Exit Criterion #1: Offset Identity', () {
    testWidgets('Span tree length matches controller.text length across reveal states',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final text = '''
# Heading 1
- [ ] Task item 1
- [x] Task item 2
- BuJo event ○ @work
Prose with **bold**, *italic*, and [[wikilink|alias]].
```dart
code inside fence
```
''';
                final controller = LivePreviewController(text: text);

                // State 1: No selection (all collapsed)
                final span1 = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );
                final extracted1 = extractPlainText(span1);
                expect(extracted1.length, equals(text.length));

                // State 2: Caret on bold text
                controller.selection = TextSelection.collapsed(
                    offset: text.indexOf('bold'));
                final span2 = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );
                final extracted2 = extractPlainText(span2);
                expect(extracted2.length, equals(text.length));

                // State 3: Source mode
                controller.isSourceMode = true;
                final span3 = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );
                final extracted3 = extractPlainText(span3);
                expect(extracted3, equals(text));

                return Container();
              },
            ),
          ),
        ),
      );
    });
  });
}
