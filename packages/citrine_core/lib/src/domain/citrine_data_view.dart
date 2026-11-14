import '../../index.dart';
import '../parser/nl_date_parser.dart';

/// Supported preset views for embedded ```` ```citrine ```` data view blocks (`B-01`, `B-02`).
enum CitrineDataViewPreset {
  topFocus('top-focus', 'Today\'s Top Focus'),
  dueToday('due-today', 'Tasks Due Today'),
  createdToday('created-today', 'Tasks Created Today'),
  dueThisWeek('due-this-week', 'Due This Week'),
  overdue('overdue', 'Earlier Open Tasks'),
  schedule('schedule', 'Schedule & Events'),
  events('events', 'Schedule & Events'),
  projects('projects', 'Active Projects'),
  habits('habits', 'Daily Habits'),
  tasks('tasks', 'Tasks');

  const CitrineDataViewPreset(this.id, this.defaultTitle);
  final String id;
  final String defaultTitle;

  static CitrineDataViewPreset? tryParse(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toLowerCase().replaceAll('_', '-');
    for (final p in values) {
      if (p.id == normalized) return p;
    }
    return null;
  }
}

/// Parsed configuration inside a ```` ```citrine ... ``` ```` fenced block (`B-01`).
class CitrineDataViewQuery {
  const CitrineDataViewQuery({
    this.view = CitrineDataViewPreset.tasks,
    this.filter,
    this.title,
    this.tag,
    this.context,
    this.status = 'open',
    this.includeOverdue = false,
    this.limit,
  });

  final CitrineDataViewPreset view;
  final String? filter;
  final String? title;
  final String? tag;
  final String? context;
  final String status;
  final bool includeOverdue;
  final int? limit;

  /// Parses simple YAML-style `key: value` lines inside a `citrine` code fence.
  factory CitrineDataViewQuery.parse(String rawBody) {
    String? viewRaw;
    String? filterRaw;
    String? titleRaw;
    String? tagRaw;
    String? contextRaw;
    String statusRaw = 'open';
    var includeOverdue = false;
    int? limit;

    for (final line in rawBody.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final colonIdx = trimmed.indexOf(':');
      if (colonIdx <= 0) continue;
      final key = trimmed.substring(0, colonIdx).trim().toLowerCase();
      var value = trimmed.substring(colonIdx + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        if (value.length >= 2) {
          value = value.substring(1, value.length - 1);
        }
      }
      switch (key) {
        case 'view':
          viewRaw = value;
        case 'filter':
          filterRaw = value;
        case 'title':
          titleRaw = value;
        case 'tag':
          tagRaw = value.startsWith('#') ? value.substring(1) : value;
        case 'context':
          contextRaw = value.startsWith('@') ? value.substring(1) : value;
        case 'status':
          statusRaw = value.toLowerCase();
        case 'include_overdue':
        case 'include-overdue':
          includeOverdue = value.toLowerCase() == 'true';
        case 'limit':
          limit = int.tryParse(value);
      }
    }

    final parsedView =
        CitrineDataViewPreset.tryParse(viewRaw) ??
        CitrineDataViewPreset.tryParse(filterRaw) ??
        CitrineDataViewPreset.tasks;

    return CitrineDataViewQuery(
      view: parsedView,
      filter: filterRaw?.trim().toLowerCase().replaceAll('_', '-'),
      title: (titleRaw != null && titleRaw.isNotEmpty) ? titleRaw : null,
      tag: (tagRaw != null && tagRaw.isNotEmpty) ? tagRaw : null,
      context: (contextRaw != null && contextRaw.isNotEmpty) ? contextRaw : null,
      status: statusRaw,
      includeOverdue: includeOverdue,
      limit: limit,
    );
  }

  String get resolvedTitle {
    if (title != null && title!.isNotEmpty) return title!;
    final filterPreset = CitrineDataViewPreset.tryParse(filter);
    if (view == CitrineDataViewPreset.tasks && filterPreset != null) {
      return filterPreset.defaultTitle;
    }
    return view.defaultTitle;
  }

  /// Formats this query as a fenced ```` ```citrine ... ``` ```` Markdown block.
  String toMarkdownFence() {
    final buf = StringBuffer('```citrine\n');
    buf.writeln('view: ${view.id}');
    if (filter != null && filter!.isNotEmpty) {
      buf.writeln('filter: $filter');
    }
    if (title != null && title!.isNotEmpty) {
      buf.writeln('title: $title');
    }
    if (tag != null && tag!.isNotEmpty) {
      buf.writeln('tag: $tag');
    }
    if (context != null && context!.isNotEmpty) {
      buf.writeln('context: $context');
    }
    if (status != 'open') {
      buf.writeln('status: $status');
    }
    if (includeOverdue) {
      buf.writeln('include_overdue: true');
    }
    if (limit != null) {
      buf.writeln('limit: $limit');
    }
    buf.write('```');
    return buf.toString();
  }
}

/// Location and parsed query of a ```` ```citrine ```` block inside Markdown.
class CitrineDataViewBlock {
  const CitrineDataViewBlock({
    required this.startOffset,
    required this.endOffset,
    required this.rawBody,
    required this.query,
  });

  final int startOffset;
  final int endOffset;
  final String rawBody;
  final CitrineDataViewQuery query;
}

