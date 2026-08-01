import 'package:meta/meta.dart';

/// Context for an active code fence block across lines.
@immutable
class FenceContext {
  const FenceContext({
    required this.fenceChar,
    required this.fenceLen,
    this.infoString,
  });

  final String fenceChar; // '`' or '~'
  final int fenceLen;
  final String? infoString;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FenceContext &&
          runtimeType == other.runtimeType &&
          fenceChar == other.fenceChar &&
          fenceLen == other.fenceLen &&
          infoString == other.infoString;

  @override
  int get hashCode => Object.hash(fenceChar, fenceLen, infoString);

  @override
  String toString() => 'FenceContext($fenceChar * $fenceLen, info: $infoString)';
}

/// Resumable per-line block state for early-termination incremental parsing.
@immutable
class BlockContext {
  const BlockContext({
    this.inFrontmatter = false,
    this.fenceContext,
    this.quoteDepth = 0,
  });

  static const initial = BlockContext();

  final bool inFrontmatter;
  final FenceContext? fenceContext;
  final int quoteDepth;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockContext &&
          runtimeType == other.runtimeType &&
          inFrontmatter == other.inFrontmatter &&
          fenceContext == other.fenceContext &&
          quoteDepth == other.quoteDepth;

  @override
  int get hashCode => Object.hash(inFrontmatter, fenceContext, quoteDepth);

  @override
  String toString() =>
      'BlockContext(frontmatter: $inFrontmatter, fence: $fenceContext, quote: $quoteDepth)';
}
