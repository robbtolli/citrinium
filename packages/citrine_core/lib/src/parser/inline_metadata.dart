import 'package:meta/meta.dart';

import 'span.dart';

/// Inline metadata kinds recognized in rapid-log lines, per `design.md`
/// §3.2 (`📅⏰🔁@#^`).
enum InlineMetadataKind {
  /// `📅 2026-08-01` -- due/scheduled date, `YYYY-MM-DD`.
  date,

  /// `⏰17:00` / `⏰ 17:00` -- time-of-day, `H:MM` or `HH:MM`.
  time,

  /// `🔁 every weekday` -- free-text recurrence rule; extends until the
  /// next recognized marker or end of line.
  recurrence,

  /// `@phone` -- GTD-style context.
  context,

  /// `#waiting-for/dr-lee` -- tag (Obsidian-style nested tags with `/`).
  tag,

  /// `^t7f3a2b` -- block ID anchor for backlinks/threading (N-02, D-12).
  blockId,
}

/// One piece of inline metadata found in a line, with offsets into the
/// owning `MarkdownDocument.rawText`.
@immutable
class InlineMetadata {
  const InlineMetadata({
    required this.kind,
    required this.span,
    required this.valueSpan,
    required this.value,
  });

  final InlineMetadataKind kind;

  /// Span of the full match, including the marker character(s) (e.g.
  /// `📅 2026-08-01`, `#tag`, `^blockid`).
  final Span span;

  /// Span of just the value portion (e.g. `2026-08-01` without `📅 `).
  final Span valueSpan;

  /// The extracted value text (same as `valueSpan.of(rawText)`).
  final String value;

  @override
  String toString() => 'InlineMetadata($kind, $value @ $span)';
}

final RegExp _dateRe = RegExp(r'📅[ \t]*(\d{4}-\d{2}-\d{2})');
final RegExp _timeRe = RegExp(r'⏰[ \t]*(\d{1,2}:\d{2})');
final RegExp _contextRe = RegExp(r'@([A-Za-z0-9_\-/]+)');
final RegExp _tagRe = RegExp(r'#([A-Za-z0-9_\-/]+)');
final RegExp _blockIdRe = RegExp(r'\^([A-Za-z0-9\-]+)');
final RegExp _recurrenceMarker = RegExp(r'🔁[ \t]*');

/// The set of marker characters that terminate a free-text `🔁` recurrence
/// value when preceded by whitespace (see [_extractRecurrence]).
const List<String> _followingMarkers = ['📅', '⏰', '@', '#', '^'];

/// Extracts all [InlineMetadata] within `rawText[lineSpan.start..lineSpan.end)`,
/// skipping any match that overlaps one of [excludeSpans] (used to keep
/// wikilink internals -- e.g. the `#heading` part of `[[Note#heading]]` --
/// from being misparsed as a tag).
///
/// Callers are responsible for not invoking this on code-fence/indented-code
/// lines; this function itself has no code-awareness.
List<InlineMetadata> extractInlineMetadata(
  String rawText,
  Span lineSpan, {
  List<Span> excludeSpans = const [],
}) {
  final results = <InlineMetadata>[];
  final lineText = lineSpan.of(rawText);

  void addAll(RegExp re, InlineMetadataKind kind) {
    for (final m in re.allMatches(lineText)) {
      final span = Span(lineSpan.start + m.start, lineSpan.start + m.end);
      if (excludeSpans.any((e) => e.overlaps(span))) continue;
      final valueOffsetInMatch = m.group(0)!.indexOf(m.group(1)!);
      final valueSpan = Span(span.start + valueOffsetInMatch, span.end);
      results.add(
        InlineMetadata(
          kind: kind,
          span: span,
          valueSpan: valueSpan,
          value: m.group(1)!,
        ),
      );
    }
  }

  addAll(_dateRe, InlineMetadataKind.date);
  addAll(_timeRe, InlineMetadataKind.time);
  addAll(_contextRe, InlineMetadataKind.context);
  addAll(_tagRe, InlineMetadataKind.tag);
  addAll(_blockIdRe, InlineMetadataKind.blockId);
  results.addAll(_extractRecurrence(lineText, lineSpan, excludeSpans));

  results.sort((a, b) => a.span.start.compareTo(b.span.start));
  return results;
}

/// `🔁` values are free text ("every weekday", "every 1st Monday"), so they
/// can't be bounded by a fixed-format regex the way date/time can. Instead
/// this scans forward from the marker to the next occurrence of another
/// metadata marker character that is itself preceded by whitespace (so a
/// recurrence description like "every 1st Monday" -- no `#`/`@`/`^` -- is
/// never accidentally truncated), or to the end of the line.
List<InlineMetadata> _extractRecurrence(
  String lineText,
  Span lineSpan,
  List<Span> excludeSpans,
) {
  final results = <InlineMetadata>[];
  for (final m in _recurrenceMarker.allMatches(lineText)) {
    var valueStart = m.end;
    var valueEnd = lineText.length;
    var i = valueStart;
    while (i < lineText.length) {
      final isBoundary =
          i > valueStart && (lineText[i - 1] == ' ' || lineText[i - 1] == '\t');
      if (isBoundary &&
          _followingMarkers.any((marker) => lineText.startsWith(marker, i))) {
        valueEnd = i;
        break;
      }
      i++;
    }
    // Trim trailing whitespace off the captured value without losing the
    // marker span's own start offset.
    while (valueEnd > valueStart &&
        (lineText[valueEnd - 1] == ' ' || lineText[valueEnd - 1] == '\t')) {
      valueEnd--;
    }
    if (valueEnd <= valueStart) continue; // `🔁` with no following text.
    final span = Span(lineSpan.start + m.start, lineSpan.start + valueEnd);
    if (excludeSpans.any((e) => e.overlaps(span))) continue;
    final valueSpan = Span(
      lineSpan.start + valueStart,
      lineSpan.start + valueEnd,
    );
    results.add(
      InlineMetadata(
        kind: InlineMetadataKind.recurrence,
        span: span,
        valueSpan: valueSpan,
        value: lineText.substring(valueStart, valueEnd),
      ),
    );
  }
  return results;
}
