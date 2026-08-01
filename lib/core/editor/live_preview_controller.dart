import 'package:citrinium_core/decoration.dart' hide DecorationRole;
import 'package:citrinium_core/decoration.dart' as markdown_dec;
import 'package:flutter/material.dart' hide Decoration;

import 'decoration_theme.dart';

/// Custom TextEditingController for design.md §7 Live Preview.
///
/// Plain text buffer is authoritative. `buildTextSpan` decorates viewport-scoped
/// lines based on caret position / reveal rules while preserving exact offset identity.
class LivePreviewController extends TextEditingController {
  LivePreviewController({
    String? text,
    bool isSourceMode = false,
  })  : _sourceMode = isSourceMode,
        super(text: text) {
    _decorator = IncrementalDecorator(text ?? '');
    addListener(_onTextChanged);
  }

  late final IncrementalDecorator _decorator;
  bool _sourceMode;

  int _visibleStartLine = 0;
  int _visibleEndLine = 50;

  void Function(int offset, String currentMarker)? onTaskCheckboxTapped;
  void Function(int offset, String currentMarker)? onTaskCheckboxLongPressed;

  bool get isSourceMode => _sourceMode;
  set isSourceMode(bool value) {
    if (_sourceMode != value) {
      _sourceMode = value;
      notifyListeners();
    }
  }

  void updateViewport({required int startLine, required int endLine}) {
    if (_visibleStartLine != startLine || _visibleEndLine != endLine) {
      _visibleStartLine = startLine;
      _visibleEndLine = endLine;
      notifyListeners();
    }
  }

