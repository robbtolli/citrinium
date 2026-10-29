import 'package:meta/meta.dart';

import 'inline_metadata.dart';
import 'markdown_document.dart';
import 'span.dart';

/// A natural-language date/time match found inside rapid-log input (`C-04`).
///
/// Per `docs/milestones/m1.md` W2 / exit criterion #4: the user confirms a
/// detected date/time (no silent rewrite), and on confirmation [matchedSpan]
/// is stripped from the visible text and replaced with structured `📅`/`⏰`
/// inline metadata via [MarkdownDocument.upsertInlineField].
@immutable
class NlDateMatch {
  const NlDateMatch({
    required this.matchedSpan,
    required this.matchedText,
    this.dueDate,
    this.dueTime,
  });

  final Span matchedSpan;
  final String matchedText;

  /// Canonical `YYYY-MM-DD`, if a date phrase was matched.
  final String? dueDate;

  /// Canonical `HH:mm` (24-hour), if a time phrase was matched.
  final String? dueTime;

  /// Human-readable preview for confirmation chips.
  String get summaryLabel {
    final parts = <String>[];
    if (dueDate != null) parts.add('📅 $dueDate');
    if (dueTime != null) parts.add('⏰ $dueTime');
    return parts.join(' ');
  }

  /// Strips [matchedSpan] from [inputText] (the exact string passed to
  /// [NlDateParser.detect]) and appends canonical `📅`/`⏰` inline metadata
  /// tokens cleanly, prepending [defaultPrefix] if [inputText] doesn't already
  /// start with a list bullet.
  String applyToLineText(
    String inputText, {
    String defaultPrefix = '- [ ] ',
  }) {
    final safeStart = matchedSpan.start.clamp(0, inputText.length);
    final safeEnd = matchedSpan.end.clamp(safeStart, inputText.length);
    var stripped = inputText.replaceRange(safeStart, safeEnd, '');
    // Collapse double spaces left by removing the phrase
    stripped = stripped.replaceAll(RegExp(r' {2,}'), ' ').trim();

    final hasBullet = RegExp(r'^[-*+]\s+').hasMatch(stripped);
    final lineWithPrefix = hasBullet ? stripped : '$defaultPrefix$stripped';

    var doc = MarkdownDocument.parse(lineWithPrefix);
    if (dueDate != null) {
      doc = doc.upsertInlineField(0, InlineMetadataKind.date, dueDate!);
    }
    if (dueTime != null) {
      doc = doc.upsertInlineField(0, InlineMetadataKind.time, dueTime!);
    }
    return doc.rawText;
  }
}

/// Pure-Dart, 100% offline natural-language date/time detector (`C-04`, `C-05`).
///
/// Recognizes common relative and explicit phrases (`today`, `tomorrow`,
/// `next monday`..`next sunday`, `in N days`, `in N weeks`, `YYYY-MM-DD`,
/// `at 5pm`, `at 14:30`, `5pm`, `tomorrow 5pm`, `tomorrow at 9:30am`) while
/// avoiding false positives on ordinary prose (e.g. `"May 3rd project"` or
/// bare numbers).
class NlDateParser {
  const NlDateParser._();

