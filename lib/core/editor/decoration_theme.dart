import 'package:citrine_core/decoration.dart';
import 'package:citrine_core/decoration.dart' as markdown_dec;
import 'package:flutter/material.dart' hide Decoration;

/// Styling rules for Live Preview decorations (m6).
class DecorationTheme {
  const DecorationTheme({
    required this.isDark,
    required this.colorScheme,
    required this.textTheme,
    this.textScaleFactor = 1.0,
  });

  final bool isDark;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final double textScaleFactor;

  /// Collapsed markup marker style: zero-advance & transparent.
  TextStyle get collapsedMarkerStyle => const TextStyle(
        fontSize: 0.001,
        color: Colors.transparent,
        letterSpacing: -0.5,
      );

  /// Dimmed revealed marker style (e.g. `**`, `[[`, `#`).
  TextStyle get revealedMarkerStyle => TextStyle(
        color: colorScheme.outline.withValues(alpha: 0.6),
        fontWeight: FontWeight.normal,
      );

  /// Resolve styling for a decoration span given reveal status and onCheckboxTap callback.
  InlineSpan buildSpan({
    required String spanText,
    required markdown_dec.Decoration decoration,
    required bool isRevealed,
    required bool isSourceMode,
    required ValueChanged<String>? onCheckboxTap,
    ValueChanged<String>? onCheckboxLongPress,
    ValueChanged<String>? onLinkTap,
    ValueChanged<String>? onTagTap,
  }) {
    if (isSourceMode) {
      return TextSpan(text: spanText);
    }

    final role = decoration.role;
    final kind = decoration.kind;

    // Checkbox WidgetSpan substitution:
    // When collapsed, if this is taskMarker content (the single marker char inside `[x]`),
    // substitute a 1-char WidgetSpan checkbox.
    if (!isRevealed &&
        kind == DecorationKind.taskMarker &&
        role == DecorationRole.content &&
        spanText.length == 1) {
      final markerChar = spanText;
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _TaskCheckboxWidget(
          markerChar: markerChar,
          colorScheme: colorScheme,
          onTap: () {
            if (onCheckboxTap != null) {
              onCheckboxTap(markerChar);
            }
          },
          onLongPress: () {
            if (onCheckboxLongPress != null) {
              onCheckboxLongPress(markerChar);
            }
          },
        ),
      );
    }

    // Collapse or substitute markers when not revealed
    if (!isRevealed &&
        (role == DecorationRole.openMarker ||
            role == DecorationRole.closeMarker)) {
      if (kind == DecorationKind.listMarker) {
        if (spanText == '-' || spanText == '*' || spanText == '+') {
          return TextSpan(
            text: '•',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          );
        } else {
          return TextSpan(
            text: spanText,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          );
        }
      }
      return TextSpan(text: spanText, style: collapsedMarkerStyle);
    }

    // Revealed markers
    if (isRevealed &&
        (role == DecorationRole.openMarker ||
            role == DecorationRole.closeMarker)) {
      return TextSpan(text: spanText, style: revealedMarkerStyle);
    }