  String _lastText = '';
  void _onTextChanged() {
    if (text != _lastText) {
      final old = _lastText;
      _lastText = text;
      _decorator.updateText(text, 0, old.length, text);
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final rawText = text;
    if (rawText.isEmpty) {
      return TextSpan(style: style);
    }

    final theme = Theme.of(context);
    final decTheme = DecorationTheme(
      isDark: theme.brightness == Brightness.dark,
      colorScheme: theme.colorScheme,
      textTheme: theme.textTheme,
      textScaleFactor: MediaQuery.textScalerOf(context).scale(1.0),
    );

    // If source mode or empty decoration set, return base style
    if (_sourceMode) {
      return TextSpan(text: rawText, style: style);
    }

    // Viewport-scoped decoration list
    final decorations = _decorator.getDecorationsForViewport(
      visibleStartLine: _visibleStartLine,
      visibleEndLine: _visibleEndLine,
      marginLines: 15,
    );

    if (decorations.isEmpty) {
      return TextSpan(text: rawText, style: style);
    }

    // Determine revealed nodes based on current selection
    final sel = selection;
    final revealedNodeIds = <int>{};

    if (sel.isValid) {
      final selStart = sel.start < sel.end ? sel.start : sel.end;
      final selEnd = sel.start < sel.end ? sel.end : sel.start;

      final selLineStart = _getLineStart(rawText, selStart);
      final selLineEnd = _getLineEnd(rawText, selEnd);

      for (final dec in decorations) {
        final isBlockMarker = dec.kind == DecorationKind.heading ||
            dec.kind == DecorationKind.listMarker ||
            dec.kind == DecorationKind.taskMarker ||
            dec.kind == DecorationKind.blockquoteMarker ||
            dec.kind == DecorationKind.fenceDelimiter ||
            dec.kind == DecorationKind.frontmatterDelimiter;

        if (isBlockMarker) {
          if (dec.start >= selLineStart && dec.start <= selLineEnd) {
            revealedNodeIds.add(dec.nodeId);
          }
        } else {
          if (selStart <= dec.end && selEnd >= dec.start) {
            revealedNodeIds.add(dec.nodeId);
          }
        }
      }
    }

    // Build InlineSpan tree covering rawText [0..rawText.length)
    final spans = <InlineSpan>[];
    var currentOffset = 0;

    // Filter and sort decorations by start offset
    final sortedDecs = List<markdown_dec.Decoration>.from(decorations)
      ..sort((a, b) => a.start.compareTo(b.start));

    for (final dec in sortedDecs) {
      if (dec.start < currentOffset) continue; // Skip overlaps
      if (dec.start > rawText.length) break;

      // Plain undecorated prefix before dec.start
      if (dec.start > currentOffset) {
        spans.add(TextSpan(
          text: rawText.substring(currentOffset, dec.start),
          style: style,
        ));
        currentOffset = dec.start;
      }

      final end = dec.end.clamp(currentOffset, rawText.length);
      if (end > currentOffset) {
        final spanText = rawText.substring(currentOffset, end);
        final isRevealed = revealedNodeIds.contains(dec.nodeId);

        // Check if IME composing covers this range
        final isComposingCovered = withComposing &&
            value.composing.isValid &&
            value.composing.start < end &&
            value.composing.end > currentOffset;

        if (isComposingCovered) {
          spans.add(TextSpan(text: spanText, style: style));
        } else {
          final span = decTheme.buildSpan(
            spanText: spanText,
            decoration: dec,
            isRevealed: isRevealed,
            isSourceMode: _sourceMode,
            onCheckboxTap: (markerChar) {
              if (onTaskCheckboxTapped != null) {
                onTaskCheckboxTapped!(currentOffset, markerChar);
              } else {
                _toggleCheckboxAt(currentOffset, markerChar);
              }
            },
            onCheckboxLongPress: (markerChar) {
              if (onTaskCheckboxLongPressed != null) {
                onTaskCheckboxLongPressed!(currentOffset, markerChar);
              }
            },
          );
          spans.add(span);
        }
        currentOffset = end;
      }
    }

    // Trailing plain undecorated suffix after last decoration
    if (currentOffset < rawText.length) {
      spans.add(TextSpan(
        text: rawText.substring(currentOffset),
        style: style,
      ));
    }

    return TextSpan(style: style, children: spans);
  }

  void _toggleCheckboxAt(int offset, String currentMarker) {
    final nextMarker = (currentMarker == 'x' || currentMarker == 'X') ? ' ' : 'x';
    if (offset >= 0 && offset < text.length) {
      final newText = text.replaceRange(offset, offset + 1, nextMarker);
      value = value.copyWith(
        text: newText,
        selection: selection,
      );
    }
  }

  /// Toggle task state at current line or selection (for Cmd+Enter)
  void toggleCurrentTaskState() {
    final sel = selection;
    if (!sel.isValid) return;
    final pos = sel.start;

    final lineStart = _getLineStart(text, pos);
    final lineEnd = _getLineEnd(text, pos);

    final lineText = text.substring(lineStart, lineEnd);
    final taskReg = RegExp(r'^([ \t]*[-*+][ \t]+\[)(.)(\].*)$');
    final match = taskReg.firstMatch(lineText);
    if (match != null) {
      final prefix = match.group(1)!;
      final currentMarker = match.group(2)!;
      final suffix = match.group(3)!;

      final nextMarker =
          (currentMarker == 'x' || currentMarker == 'X') ? ' ' : 'x';
      final newLine = '$prefix$nextMarker$suffix';

      final newText = text.replaceRange(lineStart, lineEnd, newLine);
      value = value.copyWith(
        text: newText,
        selection: selection,
      );
    }
  }

  static int _getLineStart(String text, int pos) {
    if (pos <= 0) return 0;
    final clamped = pos.clamp(0, text.length);
    final idx = text.lastIndexOf('\n', clamped - 1);
    return idx == -1 ? 0 : idx + 1;
  }

  static int _getLineEnd(String text, int pos) {
    if (pos < 0) return 0;
    if (pos >= text.length) return text.length;
    final idx = text.indexOf('\n', pos);
    return idx == -1 ? text.length : idx;
  }
}
