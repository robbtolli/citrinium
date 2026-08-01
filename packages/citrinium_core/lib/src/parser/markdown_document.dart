import 'package:meta/meta.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../vault/vault_file_io.dart'
    show LineEndingStyle, detectLineEndingStyle, hasTrailingNewline;
import 'frontmatter.dart';
import 'inline_metadata.dart';
import 'markdown_parser.dart';
import 'parsed_line.dart';
import 'task_state.dart';
import 'wikilink.dart';

/// Thrown by the edit API (`setTaskState`, `upsertInlineField`, etc.) when
/// asked to perform an edit that doesn't make sense for the target line
/// (e.g. setting a task state on a non-task line, or editing metadata on a
/// code line).
class MarkdownEditException implements Exception {
  MarkdownEditException(this.message);

  final String message;

  @override
  String toString() => 'MarkdownEditException: $message';
}

/// An offset-preserving parse of a single Markdown file's contents.
///
/// Per `docs/milestones/m0.md` W2 / `design.md` §7/§10: [rawText] is
/// authoritative, every other field is an *overlay* of offsets into it,
/// and the serializer is simply [rawText] itself -- there is no
/// parse-tree-to-text reserialization step, so there is no way for
/// untouched bytes to drift. All edit methods therefore work by splicing
/// [rawText] and reparsing, rather than mutating a document tree and
/// re-rendering it.
///
/// Construct via [MarkdownDocument.parse]. This class never throws for
/// malformed input -- worst case, content that doesn't fit any recognized
/// grammar is classified as [LineKind.text] (or, for frontmatter, `fm.data`
/// is left `null` while `fm.rawYaml`/`fm.span` still round-trip
/// correctly), which is required for hostile-input safety (W6's fixture
/// corpus depends on this).
@immutable
class MarkdownDocument {
  const MarkdownDocument._({
    required this.rawText,
    required this.frontmatter,
    required this.lines,
  });

  /// Parses [rawText] into a [MarkdownDocument].
  ///
  /// [rawText] must already have any UTF-8 BOM stripped and must be decoded
  /// text (not raw bytes) -- that boundary is `vault_file_io.dart`'s job
  /// (W1); this parser operates purely on `String` code-unit offsets, per
  /// the M0 "offset units" decision.
  factory MarkdownDocument.parse(String rawText) {
    final result = parseMarkdown(rawText);
    return MarkdownDocument._(
      rawText: rawText,
      frontmatter: result.frontmatter,
      lines: result.lines,
    );
  }

  /// The complete, authoritative source text. Serializing a
  /// [MarkdownDocument] is exactly this string -- there is no separate
  /// `serialize()` method because there is nothing to serialize.
  final String rawText;

  /// Parsed frontmatter, if [rawText] starts with a `---` delimited block.
  final Frontmatter? frontmatter;

  /// Every body line (i.e. every line after frontmatter, or every line if
  /// there is none), in document order, 0-indexed from the start of the
  /// body.
  final List<ParsedLine> lines;

  /// All task lines, in document order.
  List<ParsedLine> get tasks =>
      lines.where((l) => l.kind == LineKind.task).toList(growable: false);

  /// All BuJo event lines, in document order.
  List<ParsedLine> get events =>
      lines.where((l) => l.kind == LineKind.event).toList(growable: false);

  /// All BuJo note lines, in document order.
  List<ParsedLine> get notes =>
      lines.where((l) => l.kind == LineKind.note).toList(growable: false);

  /// Every wikilink/embed found anywhere in the body, in document order.
  List<WikiLinkRef> get allLinks => [
    for (final line in lines)
      for (final link in line.links) WikiLinkRef(line: line, link: link),
  ];

  /// Every inline metadata token found anywhere in the body, in document
  /// order.
  List<InlineMetadataRef> get allMetadata => [
    for (final line in lines)
      for (final m in line.metadata) InlineMetadataRef(line: line, metadata: m),
  ];

