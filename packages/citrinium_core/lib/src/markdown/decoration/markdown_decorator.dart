import '../../parser/bujo.dart';

import 'block_context.dart';
import 'decoration.dart';

class LineDecorationResult {
  const LineDecorationResult({
    required this.decorations,
    required this.exitingContext,
    required this.nextNodeId,
  });

  final List<Decoration> decorations;
  final BlockContext exitingContext;
  final int nextNodeId;
}

final RegExp _fenceOpenRe = RegExp(r'^( {0,3})(`{3,}|~{3,})([ \t]*(.*))?$');
final RegExp _frontmatterDelimiterRe = RegExp(r'^---[ \t]*$');
final RegExp _thematicBreakRe =
    RegExp(r'^[ \t]{0,3}(?:\*[ \t]*){3,}$|^[ \t]{0,3}(?:-[ \t]*){3,}$|^[ \t]{0,3}(?:_[ \t]*){3,}$');
final RegExp _headingRe = RegExp(r'^[ \t]{0,3}(#{1,6})([ \t]+.*)?$');
final RegExp _taskRe =
    RegExp(r'^([ \t]*)([-*+])([ \t]+)\[(.)\](?:([ \t]+)(.*))?$');
final RegExp _bujoRe =
    RegExp(r'^([ \t]*)([-*+])([ \t]+)([○–])(?:([ \t]+)(.*))?$');
final RegExp _listItemRe = RegExp(r'^([ \t]*)([-*+]|\d+\.)([ \t]+)(.*)$');

final RegExp _wikilinkRe =
    RegExp(r'(!?)\[\[([^\]\|]+)(?:\|([^\]]+))?\]\]');
final RegExp _inlineLinkRe = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
final RegExp _autolinkRe = RegExp(r'<([a-zA-Z][a-zA-Z0-9+\-.]*:[^>\s]+)>');

final RegExp _dateRe = RegExp(r'📅[ \t]*(\d{4}-\d{2}-\d{2})');
final RegExp _timeRe = RegExp(r'⏰[ \t]*(\d{1,2}:\d{2})');
final RegExp _contextRe = RegExp(r'@([A-Za-z0-9_\-/]+)');
final RegExp _tagRe = RegExp(r'#([A-Za-z0-9_\-/]+)');
final RegExp _blockIdRe = RegExp(r'\^([A-Za-z0-9\-]+)');
final RegExp _recurrenceMarker = RegExp(r'🔁[ \t]*');
const List<String> _followingMarkers = ['📅', '⏰', '@', '#', '^'];

