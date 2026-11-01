import 'package:meta/meta.dart';

import 'span.dart';

/// An Obsidian-style `[[wikilink]]` or `![[embed]]`, with offsets into the
/// owning `MarkdownDocument.rawText`. Covers all forms from `design.md`
/// §3: `[[target]]`, `[[target|alias]]`, `[[target#heading]]`, `![[embed]]`.
@immutable
class WikiLink {
  const WikiLink({
    required this.span,
    required this.isEmbed,
    required this.target,
    required this.targetSpan,
    this.heading,
    this.headingSpan,
    this.alias,
    this.aliasSpan,
  });

  /// Full span, including the leading `!` for embeds and the surrounding
  /// `[[`/`]]` delimiters.
  final Span span;

  /// Whether this is an embed (`![[...]]`) rather than a plain link.
  final bool isEmbed;

  /// The link target (note name/path), excluding any `#heading` or
  /// `|alias` suffix.
  final String target;
  final Span targetSpan;

  /// The `#heading` fragment, if present, without the leading `#`.
  final String? heading;
  final Span? headingSpan;

  /// The `|alias` display text, if present, without the leading `|`.
  final String? alias;
  final Span? aliasSpan;

  @override
  String toString() =>
      'WikiLink(${isEmbed ? '!' : ''}[[$target'
      '${heading != null ? '#$heading' : ''}'
      '${alias != null ? '|$alias' : ''}]])';
}

// `[[` ... `]]`, non-greedy, no nested `[[`/`]]` inside -- matches Obsidian's
// own (documented) restriction that wikilink targets can't contain `[` or
// `]`. An optional leading `!` marks an embed.
final RegExp _wikilinkRe = RegExp(r'(!)?\[\[([^\[\]]+?)\]\]');

/// Extracts all [WikiLink]s within `rawText[lineSpan.start..lineSpan.end)`.
///
/// Callers are responsible for not invoking this on code-fence/indented-code
/// lines; this function itself has no code-awareness.
List<WikiLink> extractWikiLinks(String rawText, Span lineSpan) {
  final lineText = lineSpan.of(rawText);
  final results = <WikiLink>[];

  for (final m in _wikilinkRe.allMatches(lineText)) {
    final isEmbed = m.group(1) != null;
    final inner = m.group(2)!;
    // innerStart is the offset (within lineText) of the first char of
    // `inner`, i.e. right after the optional `!` and the `[[` delimiter.
    final innerStart = m.start + (isEmbed ? 1 : 0) + 2;

    // `|alias` is split off first (aliases can't themselves contain `|`),
    // then `#heading` is split off the remaining target portion.
    String targetPart = inner;
    String? alias;
    int? aliasRelStart;
    final pipeIdx = inner.indexOf('|');
    if (pipeIdx != -1) {
      targetPart = inner.substring(0, pipeIdx);
      alias = inner.substring(pipeIdx + 1);
      aliasRelStart = innerStart + pipeIdx + 1;
    }

    String target = targetPart;
    String? heading;
    int? headingRelStart;
    final hashIdx = targetPart.indexOf('#');
    if (hashIdx != -1) {
      target = targetPart.substring(0, hashIdx);
      heading = targetPart.substring(hashIdx + 1);
      headingRelStart = innerStart + hashIdx + 1;
    }

    final span = Span(lineSpan.start + m.start, lineSpan.start + m.end);
    final targetSpan = Span(
      lineSpan.start + innerStart,
      lineSpan.start + innerStart + target.length,
    );
    final headingSpan = heading == null
        ? null
        : Span(
            lineSpan.start + headingRelStart!,
            lineSpan.start + headingRelStart + heading.length,
          );
    final aliasSpan = alias == null
        ? null
        : Span(
            lineSpan.start + aliasRelStart!,
            lineSpan.start + aliasRelStart + alias.length,
          );

    results.add(
      WikiLink(
        span: span,
        isEmbed: isEmbed,
        target: target,
        targetSpan: targetSpan,
        heading: heading,
        headingSpan: headingSpan,
        alias: alias,
        aliasSpan: aliasSpan,
      ),
    );
  }

  return results;
}