  // ---------------------------------------------------------------------
  // Edit API. Every method returns a *new* MarkdownDocument; `this` is
  // never mutated. Each is implemented as a targeted splice of [rawText]
  // followed by a full reparse -- correctness (an edit only ever changes
  // the bytes it says it changes) matters far more here than avoiding a
  // reparse, per the M0 W2 brief.
  // ---------------------------------------------------------------------

  /// Sets the task at `lines[lineIndex]` to a known [newState], writing
  /// [canonicalMarkerFor]'s canonical marker character.
  ///
  /// Use [setTaskMarkerChar] instead to write a custom/unrecognized marker
  /// character verbatim (there is no canonical character for
  /// [TaskStateKind.unknown]).
  ///
  /// Throws [MarkdownEditException] if `lines[lineIndex]` isn't a task
  /// line.
  MarkdownDocument setTaskState(int lineIndex, TaskStateKind newState) {
    return setTaskMarkerChar(lineIndex, canonicalMarkerFor(newState));
  }

  /// Sets the task at `lines[lineIndex]`'s marker character verbatim to
  /// [markerChar] (exactly one code unit), preserving unrecognized/custom
  /// statuses rather than requiring them to round-trip through
  /// [TaskStateKind].
  MarkdownDocument setTaskMarkerChar(int lineIndex, String markerChar) {
    if (markerChar.length != 1) {
      throw MarkdownEditException(
        'markerChar must be exactly one character, got "$markerChar"',
      );
    }
    final line = _requireLine(lineIndex);
    final task = line.task;
    if (line.kind != LineKind.task || task == null) {
      throw MarkdownEditException(
        'Line $lineIndex is not a task line (kind: ${line.kind})',
      );
    }
    final newText = rawText.replaceRange(
      task.markerSpan.start,
      task.markerSpan.end,
      markerChar,
    );
    return MarkdownDocument.parse(newText);
  }

  /// Inserts or replaces an inline metadata field of [kind] on
  /// `lines[lineIndex]`.
  ///
  /// For singleton kinds (`date`, `time`, `recurrence`, `blockId`): the
  /// first existing occurrence's value is replaced in place; if none
  /// exists, `marker value` is appended to the line (before an existing
  /// block ID, if any, to preserve the "block ID is last" convention).
  ///
  /// For multi-valued kinds (`tag`, `context`): this is an idempotent
  /// *add* -- a field with the exact same [value] already present is left
  /// untouched (no duplicate is added); otherwise it's appended the same
  /// way as the singleton case.
  MarkdownDocument upsertInlineField(
    int lineIndex,
    InlineMetadataKind kind,
    String value,
  ) {
    final line = _requireLine(lineIndex);
    _requireEditableLine(lineIndex, line);

    final existing = line.metadata
        .where((m) => m.kind == kind)
        .toList(growable: false);

    switch (kind) {
      case InlineMetadataKind.tag:
      case InlineMetadataKind.context:
        if (existing.any((m) => m.value == value)) return this;
        return _appendMetadataToLine(line, _snippetFor(kind, value));
      case InlineMetadataKind.date:
      case InlineMetadataKind.time:
      case InlineMetadataKind.recurrence:
      case InlineMetadataKind.blockId:
        if (existing.isNotEmpty) {
          final target = existing.first;
          final newText = rawText.replaceRange(
            target.valueSpan.start,
            target.valueSpan.end,
            value,
          );
          return MarkdownDocument.parse(newText);
        }
        return _appendMetadataToLine(line, _snippetFor(kind, value));
    }
  }