/// Pure functional line decorator for design.md §7 Live Preview.
class MarkdownDecorator {
  static LineDecorationResult decorateLine({
    required String lineText,
    required int lineOffset,
    required int lineNumber, // 0-based
    required BlockContext enteringContext,
    required int startNodeId,
  }) {
    var currentNodeId = startNodeId;
    final decorations = <Decoration>[];

    // 1. Frontmatter check
    if (lineNumber == 0 && enteringContext.inFrontmatter == false) {
      if (_frontmatterDelimiterRe.hasMatch(lineText)) {
        decorations.add(
          Decoration(
            start: lineOffset,
            end: lineOffset + lineText.length,
            kind: DecorationKind.frontmatterDelimiter,
            role: DecorationRole.whole,
            nodeId: currentNodeId++,
          ),
        );
        return LineDecorationResult(
          decorations: decorations,
          exitingContext: const BlockContext(inFrontmatter: true),
          nextNodeId: currentNodeId,
        );
      }
    } else if (enteringContext.inFrontmatter) {
      if (_frontmatterDelimiterRe.hasMatch(lineText)) {
        decorations.add(
          Decoration(
            start: lineOffset,
            end: lineOffset + lineText.length,
            kind: DecorationKind.frontmatterDelimiter,
            role: DecorationRole.whole,
            nodeId: currentNodeId++,
          ),
        );
        return LineDecorationResult(
          decorations: decorations,
          exitingContext: const BlockContext(inFrontmatter: false),
          nextNodeId: currentNodeId,
        );
      } else {
        decorations.add(
          Decoration(
            start: lineOffset,
            end: lineOffset + lineText.length,
            kind: DecorationKind.frontmatterDelimiter,
            role: DecorationRole.whole,
            nodeId: currentNodeId++,
          ),
        );
        return LineDecorationResult(
          decorations: decorations,
          exitingContext: enteringContext,
          nextNodeId: currentNodeId,
        );
      }
    }

    // 2. Code fence check
    if (enteringContext.fenceContext != null) {
      final fence = enteringContext.fenceContext!;
      final closeRe = RegExp(
          '^ {0,3}${RegExp.escape(fence.fenceChar)}{${fence.fenceLen},}[ \\t]*\$');
      if (closeRe.hasMatch(lineText)) {
        decorations.add(
          Decoration(
            start: lineOffset,
            end: lineOffset + lineText.length,
            kind: DecorationKind.fenceDelimiter,
            role: DecorationRole.closeMarker,
            nodeId: currentNodeId++,
          ),
        );
        return LineDecorationResult(
          decorations: decorations,
          exitingContext: const BlockContext(fenceContext: null),
          nextNodeId: currentNodeId,
        );
      } else {
        decorations.add(
          Decoration(
            start: lineOffset,
            end: lineOffset + lineText.length,
            kind: DecorationKind.inlineCode,
            role: DecorationRole.content,
            nodeId: currentNodeId++,
          ),
        );
        return LineDecorationResult(
          decorations: decorations,
          exitingContext: enteringContext,
          nextNodeId: currentNodeId,
        );
      }
    } else {
      final openMatch = _fenceOpenRe.firstMatch(lineText);
      if (openMatch != null) {
        final fenceChar = openMatch.group(2)![0];
        final fenceLen = openMatch.group(2)!.length;
        final infoStr = openMatch.group(4)?.trim();
        decorations.add(
          Decoration(
            start: lineOffset,
            end: lineOffset + lineText.length,
            kind: DecorationKind.fenceDelimiter,
            role: DecorationRole.openMarker,
            nodeId: currentNodeId++,
            payload: infoStr,
          ),
        );
        return LineDecorationResult(
          decorations: decorations,
          exitingContext: BlockContext(
            fenceContext: FenceContext(
              fenceChar: fenceChar,
              fenceLen: fenceLen,
              infoString: infoStr,
            ),
          ),
          nextNodeId: currentNodeId,
        );
      }
    }

    // 3. Thematic break
    if (_thematicBreakRe.hasMatch(lineText)) {
      decorations.add(
        Decoration(
          start: lineOffset,
          end: lineOffset + lineText.length,
          kind: DecorationKind.thematicBreak,
          role: DecorationRole.whole,
          nodeId: currentNodeId++,
        ),
      );
      return LineDecorationResult(
        decorations: decorations,
        exitingContext: const BlockContext(),
        nextNodeId: currentNodeId,
      );
    }

    // Line scanning for block markers & inline elements
    var linePos = 0;
    final excludeRanges = <_Range>[];

    // Check blockquote
    var quoteCount = 0;
    while (linePos < lineText.length) {
      if (lineText[linePos] == ' ' || lineText[linePos] == '\t') {
        linePos++;
      } else if (lineText[linePos] == '>') {
        quoteCount++;
        final start = lineOffset + linePos;
        linePos++;
        if (linePos < lineText.length && lineText[linePos] == ' ') {
          linePos++;
        }
        decorations.add(
          Decoration(
            start: start,
            end: lineOffset + linePos,
            kind: DecorationKind.blockquoteMarker,
            role: DecorationRole.openMarker,
            nodeId: currentNodeId++,
            level: quoteCount,
          ),
        );
      } else {
        break;
      }
    }

    final remaining = lineText.substring(linePos);

    // ATX Heading
    final headingMatch = _headingRe.firstMatch(remaining);
    if (headingMatch != null) {
      final hashes = headingMatch.group(1)!;
      final level = hashes.length;
      final hashStart = lineOffset + linePos + headingMatch.start;
      final hashEnd = hashStart + hashes.length;

      decorations.add(
        Decoration(
          start: hashStart,
          end: hashEnd,
          kind: DecorationKind.heading,
          role: DecorationRole.openMarker,
          nodeId: currentNodeId,
          level: level,
        ),
      );

      final contentText = headingMatch.group(2) ?? '';
      if (contentText.isNotEmpty) {
        decorations.add(
          Decoration(
            start: hashEnd,
            end: lineOffset + lineText.length,
            kind: DecorationKind.heading,
            role: DecorationRole.content,
            nodeId: currentNodeId,
            level: level,
          ),
        );
      }
      currentNodeId++;

      // Scan inline nodes inside heading content
      final contentStartPos = linePos + hashes.length;
      _scanInlineElements(
        lineText,
        contentStartPos,
        lineOffset,
        decorations,
        excludeRanges,
        () => currentNodeId++,
      );

      return LineDecorationResult(
        decorations: decorations..sort((a, b) => a.start.compareTo(b.start)),
        exitingContext: BlockContext(quoteDepth: quoteCount),
        nextNodeId: currentNodeId,
      );
    }

    // Task line
    final taskMatch = _taskRe.firstMatch(remaining);
    if (taskMatch != null) {
      var relPos = linePos + taskMatch.group(1)!.length;
      final bulletStr = taskMatch.group(2)!;
      final bulletStart = lineOffset + relPos;
      relPos += bulletStr.length;

      relPos += taskMatch.group(3)!.length; // space before `[`
      relPos += 1; // `[`
      final markerChar = taskMatch.group(4)!;
      final markerStart = lineOffset + relPos;
      relPos += markerChar.length;
      final markerEnd = lineOffset + relPos;
      relPos += 1; // `]`
      final bracketEnd = lineOffset + relPos;

      // `- [` marker prefix
      decorations.add(
        Decoration(
          start: bulletStart,
          end: markerStart,
          kind: DecorationKind.taskMarker,
          role: DecorationRole.openMarker,
          nodeId: currentNodeId,
        ),
      );
      // marker char
      decorations.add(
        Decoration(
          start: markerStart,
          end: markerEnd,
          kind: DecorationKind.taskMarker,
          role: DecorationRole.content,
          nodeId: currentNodeId,
          payload: markerChar,
        ),
      );
      // `]` marker
      decorations.add(
        Decoration(
          start: markerEnd,
          end: bracketEnd,
          kind: DecorationKind.taskMarker,
          role: DecorationRole.closeMarker,
          nodeId: currentNodeId,
        ),
      );
      currentNodeId++;

      final contentStartPos = relPos;
      _scanInlineElements(
        lineText,
        contentStartPos,
        lineOffset,
        decorations,
        excludeRanges,
        () => currentNodeId++,
      );

      return LineDecorationResult(
        decorations: decorations..sort((a, b) => a.start.compareTo(b.start)),
        exitingContext: BlockContext(quoteDepth: quoteCount),
        nextNodeId: currentNodeId,
      );
    }

    // BuJo line
    final bujoMatch = _bujoRe.firstMatch(remaining);
    if (bujoMatch != null) {
      var relPos = linePos + bujoMatch.group(1)!.length;
      final bulletStr = bujoMatch.group(2)!;
      final bulletStart = lineOffset + relPos;
      relPos += bulletStr.length;

      decorations.add(
        Decoration(
          start: bulletStart,
          end: lineOffset + relPos,
          kind: DecorationKind.listMarker,
          role: DecorationRole.openMarker,
          nodeId: currentNodeId++,
        ),
      );

      relPos += bujoMatch.group(3)!.length;
      final signifierChar = bujoMatch.group(4)!;
      final sigStart = lineOffset + relPos;
      relPos += signifierChar.length;

      final bujoKind = bujoSignifiers[signifierChar]!;
      final decKind = bujoKind == BujoKind.event
          ? DecorationKind.eventBullet
          : DecorationKind.noteBullet;

      decorations.add(
        Decoration(
          start: sigStart,
          end: lineOffset + relPos,
          kind: decKind,
          role: DecorationRole.whole,
          nodeId: currentNodeId++,
          payload: signifierChar,
        ),
      );

      _scanInlineElements(
        lineText,
        relPos,
        lineOffset,
        decorations,
        excludeRanges,
        () => currentNodeId++,
      );

      return LineDecorationResult(
        decorations: decorations..sort((a, b) => a.start.compareTo(b.start)),
        exitingContext: BlockContext(quoteDepth: quoteCount),
        nextNodeId: currentNodeId,
      );
    }

    // Plain List Item
    final listItemMatch = _listItemRe.firstMatch(remaining);
    if (listItemMatch != null) {
      var relPos = linePos + listItemMatch.group(1)!.length;
      final bulletStr = listItemMatch.group(2)!;
      final bulletStart = lineOffset + relPos;
      relPos += bulletStr.length;

      decorations.add(
        Decoration(
          start: bulletStart,
          end: lineOffset + relPos,
          kind: DecorationKind.listMarker,
          role: DecorationRole.openMarker,
          nodeId: currentNodeId++,
        ),
      );

      _scanInlineElements(
        lineText,
        relPos,
        lineOffset,
        decorations,
        excludeRanges,
        () => currentNodeId++,
      );

      return LineDecorationResult(
        decorations: decorations..sort((a, b) => a.start.compareTo(b.start)),
        exitingContext: BlockContext(quoteDepth: quoteCount),
        nextNodeId: currentNodeId,
      );
    }

    // Plain text / prose line
    _scanInlineElements(
      lineText,
      linePos,
      lineOffset,
      decorations,
      excludeRanges,
      () => currentNodeId++,
    );

    return LineDecorationResult(
      decorations: decorations..sort((a, b) => a.start.compareTo(b.start)),
      exitingContext: BlockContext(quoteDepth: quoteCount),
      nextNodeId: currentNodeId,
    );
  }

