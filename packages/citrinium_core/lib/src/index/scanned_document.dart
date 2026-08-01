import 'package:meta/meta.dart';

/// A single wikilink/embed found in a [ScannedDocument], not yet resolved to
/// a target document id (that's [IndexService]'s job, since it needs
/// visibility across the whole vault).
@immutable
class ScannedLink {
  const ScannedLink({
    required this.sourceLineIndex,
    required this.targetRaw,
    required this.isEmbed,
  });

  /// The body line index (see `ParsedLine.index`) the link was found on.
  /// Used to correlate with a [ScannedEntry.lineIndex] after entries are
  /// inserted and have real row ids -- `null` if the link was on a line
  /// that isn't itself an indexed entry (e.g. a plain prose paragraph).
  final int? sourceLineIndex;

  final String targetRaw;
  final bool isEmbed;

  String get kind => isEmbed ? 'embed' : 'wikilink';
}

/// One indexed rapid-log line (task / BuJo event / BuJo note / untyped
/// bullet), per `docs/milestones/m0.md` W3's `entries` table.
@immutable
class ScannedEntry {
  const ScannedEntry({
    required this.lineIndex,
    required this.charStart,
    required this.charEnd,
    required this.kind,
    required this.text,
    this.blockId,
    this.taskState,
    this.dueDate,
    this.dueTime,
    this.recurrenceRaw,
    this.contexts = const [],
    this.tags = const [],
  });

  final int lineIndex;
  final int charStart;
  final int charEnd;

  /// `task` | `event` | `note` | `untyped`.
  final String kind;

  final String text;
  final String? blockId;

  /// Only set when [kind] is `task`. See `task_state.dart` /
  /// `document_indexer.dart` for the encoding of unrecognized markers.
  final String? taskState;

  final String? dueDate;
  final String? dueTime;
  final String? recurrenceRaw;
  final List<String> contexts;
  final List<String> tags;
}

/// A fully-parsed vault file, ready to be written to the index. Produced by
/// `document_indexer.dart`'s `buildScannedDocument`, consumed by
/// `IndexService`.
///
/// Deliberately holds no reference to [MarkdownDocument]/`dart:io` types:
/// full scans build a `List<ScannedDocument>` inside a background isolate
/// (`Isolate.run`), so every field here must be safely sendable across the
/// isolate boundary.
@immutable
class ScannedDocument {
  const ScannedDocument({
    required this.relPath,
    required this.sha256,
    required this.mtimeMs,
    required this.sizeBytes,
    required this.docType,
    required this.title,
    required this.rawText,
    required this.entries,
    required this.links,
    this.frontmatterJson,
  });

  /// Canonical (`VaultPath.value`) relative path.
  final String relPath;

  /// Hex-encoded SHA-256 of the file's decoded text content (UTF-8
  /// re-encoded, BOM excluded) -- the join key `IndexService` uses to skip
  /// reparsing unchanged files on incremental updates.
  final String sha256;

  final int mtimeMs;
  final int sizeBytes;

  /// `citrinium.type` from frontmatter if present, else `'note'`.
  final String docType;

  /// Frontmatter `title:`, else the first heading line, else the filename
  /// (extension stripped).
  final String title;

  /// The complete file content, indexed verbatim into `document_fts` for
  /// full-text search.
  final String rawText;

  /// `null` if there's no frontmatter, else the frontmatter's YAML
  /// re-encoded as JSON.
  final String? frontmatterJson;

  final List<ScannedEntry> entries;
  final List<ScannedLink> links;
}