  static const _weekdays = <String, int>{
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  static final RegExp _combinedPattern = RegExp(
    r'\b(?:'
    r'(today|tomorrow|tmrw|tonight)'
    r'|next\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|week|month)'
    r'|in\s+(\d{1,3})\s+(day|days|week|weeks)'
    r'|(\d{4}-\d{2}-\d{2})'
    r')'
    r'(?:\s+(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?)?\b'
    r'|\b(?:at\s+)(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b'
    r'|\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
    caseSensitive: false,
  );

  /// Detects the first natural-language date/time phrase in [text] relative to
  /// [referenceNow] (defaults to `DateTime.now()`).
  ///
  /// Ignores text that is already preceded by `📅` or `⏰` so existing structured
  /// inline metadata is never re-detected as a natural-language phrase.
  static NlDateMatch? detect(String text, {DateTime? referenceNow}) {
    final now = referenceNow ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final match in _combinedPattern.allMatches(text)) {
      // Skip if preceded immediately by 📅 or ⏰
      final prefixStart = (match.start - 4).clamp(0, match.start);
      final prefix = text.substring(prefixStart, match.start);
      if (prefix.contains('📅') || prefix.contains('⏰')) {
        continue;
      }

      String? dueDate;
      String? dueTime;

      final relWord = match.group(1)?.toLowerCase();
      final nextWord = match.group(2)?.toLowerCase();
      final inCountStr = match.group(3);
      final inUnit = match.group(4)?.toLowerCase();
      final isoDate = match.group(5);

      if (relWord != null) {
        if (relWord == 'today') {
          dueDate = formatIsoDate(today);
        } else if (relWord == 'tonight') {
          dueDate = formatIsoDate(today);
          dueTime = '20:00';
        } else if (relWord == 'tomorrow' || relWord == 'tmrw') {
          dueDate = formatIsoDate(
            DateTime(today.year, today.month, today.day + 1),
          );
        }
      } else if (nextWord != null) {
        if (nextWord == 'week') {
          dueDate = formatIsoDate(
            DateTime(today.year, today.month, today.day + 7),
          );
        } else if (nextWord == 'month') {
          final nextMonth = DateTime(today.year, today.month + 1, today.day);
          dueDate = formatIsoDate(nextMonth);
        } else {
          final targetWeekday = _weekdays[nextWord];
          if (targetWeekday != null) {
            var daysAhead = (targetWeekday - today.weekday) % 7;
            if (daysAhead <= 0) daysAhead += 7;
            dueDate = formatIsoDate(
              DateTime(today.year, today.month, today.day + daysAhead),
            );
          }
        }
      } else if (inCountStr != null && inUnit != null) {
        final count = int.tryParse(inCountStr);
        if (count != null) {
          final days = inUnit.startsWith('week') ? count * 7 : count;
          dueDate = formatIsoDate(
            DateTime(today.year, today.month, today.day + days),
          );
        }
      } else if (isoDate != null) {
        dueDate = isoDate;
      }

      // Check optional time attached to date match (groups 6, 7, 8)
      final attachedHour = match.group(6);
      final attachedMin = match.group(7);
      final attachedAmPm = match.group(8);
      if (attachedHour != null) {
        final parsedTime = _parseTime(attachedHour, attachedMin, attachedAmPm);
        if (parsedTime != null) {
          dueTime = parsedTime;
        }
      }

      // Or standalone time match (groups 9..11 or 12..14)
      final standHour1 = match.group(9) ?? match.group(12);
      final standMin1 = match.group(10) ?? match.group(13);
      final standAmPm1 = match.group(11) ?? match.group(14);
      if (standHour1 != null) {
        final parsedTime = _parseTime(standHour1, standMin1, standAmPm1);
        if (parsedTime != null) {
          dueTime = parsedTime;
        }
      }

      if (dueDate != null || dueTime != null) {
        return NlDateMatch(
          matchedSpan: Span(match.start, match.end),
          matchedText: match.group(0)!,
          dueDate: dueDate,
          dueTime: dueTime,
        );
      }
    }
    return null;
  }

  static String? _parseTime(String hourStr, String? minStr, String? amPmRaw) {
    final rawHour = int.tryParse(hourStr);
    if (rawHour == null) return null;
    final minute = minStr == null ? 0 : (int.tryParse(minStr) ?? -1);
    if (minute < 0 || minute > 59) return null;

    final amPm = amPmRaw?.toLowerCase();
    int hour24;
    if (amPm == 'pm') {
      if (rawHour < 1 || rawHour > 12) return null;
      hour24 = rawHour == 12 ? 12 : rawHour + 12;
    } else if (amPm == 'am') {
      if (rawHour < 1 || rawHour > 12) return null;
      hour24 = rawHour == 12 ? 0 : rawHour;
    } else {
      if (rawHour < 0 || rawHour > 23) return null;
      hour24 = rawHour;
    }

    final hh = hour24.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  static String formatIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