  static void _scanInlineElements(
    String lineText,
    int startPos,
    int lineOffset,
    List<Decoration> decorations,
    List<_Range> excludeRanges,
    int Function() nextNodeId,
  ) {
    // 1. Inline code (backticks)
    final backtickRe = RegExp(r'(`+)(.*?)\1');
    for (final m in backtickRe.allMatches(lineText, startPos)) {
      final range = _Range(lineOffset + m.start, lineOffset + m.end);
      if (excludeRanges.any((e) => e.overlaps(range))) continue;
      excludeRanges.add(range);

      final nodeId = nextNodeId();
      final backticksLen = m.group(1)!.length;
      decorations.add(
        Decoration(
          start: lineOffset + m.start,
          end: lineOffset + m.start + backticksLen,
          kind: DecorationKind.inlineCode,
          role: DecorationRole.openMarker,
          nodeId: nodeId,
        ),
      );
      decorations.add(
        Decoration(
          start: lineOffset + m.start + backticksLen,
          end: lineOffset + m.end - backticksLen,
          kind: DecorationKind.inlineCode,
          role: DecorationRole.content,
          nodeId: nodeId,
        ),
      );
      decorations.add(
        Decoration(
          start: lineOffset + m.end - backticksLen,
          end: lineOffset + m.end,
          kind: DecorationKind.inlineCode,
          role: DecorationRole.closeMarker,
          nodeId: nodeId,
        ),
      );
    }

    // 2. Wikilinks / embeds: [[target]] or ![[target]]
    for (final m in _wikilinkRe.allMatches(lineText, startPos)) {
      final range = _Range(lineOffset + m.start, lineOffset + m.end);
      if (excludeRanges.any((e) => e.overlaps(range))) continue;
      excludeRanges.add(range);

      final nodeId = nextNodeId();
      final isEmbed = m.group(1) == '!';
      final target = m.group(2)!;
      final alias = m.group(3);

      final kind = isEmbed ? DecorationKind.embed : DecorationKind.wikilink;
      final openLen = isEmbed ? 3 : 2; // `![[` or `[[`

      decorations.add(
        Decoration(
          start: lineOffset + m.start,
          end: lineOffset + m.start + openLen,
          kind: kind,
          role: DecorationRole.openMarker,
          nodeId: nodeId,
          payload: target,
        ),
      );

      if (alias != null) {
        final targetEndPos = m.start + openLen + target.length;
        decorations.add(
          Decoration(
            start: lineOffset + m.start + openLen,
            end: lineOffset + targetEndPos,
            kind: kind,
            role: DecorationRole.content,
            nodeId: nodeId,
            payload: target,
          ),
        );
        decorations.add(
          Decoration(
            start: lineOffset + targetEndPos,
            end: lineOffset + targetEndPos + 1, // `|`
            kind: DecorationKind.wikilinkAlias,
            role: DecorationRole.openMarker,
            nodeId: nodeId,
          ),
        );
        decorations.add(
          Decoration(
            start: lineOffset + targetEndPos + 1,
            end: lineOffset + m.end - 2,
            kind: DecorationKind.wikilinkAlias,
            role: DecorationRole.content,
            nodeId: nodeId,
            payload: alias,
          ),
        );
      } else {
        decorations.add(
          Decoration(
            start: lineOffset + m.start + openLen,
            end: lineOffset + m.end - 2,
            kind: kind,
            role: DecorationRole.content,
            nodeId: nodeId,
            payload: target,
          ),
        );
      }

      decorations.add(
        Decoration(
          start: lineOffset + m.end - 2,
          end: lineOffset + m.end,
          kind: kind,
          role: DecorationRole.closeMarker,
          nodeId: nodeId,
        ),
      );
    }

    // 3. Inline links [text](url)
    for (final m in _inlineLinkRe.allMatches(lineText, startPos)) {
      final range = _Range(lineOffset + m.start, lineOffset + m.end);
      if (excludeRanges.any((e) => e.overlaps(range))) continue;
      excludeRanges.add(range);

      final nodeId = nextNodeId();
      final text = m.group(1)!;
      final url = m.group(2)!;

      // `[`
      decorations.add(
        Decoration(
          start: lineOffset + m.start,
          end: lineOffset + m.start + 1,
          kind: DecorationKind.inlineLink,
          role: DecorationRole.openMarker,
          nodeId: nodeId,
        ),
      );
      // text
      decorations.add(
        Decoration(
          start: lineOffset + m.start + 1,
          end: lineOffset + m.start + 1 + text.length,
          kind: DecorationKind.inlineLink,
          role: DecorationRole.content,
          nodeId: nodeId,
          payload: url,
        ),
      );
      // `](url)`
      decorations.add(
        Decoration(
          start: lineOffset + m.start + 1 + text.length,
          end: lineOffset + m.end,
          kind: DecorationKind.inlineLink,
          role: DecorationRole.closeMarker,
          nodeId: nodeId,
        ),
      );
    }

    // 4. Autolinks <http...>
    for (final m in _autolinkRe.allMatches(lineText, startPos)) {
      final range = _Range(lineOffset + m.start, lineOffset + m.end);
      if (excludeRanges.any((e) => e.overlaps(range))) continue;
      excludeRanges.add(range);

      final nodeId = nextNodeId();
      final url = m.group(1)!;

      decorations.add(
        Decoration(
          start: lineOffset + m.start,
          end: lineOffset + m.start + 1,
          kind: DecorationKind.autolink,
          role: DecorationRole.openMarker,
          nodeId: nodeId,
        ),
      );
      decorations.add(
        Decoration(
          start: lineOffset + m.start + 1,
          end: lineOffset + m.end - 1,
          kind: DecorationKind.autolink,
          role: DecorationRole.content,
          nodeId: nodeId,
          payload: url,
        ),
      );
      decorations.add(
        Decoration(
          start: lineOffset + m.end - 1,
          end: lineOffset + m.end,
          kind: DecorationKind.autolink,
          role: DecorationRole.closeMarker,
          nodeId: nodeId,
        ),
      );
    }

    // 5. Citrinium inline metadata
    void addMetaMatches(RegExp re, DecorationKind kind) {
      for (final m in re.allMatches(lineText, startPos)) {
        final range = _Range(lineOffset + m.start, lineOffset + m.end);
        if (excludeRanges.any((e) => e.overlaps(range))) continue;
        excludeRanges.add(range);

        final nodeId = nextNodeId();
        final val = m.group(1)!;
        final valOffsetInMatch = m.group(0)!.indexOf(val);

        decorations.add(
          Decoration(
            start: lineOffset + m.start,
            end: lineOffset + m.start + valOffsetInMatch,
            kind: kind,
            role: DecorationRole.openMarker,
            nodeId: nodeId,
          ),
        );
        decorations.add(
          Decoration(
            start: lineOffset + m.start + valOffsetInMatch,
            end: lineOffset + m.end,
            kind: kind,
            role: DecorationRole.content,
            nodeId: nodeId,
            payload: val,
          ),
        );
      }
    }

    addMetaMatches(_dateRe, DecorationKind.dueDate);
    addMetaMatches(_timeRe, DecorationKind.dueTime);
    addMetaMatches(_contextRe, DecorationKind.context);
    addMetaMatches(_tagRe, DecorationKind.tag);
    addMetaMatches(_blockIdRe, DecorationKind.blockId);

    // Recurrence 🔁
    for (final m in _recurrenceMarker.allMatches(lineText, startPos)) {
      final valueStart = m.end;
      var valueEnd = lineText.length;
      var i = valueStart;
      while (i < lineText.length) {
        final isBoundary = i > valueStart &&
            (lineText[i - 1] == ' ' || lineText[i - 1] == '\t');
        if (isBoundary &&
            _followingMarkers
                .any((marker) => lineText.startsWith(marker, i))) {
          valueEnd = i;
          break;
        }
        i++;
      }
      while (valueEnd > valueStart &&
          (lineText[valueEnd - 1] == ' ' || lineText[valueEnd - 1] == '\t')) {
        valueEnd--;
      }
      if (valueEnd <= valueStart) continue;

      final range = _Range(lineOffset + m.start, lineOffset + valueEnd);
      if (excludeRanges.any((e) => e.overlaps(range))) continue;
      excludeRanges.add(range);

      final nodeId = nextNodeId();
      final val = lineText.substring(valueStart, valueEnd);

      decorations.add(
        Decoration(
          start: lineOffset + m.start,
          end: lineOffset + m.end,
          kind: DecorationKind.recurrence,
          role: DecorationRole.openMarker,
          nodeId: nodeId,
        ),
      );
      decorations.add(
        Decoration(
          start: lineOffset + m.end,
          end: lineOffset + valueEnd,
          kind: DecorationKind.recurrence,
          role: DecorationRole.content,
          nodeId: nodeId,
          payload: val,
        ),
      );
    }

    // 6. Emphasis, Strong, Strikethrough, Highlight with flanking rules
    _scanEmphasisAndFormatting(
      lineText,
      startPos,
      lineOffset,
      decorations,
      excludeRanges,
      nextNodeId,
    );
  }

