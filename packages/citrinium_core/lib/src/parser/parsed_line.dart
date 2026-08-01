import 'package:meta/meta.dart';

import 'bujo.dart';
import 'inline_metadata.dart';
import 'span.dart';
import 'task_state.dart';
import 'wikilink.dart';

/// What a body line is, structurally, per `design.md` §3.1/§3.2.
enum LineKind {
  /// Empty or whitespace-only.
  blank,

  /// ATX heading (`# ...` through `###### ...`).
  heading,

  /// `- [ ] ...` / `- [x] ...` / etc -- a checkbox task line.
  task,

  /// `- ○ ...` -- a BuJo event line.
  event,

  /// `- – ...` -- a BuJo note line.
  note,

  /// A bullet list line that isn't a task or BuJo event/note (e.g. `- just
  /// a note` with no signifier, or `* item`).
  listItem,

  /// Anything else: prose, thematic breaks, table rows, etc.
  text,

  /// A fenced-code-block opening or closing delimiter line (` ``` `/`~~~`).
  codeFenceDelimiter,

  /// Inside a fenced or indented code block. Never scanned for
  /// tasks/BuJo/headings/inline metadata/wikilinks -- see
  /// `code_blocks.dart`.
  code,
}

/// Checkbox task details for a [ParsedLine] with `kind == LineKind.task`.
@immutable
class TaskInfo {
  const TaskInfo({
    required this.stateKind,
    required this.markerChar,
    required this.bulletSpan,
    required this.checkboxSpan,
    required this.markerSpan,
    required this.contentSpan,
  });

  /// The classified state. [TaskStateKind.unknown] means [markerChar] isn't
  /// one of the recognized single characters -- preserved verbatim rather
  /// than normalized, per `docs/milestones/m0.md` W2.
  final TaskStateKind stateKind;

  /// The literal character between `[` and `]`, e.g. `' '`, `'x'`, or some
  /// unrecognized custom status character.
  final String markerChar;

  /// Span of the list bullet character (`-`, `*`, or `+`).
  final Span bulletSpan;

  /// Span of the full `[x]` checkbox, brackets included.
  final Span checkboxSpan;

  /// Span of just [markerChar] -- this is what `setTaskState` splices.
  final Span markerSpan;

  /// Span of the line's text after the checkbox (may be empty, e.g. a bare
  /// `- [ ]` with no description yet).
  final Span contentSpan;

  @override
  String toString() =>
      'TaskInfo($stateKind, marker: ${markerChar == ' ' ? "' '" : markerChar})';
}

/// BuJo event/note details for a [ParsedLine] with `kind == LineKind.event`
/// or `kind == LineKind.note`.
@immutable
class BujoLineInfo {
  const BujoLineInfo({
    required this.kind,
    required this.bulletSpan,
    required this.signifierSpan,
    required this.contentSpan,
  });

  final BujoKind kind;
  final Span bulletSpan;
  final Span signifierSpan;
  final Span contentSpan;

  @override
  String toString() => 'BujoLineInfo($kind)';
}

/// One body line of a `MarkdownDocument`: its classification, plus every
/// inline-metadata token and wikilink found on it, all with offsets into
/// the owning document's `rawText`.
@immutable
class ParsedLine {
  const ParsedLine({
    required this.index,
    required this.span,
    required this.kind,
    this.task,
    this.bujo,
    this.metadata = const [],
    this.links = const [],
  });

  /// 0-based index within the document body (frontmatter excluded, and not
  /// to be confused with a 0-based index into the whole file).
  final int index;

  /// Span of this line's content, excluding its line terminator.
  final Span span;

  final LineKind kind;

  /// Non-null iff `kind == LineKind.task`.
  final TaskInfo? task;

  /// Non-null iff `kind == LineKind.event || kind == LineKind.note`.
  final BujoLineInfo? bujo;

  /// Inline metadata found anywhere on this line (empty for blank/code
  /// lines, and for lines with none).
  final List<InlineMetadata> metadata;

  /// Wikilinks/embeds found anywhere on this line (empty for blank/code
  /// lines, and for lines with none).
  final List<WikiLink> links;

  @override
  String toString() => 'ParsedLine#$index($kind, $span)';
}
