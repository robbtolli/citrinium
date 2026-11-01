import 'bujo.dart';
import 'code_blocks.dart';
import 'frontmatter.dart';
import 'inline_metadata.dart';
import 'parsed_line.dart';
import 'raw_lines.dart';
import 'span.dart';
import 'task_state.dart';
import 'wikilink.dart';

/// List bullets recognized for tasks/BuJo lines/generic list items: `-`,
/// `*`, `+` (standard CommonMark bullet characters).
final RegExp _taskRe = RegExp(
  r'^([ \t]*)([-*+])([ \t]+)\[(.)\](?:([ \t]+)(.*))?$',
);
final RegExp _bujoRe = RegExp(
  r'^([ \t]*)([-*+])([ \t]+)([○–])(?:([ \t]+)(.*))?$',
);
final RegExp _headingRe = RegExp(r'^[ \t]{0,3}(#{1,6})([ \t]+.*)?$');
final RegExp _listItemRe = RegExp(r'^([ \t]*)([-*+])([ \t]+)(.*)$');

/// The result of parsing frontmatter + body lines out of a `rawText`. This
/// is a pure function of [rawText]; `MarkdownDocument.parse` is a thin
/// wrapper that also stashes [rawText] itself on the returned document.
class ParseResult {
  const ParseResult({required this.frontmatter, required this.lines});

  final Frontmatter? frontmatter;
  final List<ParsedLine> lines;
}

ParseResult parseMarkdown(String rawText) {
  final allRawLines = splitRawLines(rawText);
  final frontmatter = parseFrontmatter(rawText, allRawLines);
  final bodyStart = frontmatter?.span.end ?? 0;

  final bodyRawLines = allRawLines
      .where((l) => l.span.start >= bodyStart)
      .toList(growable: false);
  final statuses = computeCodeLineStatuses(bodyRawLines);

  final lines = <ParsedLine>[];
  for (var i = 0; i < bodyRawLines.length; i++) {
    lines.add(
      _classifyLine(
        rawText,
        i,
        bodyRawLines[i].span,
        bodyRawLines[i].content,
        statuses[i],
      ),
    );
  }

  return ParseResult(frontmatter: frontmatter, lines: lines);
}

ParsedLine _classifyLine(
  String rawText,
  int index,
  Span span,
  String content,
  CodeLineStatus status,
) {
  switch (status) {
    case CodeLineStatus.fenceDelimiter:
      return ParsedLine(
        index: index,
        span: span,
        kind: LineKind.codeFenceDelimiter,
      );
    case CodeLineStatus.code:
      return ParsedLine(index: index, span: span, kind: LineKind.code);
    case CodeLineStatus.none:
      break;
  }

  if (content.trim().isEmpty) {
    return ParsedLine(index: index, span: span, kind: LineKind.blank);
  }

  final taskMatch = _taskRe.firstMatch(content);
  if (taskMatch != null) {
    return _buildTaskLine(rawText, index, span, taskMatch);
  }

  final bujoMatch = _bujoRe.firstMatch(content);
  if (bujoMatch != null) {
    return _buildBujoLine(rawText, index, span, bujoMatch);
  }

  final links = extractWikiLinks(rawText, span);
  final excludeSpans = links.map((l) => l.span).toList(growable: false);
  final metadata = extractInlineMetadata(
    rawText,
    span,
    excludeSpans: excludeSpans,
  );

  LineKind kind;
  if (_headingRe.hasMatch(content)) {
    kind = LineKind.heading;
  } else if (_listItemRe.hasMatch(content)) {
    kind = LineKind.listItem;
  } else {
    kind = LineKind.text;
  }

  return ParsedLine(
    index: index,
    span: span,
    kind: kind,
    metadata: metadata,
    links: links,
  );
}

// `RegExpMatch` (dart:core) only exposes the *overall* match's start/end --
// there's no per-group offset API -- so group offsets below are
// reconstructed by walking cumulative group lengths from the (anchored,
// `^`-to-`$`) match start. This is exact, not a heuristic: the task/BuJo
// regexes fully consume the line with no ambiguous/alternated segments
// between the groups we care about, so `group(n)`'s lengths concatenate
// back to exactly the original text.

ParsedLine _buildTaskLine(String rawText, int index, Span span, RegExpMatch m) {
  final base = span.start;
  var pos = base;

  pos += m.group(1)!.length; // leading indent
  final bulletSpan = Span(pos, pos + m.group(2)!.length);
  pos = bulletSpan.end;
  pos += m.group(3)!.length; // spaces between bullet and `[`
  pos += 1; // `[`
  final markerChar = m.group(4)!;
  final markerSpan = Span(pos, pos + markerChar.length);
  pos = markerSpan.end;
  pos += 1; // `]`
  final checkboxSpan = Span(markerSpan.start - 1, markerSpan.end + 1);
  final spacesAfter = m.group(5);
  if (spacesAfter != null) pos += spacesAfter.length;
  final text = m.group(6);
  final contentSpan = text != null && text.isNotEmpty
      ? Span(pos, pos + text.length)
      : Span(pos, pos);

  final task = TaskInfo(
    stateKind: taskStateKindForMarker(markerChar),
    markerChar: markerChar,
    bulletSpan: bulletSpan,
    checkboxSpan: checkboxSpan,
    markerSpan: markerSpan,
    contentSpan: contentSpan,
  );

  final links = extractWikiLinks(rawText, span);
  final excludeSpans = links.map((l) => l.span).toList(growable: false);
  final metadata = extractInlineMetadata(
    rawText,
    span,
    excludeSpans: excludeSpans,
  );

  return ParsedLine(
    index: index,
    span: span,
    kind: LineKind.task,
    task: task,
    metadata: metadata,
    links: links,
  );
}

ParsedLine _buildBujoLine(String rawText, int index, Span span, RegExpMatch m) {
  final base = span.start;
  var pos = base;

  pos += m.group(1)!.length; // leading indent
  final bulletSpan = Span(pos, pos + m.group(2)!.length);
  pos = bulletSpan.end;
  pos += m.group(3)!.length; // spaces between bullet and signifier
  final signifierChar = m.group(4)!;
  final signifierSpan = Span(pos, pos + signifierChar.length);
  pos = signifierSpan.end;
  final spacesAfter = m.group(5);
  if (spacesAfter != null) pos += spacesAfter.length;
  final text = m.group(6);
  final contentSpan = text != null && text.isNotEmpty
      ? Span(pos, pos + text.length)
      : Span(pos, pos);

  final bujoKind = bujoSignifiers[signifierChar]!;
  final bujo = BujoLineInfo(
    kind: bujoKind,
    bulletSpan: bulletSpan,
    signifierSpan: signifierSpan,
    contentSpan: contentSpan,
  );

  final links = extractWikiLinks(rawText, span);
  final excludeSpans = links.map((l) => l.span).toList(growable: false);
  final metadata = extractInlineMetadata(
    rawText,
    span,
    excludeSpans: excludeSpans,
  );

  final kind = bujoKind == BujoKind.event ? LineKind.event : LineKind.note;
  return ParsedLine(
    index: index,
    span: span,
    kind: kind,
    bujo: bujo,
    metadata: metadata,
    links: links,
  );
}