    // Content styling by kind
    TextStyle? style;
    switch (kind) {
      case DecorationKind.strong:
        style = const TextStyle(fontWeight: FontWeight.bold);
        break;
      case DecorationKind.emphasis:
        style = const TextStyle(fontStyle: FontStyle.italic);
        break;
      case DecorationKind.strikethrough:
        style = const TextStyle(decoration: TextDecoration.lineThrough);
        break;
      case DecorationKind.cancelledTaskText:
        style = TextStyle(
          decoration: TextDecoration.lineThrough,
          color: colorScheme.outline,
        );
        break;
      case DecorationKind.highlight:
        style = TextStyle(
          backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
        );
        break;
      case DecorationKind.inlineCode:
        style = TextStyle(
          fontFamily: 'monospace',
          backgroundColor: colorScheme.surfaceContainerHighest,
        );
        break;
      case DecorationKind.heading:
        final level = decoration.level ?? 1;
        final fontSize = (24.0 - (level - 1) * 2.0).clamp(14.0, 28.0);
        style = TextStyle(
          fontSize: fontSize * textScaleFactor,
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
        );
        break;
      case DecorationKind.wikilink:
      case DecorationKind.wikilinkAlias:
      case DecorationKind.inlineLink:
      case DecorationKind.autolink:
        final target = decoration.payload ?? spanText;
        if (!isRevealed && onLinkTap != null && role == DecorationRole.content) {
          return WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onLinkTap(target),
                child: Text(
                  spanText,
                  style: TextStyle(
                    color: colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          );
        }
        style = TextStyle(
          color: colorScheme.primary,
          decoration: TextDecoration.underline,
        );
        break;
      case DecorationKind.embed:
        style = TextStyle(
          color: colorScheme.secondary,
          fontWeight: FontWeight.w500,
        );
        break;
      case DecorationKind.tag:
        final tag = decoration.payload ?? spanText;
        if (!isRevealed && onTagTap != null && role == DecorationRole.content) {
          return WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onTagTap(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    spanText,
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        style = TextStyle(
          color: colorScheme.tertiary,
          fontWeight: FontWeight.w500,
        );
        break;
      case DecorationKind.dueDate:
      case DecorationKind.dueTime:
      case DecorationKind.recurrence:
      case DecorationKind.context:
      case DecorationKind.blockId:
        style = TextStyle(
          color: colorScheme.tertiary,
          fontWeight: FontWeight.w500,
        );
        break;
      case DecorationKind.eventBullet:
        style = TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
        );
        break;
      case DecorationKind.noteBullet:
        style = TextStyle(
          color: colorScheme.outline,
          fontWeight: FontWeight.bold,
        );
        break;
      default:
        style = null;
        break;
    }

    return TextSpan(text: spanText, style: style);
  }
}

class _TaskCheckboxWidget extends StatelessWidget {
  const _TaskCheckboxWidget({
    required this.markerChar,
    required this.colorScheme,
    required this.onTap,
    this.onLongPress,
  });

  final String markerChar;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isChecked = markerChar == 'x' || markerChar == 'X';
    final isInProgress = markerChar == '/';
    final isCancelled = markerChar == '-';

    Border border;
    Color boxColor;

    if (isChecked) {
      border = Border.all(color: colorScheme.primary, width: 1.5);
      boxColor = colorScheme.primary;
    } else if (isInProgress) {
      border = Border.all(color: colorScheme.primary, width: 1.5);
      boxColor = Colors.transparent;
    } else if (isCancelled) {
      border = Border.all(
        color: colorScheme.outline.withValues(alpha: 0.5),
        width: 1.5,
      );
      boxColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    } else {
      border = Border.all(color: colorScheme.outline, width: 1.5);
      boxColor = Colors.transparent;
    }

    Widget? child;
    if (isChecked) {
      child = Icon(
        Icons.check,
        size: 12.0,
        color: colorScheme.onPrimary,
      );
    } else if (isInProgress) {
      child = CustomPaint(
        painter: _HalfFilledCheckboxPainter(color: colorScheme.primary),
      );
    } else if (isCancelled) {
      child = Center(
        child: Container(
          width: 8.0,
          height: 1.5,
          color: colorScheme.outline,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2.0),
        width: 16.0,
        height: 16.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3.0),
          border: border,
          color: boxColor,
        ),
        child: child,
      ),
    );
  }
}

class _HalfFilledCheckboxPainter extends CustomPainter {
  const _HalfFilledCheckboxPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    // Draw left half filled
    canvas.drawRect(
      Rect.fromLTWH(1.5, 1.5, (size.width - 3.0) / 2, size.height - 3.0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _HalfFilledCheckboxPainter oldDelegate) =>
      oldDelegate.color != color;
}
