import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;
import 'package:meta/meta.dart';

import '../parser/markdown_document.dart';
import '../parser/parsed_line.dart';

/// Unified rapid-log entry classification (`D-01`, `docs/milestones/m1.md` W1).
enum DomainEntryKind {
  task,
  event,
  note,
  untyped,
}

/// A unified rapid-log entry (`D-01`) with single-level indent-based child-line
/// grouping for attached Markdown note bodies (`D-14`) and lightweight comments
/// (`D-18`), plus a content-hash identity key (`W1`) for stable UI diffing
/// across incremental reparses.
@immutable
class GroupedEntry {
  const GroupedEntry({
    required this.kind,
    required this.parentLine,
    required this.childLines,
    required this.childBodyText,
    required this.contentHash,
    this.documentId,
    this.relPath,
  });

  final DomainEntryKind kind;
  final ParsedLine parentLine;
  final List<ParsedLine> childLines;
  final String childBodyText;
  final String contentHash;
  final int? documentId;
  final String? relPath;

  int get lineIndex => parentLine.index;
  bool get hasChildren => childBodyText.isNotEmpty;

  /// Stable identity key combining `(documentId/relPath, lineIndex)` with
  /// [contentHash] so callers can re-match an entry even when lines above it
  /// are inserted or deleted.
  String get stableIdentity =>
      '${relPath ?? documentId ?? 'doc'}:${parentLine.index}:$contentHash';
}

/// Computes single-level indent-based parent/child entry groupings (`W1`, `W7`,
/// `D-01`, `D-14`, `D-18`) over a [MarkdownDocument]'s flat `List<ParsedLine>`.
class EntryHierarchy {
  const EntryHierarchy._();

  /// Groups all top-level rapid-log entries (`task`, `event`, `note`, or
  /// untyped `listItem`) in [doc] along with their immediately following
  /// indented child note/comment lines (restricted to one level of nesting per
  /// `docs/milestones/m1.md` W1/W7).
  static List<GroupedEntry> groupDocumentEntries(
    MarkdownDocument doc, {
    int? documentId,
    String? relPath,
  }) {
    final results = <GroupedEntry>[];
    var i = 0;

    while (i < doc.lines.length) {
      final line = doc.lines[i];
      final entryKind = _classifyEntryKind(line.kind);
      if (entryKind == null) {
        i++;
        continue;
      }

      final range = doc.childBlockRangeForLine(i);
      final childLines = <ParsedLine>[
        for (var c = range.startLine; c < range.endLineExclusive; c++)
          doc.lines[c],
      ];
      final childBodyText = doc.readChildBlockText(i);

      final parentRaw = doc.rawText.substring(line.span.start, line.span.end);
      final digestInput = '$parentRaw\n$childBodyText';
      final hash = sha256
          .convert(utf8.encode(digestInput))
          .toString()
          .substring(0, 12);

      results.add(
        GroupedEntry(
          kind: entryKind,
          parentLine: line,
          childLines: childLines,
          childBodyText: childBodyText,
          contentHash: hash,
          documentId: documentId,
          relPath: relPath,
        ),
      );

      // Advance past the consumed child block so indented child lines are
      // grouped under their parent rather than emitted as separate top-level
      // entries (single-level nesting rule).
      i = range.endLineExclusive > i + 1 ? range.endLineExclusive : i + 1;
    }

    return results;
  }

  /// Re-matches a target entry after an incremental reparse: prefers the exact
  /// `lineIndex` if its `contentHash` still matches; otherwise searches for a
  /// nearby entry with the same `contentHash`.
  static GroupedEntry? rematchEntry(
    List<GroupedEntry> updatedEntries, {
    required int previousLineIndex,
    required String previousContentHash,
  }) {
    for (final e in updatedEntries) {
      if (e.lineIndex == previousLineIndex &&
          e.contentHash == previousContentHash) {
        return e;
      }
    }
    for (final e in updatedEntries) {
      if (e.contentHash == previousContentHash) {
        return e;
      }
    }
    for (final e in updatedEntries) {
      if (e.lineIndex == previousLineIndex) {
        return e;
      }
    }
    return null;
  }

  static DomainEntryKind? _classifyEntryKind(LineKind kind) {
    switch (kind) {
      case LineKind.task:
        return DomainEntryKind.task;
      case LineKind.event:
        return DomainEntryKind.event;
      case LineKind.note:
        return DomainEntryKind.note;
      case LineKind.listItem:
        return DomainEntryKind.untyped;
      case LineKind.blank:
      case LineKind.heading:
      case LineKind.text:
      case LineKind.codeFenceDelimiter:
      case LineKind.code:
        return null;
    }
  }
}
