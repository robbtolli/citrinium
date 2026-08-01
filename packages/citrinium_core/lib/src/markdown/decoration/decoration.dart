import 'package:meta/meta.dart';

/// Semantic decoration kinds for the design.md §7 Live Preview editor.
enum DecorationKind {
  // Inline emphasis
  strong,
  emphasis,
  strikethrough,
  highlight,
  inlineCode,

  // Structure
  heading,
  listMarker,
  bulletGlyph,
  taskMarker,
  blockquoteMarker,
  fenceDelimiter,
  frontmatterDelimiter,
  thematicBreak,

  // Links
  wikilink,
  wikilinkAlias,
  embed,
  inlineLink,
  autolink,

  // Citrinium inline metadata (design.md §3.2)
  dueDate,
  dueTime,
  recurrence,
  context,
  tag,
  blockId,
  signifier,

  // BuJo bullets (design.md §3.2)
  eventBullet,
  noteBullet,
}

/// Which part of a syntax node a decoration span covers.
enum DecorationRole {
  openMarker,
  closeMarker,
  content,
  whole,
}

/// A semantic decoration span with offsets into the document's raw text.
@immutable
class Decoration {
  const Decoration({
    required this.start,
    required this.end,
    required this.kind,
    required this.role,
    required this.nodeId,
    this.level,
    this.payload,
  });

  /// Code-unit start offset in rawText.
  final int start;

  /// Code-unit end offset in rawText.
  final int end;

  /// The decoration kind.
  final DecorationKind kind;

  /// Role of this span relative to its syntax node.
  final DecorationRole role;

  /// Integer grouping markers and content belonging to the same syntax node.
  final int nodeId;

  /// Heading level, list depth, or quote depth if applicable.
  final int? level;

  /// Extra payload (e.g. link target, tag name, parsed date).
  final String? payload;

  Decoration copyWithRange(int newStart, int newEnd) {
    return Decoration(
      start: newStart,
      end: newEnd,
      kind: kind,
      role: role,
      nodeId: nodeId,
      level: level,
      payload: payload,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Decoration &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          kind == other.kind &&
          role == other.role &&
          nodeId == other.nodeId &&
          level == other.level &&
          payload == other.payload;

  @override
  int get hashCode =>
      Object.hash(start, end, kind, role, nodeId, level, payload);

  @override
  String toString() =>
      'Decoration($kind, role: $role, range: [$start, $end), node: $nodeId, level: $level, payload: $payload)';
}
