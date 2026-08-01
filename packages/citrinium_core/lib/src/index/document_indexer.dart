import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../parser/markdown_document.dart';
import '../parser/parsed_line.dart';
import 'scanned_document.dart';

/// A leading-bullet stripper for [LineKind.listItem] lines only.
///
/// `ParsedLine` doesn't carry a structured `contentSpan` for plain list
/// items the way it does for tasks (`TaskInfo.contentSpan`) and BuJo
/// events/notes (`BujoLineInfo.contentSpan`) -- generic bullets with no
/// signifier are a residual category `markdown_parser.dart` doesn't
/// otherwise need to break down further. Re-deriving the content text here
/// (rather than adding a new field to the parser's public API for a single
/// index-layer convenience column) keeps W2's public surface exactly as
/// designed; this regex intentionally mirrors `_listItemRe` in
/// `markdown_parser.dart`.
final RegExp _bulletPrefixRe = RegExp(r'^[ \t]*[-*+][ \t]+');

/// Builds a [ScannedDocument] from an already-parsed [doc].
///
/// This is the pure mapping step between W2's parser and W3's index schema:
/// no file I/O happens here (that's the caller's job -- see
/// `index_service.dart`'s isolate-side scan function), so this is directly
/// unit-testable against in-memory `MarkdownDocument`s.
ScannedDocument buildScannedDocument({
  required String relPath,
  required String sha256,
  required int mtimeMs,
  required int sizeBytes,
  required MarkdownDocument doc,
}) {
  final fm = doc.frontmatter;
  final data = fm?.data;

  final frontmatterJson = data == null ? null : jsonEncode(_yamlToJson(data));
  final docType = _docType(data);
  final title = _title(data, doc);

  final entries = <ScannedEntry>[];
  final links = <ScannedLink>[];

  for (final line in doc.lines) {
    final kind = _entryKindFor(line.kind);
    if (kind != null) {
      entries.add(_buildEntry(kind, line, doc.rawText));
    }
    for (final link in line.links) {
      links.add(
        ScannedLink(
          sourceLineIndex: kind != null ? line.index : null,
          targetRaw: link.target,
          isEmbed: link.isEmbed,
        ),
      );
    }
  }

  return ScannedDocument(
    relPath: relPath,
    sha256: sha256,
    mtimeMs: mtimeMs,
    sizeBytes: sizeBytes,
    docType: docType,
    title: title,
    rawText: doc.rawText,
    frontmatterJson: frontmatterJson,
    entries: entries,
    links: links,
  );
}

String? _entryKindFor(LineKind kind) {
  switch (kind) {
    case LineKind.task:
      return 'task';
    case LineKind.event:
      return 'event';
    case LineKind.note:
      return 'note';
    case LineKind.listItem:
      return 'untyped';
    case LineKind.blank:
    case LineKind.heading:
    case LineKind.text:
    case LineKind.codeFenceDelimiter:
    case LineKind.code:
      return null;
  }
}

ScannedEntry _buildEntry(String kind, ParsedLine line, String rawText) {
  final text = switch (line.kind) {
    LineKind.task => line.task!.contentSpan.of(rawText),
    LineKind.event || LineKind.note => line.bujo!.contentSpan.of(rawText),
    _ => line.span.of(rawText).replaceFirst(_bulletPrefixRe, ''),
  };

  String? taskState;
  if (line.kind == LineKind.task) {
    final task = line.task!;
    taskState = task.stateKind.name == 'unknown'
        ? 'unknown:${task.markerChar}'
        : task.stateKind.name;
  }

  String? firstValue(String metadataKind) {
    for (final m in line.metadata) {
      if (m.kind.name == metadataKind) return m.value;
    }
    return null;
  }

  final contexts = <String>{};
  final tags = <String>{};
  String? blockId;
  for (final m in line.metadata) {
    switch (m.kind.name) {
      case 'context':
        contexts.add(m.value);
      case 'tag':
        tags.add(m.value);
      case 'blockId':
        blockId ??= m.value;
    }
  }

  return ScannedEntry(
    lineIndex: line.index,
    charStart: line.span.start,
    charEnd: line.span.end,
    kind: kind,
    text: text,
    blockId: blockId,
    taskState: taskState,
    dueDate: firstValue('date'),
    dueTime: firstValue('time'),
    recurrenceRaw: firstValue('recurrence'),
    contexts: contexts.toList(growable: false),
    tags: tags.toList(growable: false),
  );
}

String _docType(YamlMap? data) {
  if (data != null) {
    final citrinium = data['citrinium'];
    if (citrinium is YamlMap) {
      final type = citrinium['type'];
      if (type != null) return type.toString();
    }
  }
  return 'note';
}

String _title(YamlMap? data, MarkdownDocument doc) {
  if (data != null) {
    final title = data['title'];
    if (title is String && title.trim().isNotEmpty) return title.trim();
  }
  for (final line in doc.lines) {
    if (line.kind == LineKind.heading) {
      final text = line.span.of(doc.rawText).replaceFirst(
        RegExp(r'^[ \t]{0,3}#{1,6}[ \t]*'),
        '',
      );
      if (text.trim().isNotEmpty) return text.trim();
    }
  }
  return '';
}

/// `package:yaml`'s `YamlMap`/`YamlList` aren't `jsonEncode`-able directly;
/// this recursively converts them (and any nested `YamlNode`s) into plain
/// `Map`/`List`/scalar values first.
Object? _yamlToJson(Object? node) {
  if (node is YamlMap) {
    return {
      for (final entry in node.entries) entry.key.toString(): _yamlToJson(entry.value),
    };
  }
  if (node is YamlList) {
    return node.map(_yamlToJson).toList(growable: false);
  }
  return node;
}
