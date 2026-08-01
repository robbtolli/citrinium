import 'package:flutter/material.dart';

/// Backdrop CustomPainter that draws code block fills, blockquote bars,
/// active line tint, and thematic breaks behind EditableText (W4).
class EditorBackdropPainter extends CustomPainter {
  EditorBackdropPainter({
    required this.text,
    required this.selection,
    required this.colorScheme,
    required this.lineHeight,
    required this.padding,
  });

  final String text;
  final TextSelection selection;
  final ColorScheme colorScheme;
  final double lineHeight;
  final EdgeInsets padding;

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    final lines = text.split('\n');

    // 1. Active line tint
    if (selection.isValid && selection.isCollapsed) {
      final pos = selection.start;
      var currentOffset = 0;
      var activeLineIndex = -1;

      for (var i = 0; i < lines.length; i++) {
        final lineLen = lines[i].length + 1; // including \n
        if (pos >= currentOffset && pos < currentOffset + lineLen) {
          activeLineIndex = i;
          break;
        }
        currentOffset += lineLen;
      }

      if (activeLineIndex != -1) {
        final top = padding.top + activeLineIndex * lineHeight;
        final paint = Paint()
          ..color = colorScheme.primaryContainer.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTWH(0, top, size.width, lineHeight),
          paint,
        );
      }
    }

    // 2. Fences & Blockquotes & Hrules
    var inFence = false;
    double? fenceTop;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final top = padding.top + i * lineHeight;

      // Fence background
      final trimmed = line.trim();
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        if (!inFence) {
          inFence = true;
          fenceTop = top;
        } else {
          inFence = false;
          final bottom = top + lineHeight;
          final fencePaint = Paint()
            ..color = colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            ..style = PaintingStyle.fill;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(padding.left - 4, fenceTop!, size.width - padding.right + 4, bottom),
              const Radius.circular(4.0),
            ),
            fencePaint,
          );
          fenceTop = null;
        }
      }

      // Blockquote left bar
      if (line.trimLeft().startsWith('>')) {
        var depth = 0;
        var idx = 0;
        while (idx < line.length && (line[idx] == ' ' || line[idx] == '>')) {
          if (line[idx] == '>') depth++;
          idx++;
        }
        for (var d = 0; d < depth; d++) {
          final barPaint = Paint()
            ..color = colorScheme.primary.withValues(alpha: 0.7)
            ..strokeWidth = 3.0
            ..style = PaintingStyle.stroke;
          final x = padding.left + (d * 12.0) - 6.0;
          canvas.drawLine(
            Offset(x, top),
            Offset(x, top + lineHeight),
            barPaint,
          );
        }
      }

      // Thematic break rule
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        final rulePaint = Paint()
          ..color = colorScheme.outlineVariant
          ..strokeWidth = 1.0;
        final y = top + lineHeight / 2;
        canvas.drawLine(
          Offset(padding.left, y),
          Offset(size.width - padding.right, y),
          rulePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant EditorBackdropPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.selection != selection ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.padding != padding;
  }
}