  /// Removes inline metadata of [kind] from `lines[lineIndex]`.
  ///
  /// If [value] is given, only a field matching both [kind] and [value] is
  /// removed (relevant for `tag`/`context`, which may appear more than
  /// once with different values); otherwise every field of [kind] on the
  /// line is removed. A no-op (returns `this`) if nothing matches.
  MarkdownDocument removeInlineField(
    int lineIndex,
    InlineMetadataKind kind, {
    String? value,
  }) {
    final line = _requireLine(lineIndex);
    _requireEditableLine(lineIndex, line);

    final matches = line.metadata
        .where((m) => m.kind == kind && (value == null || m.value == value))
        .toList();
    if (matches.isEmpty) return this;

    // Remove right-to-left so earlier spans in the same line stay valid
    // across the sequence of splices.
    matches.sort((a, b) => b.span.start.compareTo(a.span.start));

    var newText = rawText;
    for (final m in matches) {
      var start = m.span.start;
      var end = m.span.end;
      if (start > 0 && _isSpaceOrTab(newText, start - 1)) {
        start -= 1;
      } else if (end < newText.length && _isSpaceOrTab(newText, end)) {
        end += 1;
      }
      newText = newText.replaceRange(start, end, '');
    }
    return MarkdownDocument.parse(newText);
  }

  /// Appends a new line containing [text] to the end of the document body.
  ///
  /// If [rawText] doesn't already end with a newline, one is added first
  /// (matching whichever [LineEndingStyle] is passed, or the document's
  /// own dominant style if omitted, or `lf` for an empty document/one with
  /// no line breaks at all). The appended line itself always ends with a
  /// newline.
  MarkdownDocument appendLine(String text, {LineEndingStyle? lineEnding}) {
    final ending = _lineEndingLiteral(
      lineEnding ?? detectLineEndingStyle(rawText),
    );
    final needsLeadingNewline =
        rawText.isNotEmpty && !hasTrailingNewline(rawText);
    final newText = '$rawText${needsLeadingNewline ? ending : ''}$text$ending';
    return MarkdownDocument.parse(newText);
  }

  /// Sets `path` (a sequence of map keys / list indices, per `yaml_edit`'s
  /// `YamlEditor.update`) to [value] in the frontmatter, surgically --
  /// untouched keys, comments, and formatting elsewhere in the frontmatter
  /// block are preserved. Creates a new frontmatter block at the top of
  /// the document if one doesn't already exist.
  MarkdownDocument setFrontmatterValue(List<Object> path, Object? value) {
    final fm = frontmatter;
    if (fm == null) {
      // Seed with an explicit empty flow map rather than an empty string --
      // `YamlEditor('')` parses to a null scalar, which `update`/`parseAt`
      // can't traverse into or auto-vivify from.
      final editor = YamlEditor('{}');
      _ensureParentMaps(editor, path);
      editor.update(path, value);
      var newYaml = editor.toString();
      if (newYaml.isNotEmpty && !newYaml.endsWith('\n')) newYaml += '\n';
      return MarkdownDocument.parse('---\n$newYaml---\n$rawText');
    }
    // Same null-scalar-root caveat as above applies to an empty-but-present
    // frontmatter block (`---\n---\n`).
    final editor = YamlEditor(fm.rawYaml.trim().isEmpty ? '{}' : fm.rawYaml);
    _ensureParentMaps(editor, path);
    editor.update(path, value);
    var newYaml = editor.toString();
    if (newYaml.isNotEmpty && !newYaml.endsWith('\n')) newYaml += '\n';
    final newText = rawText.replaceRange(
      fm.rawYamlSpan.start,
      fm.rawYamlSpan.end,
      newYaml,
    );
    return MarkdownDocument.parse(newText);
  }

  /// Removes `path` from the frontmatter, surgically. A no-op if there's
  /// no frontmatter, or [path] doesn't resolve to an existing key.
  MarkdownDocument removeFrontmatterValue(List<Object> path) {
    final fm = frontmatter;
    if (fm == null) return this;
    final editor = YamlEditor(fm.rawYaml);
    try {
      editor.remove(path);
    } on Object {
      return this;
    }
    var newYaml = editor.toString();
    if (newYaml.isNotEmpty && !newYaml.endsWith('\n')) newYaml += '\n';
    final newText = rawText.replaceRange(
      fm.rawYamlSpan.start,
      fm.rawYamlSpan.end,
      newYaml,
    );
    return MarkdownDocument.parse(newText);
  }

