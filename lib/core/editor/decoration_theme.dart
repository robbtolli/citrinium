import 'package:citrinium_core/decoration.dart';
import 'package:citrinium_core/decoration.dart' as markdown_dec;
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
      case DecorationKind.dueDate:
      case DecorationKind.dueTime:
      case DecorationKind.recurrence:
      case DecorationKind.context:
      case DecorationKind.tag:
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
          border: Border.all(
            color: isChecked ? colorScheme.primary : colorScheme.outline,
            width: 1.5,
          ),
          color: isChecked ? colorScheme.primary : Colors.transparent,
        ),
        child: isChecked
            ? Icon(
                Icons.check,
                size: 12.0,
                color: colorScheme.onPrimary,
              )
            : null,
      ),
    );
  }
}
