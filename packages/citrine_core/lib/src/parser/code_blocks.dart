import 'raw_lines.dart';

/// How a given body line relates to code blocks, per
/// `docs/milestones/m0.md` W2: "`- [ ]` inside a fence must not parse as a
/// task, and wikilinks inside code must not become links."
enum CodeLineStatus {
  /// Not code -- eligible for task/BuJo/heading/metadata/wikilink parsing.
  none,

  /// A fenced-code-block opening or closing delimiter line itself (e.g.
  /// ` ```dart `). Not parsed as prose, but also not treated as "content".
  fenceDelimiter,

  /// Inside a fenced code block, or part of an indented code block.
  code,
}

final RegExp _fenceOpenRe = RegExp(r'^( {0,3})(`{3,}|~{3,})');

/// Computes the [CodeLineStatus] of every line in [lines] (which must be
/// the *body* lines -- frontmatter already stripped off -- in document
/// order), tracking fenced-code-block state across lines.
///
/// Indented-code detection (CommonMark-style: >=4 columns of leading
/// whitespace, tabs expanded to 4-column stops) is intentionally
/// conservative: a line only counts as indented code if it directly
/// follows a blank line, another indented-code line, or the start of the
/// document. This keeps 2-space (or even single 4-space) nested list
/// continuation lines -- which directly follow their non-blank parent
/// bullet line, never a blank line -- from being misclassified as code,
/// while still catching genuine indented code blocks (which CommonMark
/// itself disallows from interrupting a paragraph).
List<CodeLineStatus> computeCodeLineStatuses(List<RawLine> lines) {
  final statuses = List<CodeLineStatus>.filled(
    lines.length,
    CodeLineStatus.none,
  );

  var inFence = false;
  String fenceChar = '';
  var fenceLen = 0;

  for (var i = 0; i < lines.length; i++) {
    final content = lines[i].content;

    if (inFence) {
      if (_matchesFenceClose(content, fenceChar, fenceLen)) {
        statuses[i] = CodeLineStatus.fenceDelimiter;
        inFence = false;
        fenceChar = '';
        fenceLen = 0;
      } else {
        statuses[i] = CodeLineStatus.code;
      }
      continue;
    }

    final open = _fenceOpenRe.firstMatch(content);
    if (open != null) {
      statuses[i] = CodeLineStatus.fenceDelimiter;
      inFence = true;
      fenceChar = open.group(2)![0];
      fenceLen = open.group(2)!.length;
      continue;
    }

    if (content.trim().isNotEmpty && _indentWidth(content) >= 4) {
      final prevIsBlankOrCodeOrStart =
          i == 0 ||
          lines[i - 1].content.trim().isEmpty ||
          statuses[i - 1] == CodeLineStatus.code;
      if (prevIsBlankOrCodeOrStart) {
        statuses[i] = CodeLineStatus.code;
        continue;
      }
    }

    statuses[i] = CodeLineStatus.none;
  }

  return statuses;
}

bool _matchesFenceClose(String content, String fenceChar, int fenceLen) {
  final re = RegExp('^ {0,3}${RegExp.escape(fenceChar)}{$fenceLen,}[ \t]*\$');
  return re.hasMatch(content);
}

/// Width, in columns, of the leading run of spaces/tabs in [content] (tabs
/// expand to the next multiple of 4, matching CommonMark's tab-expansion
/// rule for indented code blocks).
int _indentWidth(String content) {
  var width = 0;
  for (final unit in content.codeUnits) {
    if (unit == 0x20) {
      width += 1;
    } else if (unit == 0x09) {
      width += 4 - (width % 4);
    } else {
      break;
    }
  }
  return width;
}
