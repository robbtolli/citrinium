import 'dart:math';

import 'task_state.dart';

/// Matches a hidden Citrine task ID comment: `<!-- citrine:task=<id> -->`.
final RegExp citrineTaskCommentRegExp = RegExp(
  r'<!--\s*citrine:task=([A-Za-z0-9_-]+)\s*-->',
);

final RegExp _trailingCitrineTaskCommentRegExp = RegExp(
  r'[ \t]*<!--\s*citrine:task=([A-Za-z0-9_-]+)\s*-->[ \t]*$',
);

final Random _random = Random.secure();

/// Generates a compact, URL- and HTML-comment-safe task identifier.
String generateCitrineTaskId() {
  final ts = DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(36);
  final randA = _random.nextInt(0x100000).toRadixString(36).padLeft(4, '0');
  final randB = _random.nextInt(0x100000).toRadixString(36).padLeft(4, '0');
  return 't_${ts}_$randA$randB';
}

/// Extracts the task ID from `<!-- citrine:task=<id> -->` in [line], or null.
String? extractCitrineTaskId(String line) {
  final match = citrineTaskCommentRegExp.firstMatch(line);
  return match?.group(1);
}

/// Strips any `<!-- citrine:task=<id> -->` comment (and surrounding padding)
/// from [line] or task text for clean display.
String stripCitrineTaskComment(String text) {
  return text
      .replaceAll(_trailingCitrineTaskCommentRegExp, '')
      .replaceAll(citrineTaskCommentRegExp, '')
      .trimRight();
}

/// Appends `<!-- citrine:task=<taskId> -->` to [line] (preserving trailing
/// `\r`/`\n`), or replaces an existing `<!-- citrine:task=... -->` comment.
String upsertCitrineTaskCommentInLine(String line, String taskId) {
  final newlineMatch = RegExp(r'(\r\n|\n|\r)$').firstMatch(line);
  final newline = newlineMatch?.group(0) ?? '';
  final body = newline.isEmpty
      ? line
      : line.substring(0, line.length - newline.length);

  if (citrineTaskCommentRegExp.hasMatch(body)) {
    final replaced = body.replaceFirst(
      citrineTaskCommentRegExp,
      '<!-- citrine:task=$taskId -->',
    );
    return '$replaced$newline';
  }

  final trimmed = body.trimRight();
  final separator = trimmed.isEmpty ? '' : ' ';
  return '$trimmed$separator<!-- citrine:task=$taskId -->$newline';
}

/// Splices an existing Markdown task [line] with updated [state], optional
/// [newText], and `<!-- citrine:task=<taskId> -->`, preserving indentation,
/// bullet character, and line ending.
String spliceTaskLine({
  required String line,
  required TaskStateKind state,
  String? newText,
  required String taskId,
}) {
  final newlineMatch = RegExp(r'(\r\n|\n|\r)$').firstMatch(line);
  final newline = newlineMatch?.group(0) ?? '';
  final body = newline.isEmpty
      ? line
      : line.substring(0, line.length - newline.length);

  final checkboxRe = RegExp(r'^([ \t]*[-*+][ \t]+\[)(.)(\][ \t]*)(.*)$');
  final match = checkboxRe.firstMatch(body);
  if (match == null) {
    final text = stripCitrineTaskComment(newText ?? body);
    final marker = _markerCharForState(state);
    return '- [$marker] $text <!-- citrine:task=$taskId -->$newline';
  }

  final prefix = match.group(1)!;
  final afterCheckbox = match.group(3)!;
  final currentContent = match.group(4)!;
  final marker = _markerCharForState(state);
  final cleanText = stripCitrineTaskComment(newText ?? currentContent);
  final updatedBody =
      '$prefix$marker$afterCheckbox$cleanText <!-- citrine:task=$taskId -->';
  return '$updatedBody$newline';
}

String _markerCharForState(TaskStateKind state) {
  return switch (state) {
    TaskStateKind.open => ' ',
    TaskStateKind.inProgress => '/',
    TaskStateKind.completed => 'x',
    TaskStateKind.cancelled => '-',
    TaskStateKind.waitingFor => 'w',
    TaskStateKind.unknown => ' ',
  };
}
