import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

import 'raw_lines.dart';
import 'span.dart';

/// YAML frontmatter recognized **only at offset 0** of `rawText`, per
/// `design.md` §3.3 / `docs/milestones/m0.md` W2.
///
/// [rawYaml] is the *exact* substring between the `---` delimiters,
/// preserved verbatim so that [MarkdownDocument.setFrontmatterValue] /
/// [MarkdownDocument.removeFrontmatterValue] can hand it to `yaml_edit`'s
/// `YamlEditor` and splice the surgical result back in, keeping any user
/// comments/formatting/key order in the untouched parts of the document
/// intact.
@immutable
class Frontmatter {
  const Frontmatter({
    required this.span,
    required this.rawYamlSpan,
    required this.rawYaml,
    required this.data,
  });

  /// Span covering the opening `---` line through the closing `---` line's
  /// terminator (or its end, if the file ends immediately after it with no
  /// trailing newline). The document body starts at `span.end`.
  final Span span;

  /// Span of just the YAML body, i.e. between the two `---` delimiter
  /// lines (exclusive of both).
  final Span rawYamlSpan;

  /// `rawYamlSpan.of(rawText)`.
  final String rawYaml;

  /// The parsed YAML value, if [rawYaml] parsed successfully as a mapping.
  ///
  /// `null` if the frontmatter block is empty, or if it failed to parse as
  /// YAML at all (a syntactically-broken-but-structurally-present
  /// frontmatter block; we still recognize and preserve the block's span
  /// for round-tripping even though we can't offer structured access to
  /// it -- a parse failure here must never take down parsing the rest of
  /// the document).
  final YamlMap? data;

  @override
  String toString() =>
      'Frontmatter($span, ${data == null ? 'unparsed' : '${data!.length} keys'})';
}

/// Attempts to recognize and parse frontmatter at the start of the
/// document described by [allRawLines] (the *whole* document's raw lines,
/// not just the body). Returns `null` if the document doesn't start with a
/// `---` delimiter line, or if no matching closing `---` line is found.
Frontmatter? parseFrontmatter(String rawText, List<RawLine> allRawLines) {
  if (allRawLines.isEmpty) return null;
  if (allRawLines.first.content.trimRight() != '---') return null;

  for (var i = 1; i < allRawLines.length; i++) {
    if (allRawLines[i].content.trimRight() != '---') continue;

    final yamlStart = allRawLines[1].span.start;
    final yamlEnd = allRawLines[i].span.start;
    final rawYamlSpan = Span(yamlStart, yamlEnd);
    final rawYaml = rawYamlSpan.of(rawText);
    final span = Span(0, allRawLines[i].fullEnd);

    YamlMap? data;
    if (rawYaml.trim().isNotEmpty) {
      try {
        final loaded = loadYaml(rawYaml);
        if (loaded is YamlMap) data = loaded;
      } on YamlException {
        data = null;
      }
    }

    return Frontmatter(
      span: span,
      rawYamlSpan: rawYamlSpan,
      rawYaml: rawYaml,
      data: data,
    );
  }

  return null;
}
