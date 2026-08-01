import 'block_context.dart';
import 'decoration.dart';
import 'markdown_decorator.dart';

/// A cached line entry in [IncrementalDecorator].
class _LineEntry {
  _LineEntry({
    required this.text,
    required this.lineOffset,
    required this.enteringContext,
    this.isDirty = true,
  });

  String text;
  int lineOffset;
  BlockContext enteringContext;
  LineDecorationResult? result;
  bool isDirty;
}

/// Incremental, viewport-scoped decoration engine with early-stopping block context propagation.
class IncrementalDecorator {
  IncrementalDecorator([String text = '']) {
    _setText(text);
  }

  final List<_LineEntry> _lines = [];
  int _documentVersion = 0;
  int _nextNodeId = 1;

  int get documentVersion => _documentVersion;
  int get lineCount => _lines.length;

  /// Full text update (e.g. when opening a new file or after external edit).
  void _setText(String text) {
    _lines.clear();
    _documentVersion++;
    _nextNodeId = 1;

    final rawLines = text.split('\n');
    var offset = 0;
    for (var i = 0; i < rawLines.length; i++) {
      final lineStr = rawLines[i];
      _lines.add(
        _LineEntry(
          text: lineStr,
          lineOffset: offset,
          enteringContext:
              i == 0 ? BlockContext.initial : const BlockContext(),
          isDirty: true,
        ),
      );
      offset += lineStr.length + (i < rawLines.length - 1 ? 1 : 0);
    }

    _recomputeFrom(0);
  }

  /// Called when text is edited in a range `[editStart, editEnd)` with replacement [replacement].
  void updateText(
      String fullText, int editStart, int editEnd, String replacement) {
    _documentVersion++;

    // Split new full text into lines to reconstruct line boundaries accurately
    final newRawLines = fullText.split('\n');

    // Simple, exact sync for line list while preserving offsets
    _lines.clear();
    var offset = 0;
    for (var i = 0; i < newRawLines.length; i++) {
      final lineStr = newRawLines[i];
      _lines.add(
        _LineEntry(
          text: lineStr,
          lineOffset: offset,
          enteringContext:
              i == 0 ? BlockContext.initial : const BlockContext(),
          isDirty: true,
        ),
      );
      offset += lineStr.length + (i < newRawLines.length - 1 ? 1 : 0);
    }

    // Identify first invalidated line
    var startLineIndex = 0;
    for (var i = 0; i < _lines.length; i++) {
      final lineEnd = _lines[i].lineOffset + _lines[i].text.length;
      if (lineEnd >= editStart) {
        startLineIndex = i;
        break;
      }
    }

    _recomputeFrom(startLineIndex);
  }

  /// Forward block-context propagation with early termination.
  void _recomputeFrom(int startIndex) {
    var context = startIndex == 0
        ? BlockContext.initial
        : (_lines[startIndex - 1].result?.exitingContext ??
            BlockContext.initial);

    for (var i = startIndex; i < _lines.length; i++) {
      final entry = _lines[i];

      // If context is unchanged and entry is not dirty, we can terminate early!
      if (!entry.isDirty && entry.enteringContext == context) {
        break;
      }

      entry.enteringContext = context;
      final res = MarkdownDecorator.decorateLine(
        lineText: entry.text,
        lineOffset: entry.lineOffset,
        lineNumber: i,
        enteringContext: context,
        startNodeId: _nextNodeId,
      );

      _nextNodeId = res.nextNodeId;
      entry.result = res;
      entry.isDirty = false;
      context = res.exitingContext;
    }
  }

  /// Get decorations for all lines in document (unscoped).
  List<Decoration> getAllDecorations() {
    final all = <Decoration>[];
    for (var i = 0; i < _lines.length; i++) {
      _ensureLineDecorated(i);
      if (_lines[i].result != null) {
        all.addAll(_lines[i].result!.decorations);
      }
    }
    return all;
  }

  /// Get decorations for a visible line range `[startLine, endLine]` plus a margin [marginLines].
  List<Decoration> getDecorationsForViewport({
    required int visibleStartLine,
    required int visibleEndLine,
    int marginLines = 10,
  }) {
    final start = (visibleStartLine - marginLines).clamp(0, _lines.length - 1);
    final end = (visibleEndLine + marginLines).clamp(0, _lines.length - 1);

    final decs = <Decoration>[];
    for (var i = start; i <= end; i++) {
      _ensureLineDecorated(i);
      if (_lines[i].result != null) {
        decs.addAll(_lines[i].result!.decorations);
      }
    }
    return decs;
  }

  void _ensureLineDecorated(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= _lines.length) return;
    final entry = _lines[lineIndex];
    if (entry.isDirty || entry.result == null) {
      _recomputeFrom(lineIndex);
    }
  }
}