/// Finds all ```` ```citrine ... ``` ```` fenced code blocks in [rawText].
List<CitrineDataViewBlock> findCitrineDataViewBlocks(String rawText) {
  final blocks = <CitrineDataViewBlock>[];
  final openPattern = RegExp(r'^```citrine\s*$', multiLine: true);
  final closePattern = RegExp(r'^```\s*$', multiLine: true);

  var searchStart = 0;
  while (searchStart < rawText.length) {
    final openMatch = openPattern.firstMatch(rawText.substring(searchStart));
    if (openMatch == null) break;

    final absOpenStart = searchStart + openMatch.start;
    final bodyStart = searchStart + openMatch.end + 1; // skip newline
    if (bodyStart >= rawText.length) break;

    final closeMatch = closePattern.firstMatch(rawText.substring(bodyStart));
    if (closeMatch == null) break;

    final absBodyEnd = bodyStart + closeMatch.start;
    final absCloseEnd = bodyStart + closeMatch.end;
    final body = rawText.substring(bodyStart, absBodyEnd);

    blocks.add(
      CitrineDataViewBlock(
        startOffset: absOpenStart,
        endOffset: absCloseEnd,
        rawBody: body,
        query: CitrineDataViewQuery.parse(body),
      ),
    );
    searchStart = absCloseEnd;
  }
  return blocks;
}

/// Evaluates [query] against [allEntries] for [referenceDate].
List<IndexedEntryWithDocument> evaluateCitrineDataView({
  required CitrineDataViewQuery query,
  required List<IndexedEntryWithDocument> allEntries,
  required DateTime referenceDate,
  Set<String> pinnedFocusKeys = const {},
}) {
  final todayIso = NlDateParser.formatIsoDate(referenceDate);
  final weekEndIso = NlDateParser.formatIsoDate(
    referenceDate.add(const Duration(days: 7)),
  );
  final monthPrefix = todayIso.substring(0, 7); // YYYY-MM
  final dailyRelPath = 'daily/$todayIso.md';

  final filterStr = query.filter;
  final effectiveFilter = CitrineDataViewPreset.tryParse(filterStr) ?? query.view;

  final results = allEntries.where((item) {
    // Optional tag / context filters
    if (query.tag != null &&
        !item.tags.any((t) => t.toLowerCase() == query.tag!.toLowerCase())) {
      return false;
    }
    if (query.context != null &&
        !item.contexts.any(
          (c) => c.toLowerCase() == query.context!.toLowerCase(),
        )) {
      return false;
    }

    // Explicit completed filters used on Today & Plan/Review
    if (filterStr == 'completed-today') {
      return item.isCompletedTask &&
          (item.entry.dueDate == todayIso ||
              item.document.relPath == dailyRelPath);
    }
    if (filterStr == 'completed-this-week') {
      if (!item.isCompletedTask) return false;
      final due = item.entry.dueDate;
      if (due != null) {
        return due.compareTo(todayIso) <= 0;
      }
      return item.document.relPath == dailyRelPath;
    }
    if (filterStr == 'due-this-month') {
      if (!item.isOpenTask) return false;
      final due = item.entry.dueDate;
      if (due == null) return false;
      if (due.startsWith(monthPrefix)) return true;
      return query.includeOverdue && due.compareTo(todayIso) < 0;
    }

    // Status filter for non-completed-specific views
    if (query.status == 'completed' && !item.isCompletedTask) {
      return false;
    }
    if (query.status == 'open' && item.isTask && !item.isOpenTask) {
      return false;
    }

    switch (effectiveFilter) {
      case CitrineDataViewPreset.topFocus:
        return item.isOpenTask && pinnedFocusKeys.contains(item.uniqueKey);
      case CitrineDataViewPreset.dueToday:
        if (!item.isOpenTask) return false;
        final due = item.entry.dueDate;
        if (due == null) return false;
        if (due == todayIso) return true;
        return query.includeOverdue && due.compareTo(todayIso) < 0;
      case CitrineDataViewPreset.createdToday:
        return item.isTask && item.document.relPath == dailyRelPath;
      case CitrineDataViewPreset.dueThisWeek:
        if (!item.isOpenTask) return false;
        final due = item.entry.dueDate;
        if (due == null) return false;
        if (due.compareTo(todayIso) >= 0 && due.compareTo(weekEndIso) <= 0) {
          return true;
        }
        return query.includeOverdue && due.compareTo(todayIso) < 0;
      case CitrineDataViewPreset.overdue:
        if (!item.isOpenTask) return false;
        final due = item.entry.dueDate;
        return due != null && due.compareTo(todayIso) < 0;
      case CitrineDataViewPreset.schedule:
      case CitrineDataViewPreset.events:
        if (!item.isEvent) return false;
        final due = item.entry.dueDate;
        if (filterStr == 'this-week') {
          return due != null &&
              due.compareTo(todayIso) >= 0 &&
              due.compareTo(weekEndIso) <= 0;
        }
        if (filterStr == 'this-month') {
          return due != null && due.startsWith(monthPrefix);
        }
        if (filterStr == 'upcoming') {
          return due != null && due.compareTo(todayIso) >= 0;
        }
        return due == null || due == todayIso;
      case CitrineDataViewPreset.projects:
        return item.document.docType == 'project' &&
            item.isOpenTask;
      case CitrineDataViewPreset.habits:
        return item.isHabit;
      case CitrineDataViewPreset.tasks:
        return item.isOpenTask;
    }
  }).toList();

  if (query.limit != null && query.limit! > 0 && results.length > query.limit!) {
    return results.sublist(0, query.limit!);
  }
  return results;
}
