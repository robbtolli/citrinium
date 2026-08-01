import 'package:meta/meta.dart';

/// A half-open range `[start, end)` of **UTF-16 code-unit offsets** into some
/// `MarkdownDocument.rawText`.
///
/// Per `docs/milestones/m0.md` W2 / `design.md` §7 §10, offsets are Dart
/// `String` code-unit offsets everywhere -- never byte offsets, never
/// grapheme-cluster or rune counts. This matters because inline metadata
/// markers (`📅⏰🔁`) are outside the Basic Multilingual Plane and are
/// represented as UTF-16 surrogate pairs (2 code units each); using rune
/// counts here would silently desync from `String.substring`.
@immutable
class Span {
  const Span(this.start, this.end)
    : assert(end >= start, 'Span end must be >= start');

  /// Inclusive start offset.
  final int start;

  /// Exclusive end offset.
  final int end;

  int get length => end - start;

  bool get isEmpty => start == end;

  bool get isNotEmpty => !isEmpty;

  /// The substring of [source] this span covers.
  String of(String source) => source.substring(start, end);

  /// Whether this span and [other] share any offsets.
  bool overlaps(Span other) => start < other.end && other.start < end;

  /// Whether [offset] falls within `[start, end)`.
  bool contains(int offset) => offset >= start && offset < end;

  /// Returns a new [Span] shifted by [delta] code units. Used when an edit
  /// earlier in the document changes the length of the text, so spans after
  /// the edit point stay accurate without a full reparse.
  Span shift(int delta) => Span(start + delta, end + delta);

  @override
  bool operator ==(Object other) =>
      other is Span && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'Span($start, $end)';
}