  ParsedLine _requireLine(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= lines.length) {
      throw MarkdownEditException(
        'Line index $lineIndex out of range (0..${lines.length - 1})',
      );
    }
    return lines[lineIndex];
  }

  void _requireEditableLine(int lineIndex, ParsedLine line) {
    if (line.kind == LineKind.code ||
        line.kind == LineKind.codeFenceDelimiter) {
      throw MarkdownEditException(
        'Line $lineIndex is inside a code block and cannot be edited as metadata',
      );
    }
  }

  MarkdownDocument _appendMetadataToLine(ParsedLine line, String snippet) {
    final blockIds = line.metadata
        .where((m) => m.kind == InlineMetadataKind.blockId)
        .toList();
    if (blockIds.isEmpty) {
      final at = line.span.end;
      final newText = rawText.replaceRange(at, at, ' $snippet');
      return MarkdownDocument.parse(newText);
    }
    final blockIdStart = blockIds.first.span.start;
    var insertAt = blockIdStart;
    while (insertAt > line.span.start && _isSpaceOrTab(rawText, insertAt - 1)) {
      insertAt -= 1;
    }
    final newText = rawText.replaceRange(insertAt, blockIdStart, ' $snippet ');
    return MarkdownDocument.parse(newText);
  }

  @override
  String toString() =>
      'MarkdownDocument(${rawText.length} chars, ${lines.length} lines'
      '${frontmatter != null ? ', frontmatter' : ''})';
}

bool _isSpaceOrTab(String text, int index) =>
    text[index] == ' ' || text[index] == '\t';

/// `YamlEditor.update` requires every element of `path` except the last to
/// already exist (it won't auto-vivify intermediate maps the way, say,
/// `Map` bracket-chaining might). This walks each prefix of [path] and
/// creates an empty map at any that's missing, so
/// `setFrontmatterValue(['citrinium', 'status'], 'active')` works whether
/// or not a `citrinium:` map already exists in the frontmatter.
void _ensureParentMaps(YamlEditor editor, List<Object> path) {
  for (var i = 1; i < path.length; i++) {
    final prefix = path.sublist(0, i);
    try {
      editor.parseAt(prefix);
    } on ArgumentError {
      editor.update(prefix, <Object?, Object?>{});
    }
  }
}

String _snippetFor(InlineMetadataKind kind, String value) {
  switch (kind) {
    case InlineMetadataKind.date:
      return '📅 $value';
    case InlineMetadataKind.time:
      return '⏰$value';
    case InlineMetadataKind.recurrence:
      return '🔁 $value';
    case InlineMetadataKind.context:
      return '@$value';
    case InlineMetadataKind.tag:
      return '#$value';
    case InlineMetadataKind.blockId:
      return '^$value';
  }
}

String _lineEndingLiteral(LineEndingStyle style) {
  switch (style) {
    case LineEndingStyle.crlf:
      return '\r\n';
    case LineEndingStyle.cr:
      return '\r';
    case LineEndingStyle.lf:
    case LineEndingStyle.mixed:
    case LineEndingStyle.none:
      return '\n';
  }
}

/// A wikilink/embed paired with the [ParsedLine] it was found on, returned
/// by `MarkdownDocument.allLinks`.
@immutable
class WikiLinkRef {
  const WikiLinkRef({required this.line, required this.link});

  final ParsedLine line;
  final WikiLink link;
}

/// An inline metadata token paired with the [ParsedLine] it was found on,
/// returned by `MarkdownDocument.allMetadata`.
@immutable
class InlineMetadataRef {
  const InlineMetadataRef({required this.line, required this.metadata});

  final ParsedLine line;
  final InlineMetadata metadata;
}
