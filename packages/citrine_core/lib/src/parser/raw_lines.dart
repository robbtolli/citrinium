import 'package:meta/meta.dart';

import 'span.dart';

/// A single physical line of `rawText`: its content (excluding the line
/// terminator) plus whatever terminator followed it (`''` for the final
/// line of a file with no trailing newline).
///
/// This is an internal building block for the parser -- higher layers
/// (`ParsedLine` in `parsed_line.dart`) carry the richer, public
/// classification. Kept separate from frontmatter/code/task concerns so
/// each piece of the pipeline (`splitRawLines` -> frontmatter detection ->
/// code-fence tracking -> line classification) can be tested in isolation.
@immutable
class RawLine {
  const RawLine({
    required this.index,
    required this.span,
    required this.content,
    required this.terminator,
  });

  /// 0-based index within whatever list this line came from (the whole
  /// document when first split; renumbered to be 0-based within the body
  /// once frontmatter is stripped off).
  final int index;

  /// Span of the content only, in the original text's offsets -- never
  /// includes the terminator.
  final Span span;

  /// `span.of(text)`, cached at construction time since every consumer
  /// needs it at least once.
  final String content;

  /// One of `''`, `'\n'`, `'\r\n'`, `'\r'`.
  final String terminator;

  /// End offset of the terminator (i.e. where the *next* line's content, if
  /// any, begins). Equal to `span.end` when [terminator] is empty.
  int get fullEnd => span.end + terminator.length;

  @override
  String toString() =>
      'RawLine($index, $span, terminator: ${terminator.isEmpty ? 'none' : terminator.codeUnits})';
}

final RegExp _lineBreak = RegExp(r'\r\n|\r|\n');

/// Splits [text] into [RawLine]s.
///
/// A trailing newline never produces an extra empty trailing line -- `"a\n"`
/// is one line (`"a"`, terminator `"\n"`), not two. An empty string produces
/// zero lines. This mirrors `hasTrailingNewline` in `vault_file_io.dart`
/// exactly, since W2 and W1 need to agree on what "has a trailing newline"
/// means for the same file.
List<RawLine> splitRawLines(String text) {
  final lines = <RawLine>[];
  var pos = 0;
  var index = 0;
  for (final m in _lineBreak.allMatches(text)) {
    final span = Span(pos, m.start);
    lines.add(
      RawLine(
        index: index,
        span: span,
        content: span.of(text),
        terminator: m.group(0)!,
      ),
    );
    index++;
    pos = m.end;
  }
  if (pos < text.length) {
    final span = Span(pos, text.length);
    lines.add(
      RawLine(index: index, span: span, content: span.of(text), terminator: ''),
    );
  }
  return lines;
}