  static void _scanEmphasisAndFormatting(
    String text,
    int startPos,
    int lineOffset,
    List<Decoration> decorations,
    List<_Range> excludeRanges,
    int Function() nextNodeId,
  ) {
    // Delimiters:
    // ** or __ -> strong
    // * or _ -> emphasis
    // ~~ -> strikethrough
    // == -> highlight
    final delims = <_DelimMatch>[];

    final reg = RegExp(r'(\*\*|__|~~|==|\*|_)');
    for (final m in reg.allMatches(text, startPos)) {
      final range = _Range(lineOffset + m.start, lineOffset + m.end);
      if (excludeRanges.any((e) => e.overlaps(range))) continue;

      final str = m.group(1)!;
      final idx = m.start;

      // CommonMark flanking checks
      final prevChar = idx > 0 ? text[idx - 1] : ' ';
      final nextChar =
          idx + str.length < text.length ? text[idx + str.length] : ' ';

      final leftFlanking = !_isUnicodeWhitespace(nextChar) &&
          (!_isPunctuation(nextChar) ||
              _isUnicodeWhitespace(prevChar) ||
              _isPunctuation(prevChar));

      final rightFlanking = !_isUnicodeWhitespace(prevChar) &&
          (!_isPunctuation(prevChar) ||
              _isUnicodeWhitespace(nextChar) ||
              _isPunctuation(nextChar));

      final canOpen = str.startsWith('_')
          ? (leftFlanking && (!rightFlanking || _isPunctuation(prevChar)))
          : leftFlanking;

      final canClose = str.startsWith('_')
          ? (rightFlanking && (!leftFlanking || _isPunctuation(nextChar)))
          : rightFlanking;

      delims.add(
        _DelimMatch(
          str: str,
          start: idx,
          end: idx + str.length,
          canOpen: canOpen,
          canClose: canClose,
        ),
      );
    }

    // Stack matching
    final stack = <_DelimMatch>[];
    for (final d in delims) {
      if (d.canClose) {
        var matchIdx = -1;
        for (var i = stack.length - 1; i >= 0; i--) {
          if (stack[i].str == d.str && stack[i].canOpen) {
            matchIdx = i;
            break;
          }
        }

        if (matchIdx != -1) {
          final openD = stack.removeAt(matchIdx);
          stack.removeRange(matchIdx, stack.length);

          final nodeId = nextNodeId();
          DecorationKind kind;
          if (d.str == '**' || d.str == '__') {
            kind = DecorationKind.strong;
          } else if (d.str == '*' || d.str == '_') {
            kind = DecorationKind.emphasis;
          } else if (d.str == '~~') {
            kind = DecorationKind.strikethrough;
          } else {
            kind = DecorationKind.highlight;
          }

          decorations.add(
            Decoration(
              start: lineOffset + openD.start,
              end: lineOffset + openD.end,
              kind: kind,
              role: DecorationRole.openMarker,
              nodeId: nodeId,
            ),
          );
          decorations.add(
            Decoration(
              start: lineOffset + openD.end,
              end: lineOffset + d.start,
              kind: kind,
              role: DecorationRole.content,
              nodeId: nodeId,
            ),
          );
          decorations.add(
            Decoration(
              start: lineOffset + d.start,
              end: lineOffset + d.end,
              kind: kind,
              role: DecorationRole.closeMarker,
              nodeId: nodeId,
            ),
          );
          continue;
        }
      }

      if (d.canOpen) {
        stack.add(d);
      }
    }
  }

  static bool _isUnicodeWhitespace(String ch) {
    return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
  }

  static bool _isPunctuation(String ch) {
    if (ch.isEmpty) return false;
    final code = ch.codeUnitAt(0);
    return (code >= 33 && code <= 47) ||
        (code >= 58 && code <= 64) ||
        (code >= 91 && code <= 96) ||
        (code >= 123 && code <= 126);
  }
}

class _Range {
  const _Range(this.start, this.end);
  final int start;
  final int end;

  bool overlaps(_Range other) {
    return start < other.end && other.start < end;
  }
}

class _DelimMatch {
  _DelimMatch({
    required this.str,
    required this.start,
    required this.end,
    required this.canOpen,
    required this.canClose,
  });

  final String str;
  final int start;
  final int end;
  final bool canOpen;
  final bool canClose;
}
