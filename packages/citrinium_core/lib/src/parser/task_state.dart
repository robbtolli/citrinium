/// Task states (D-02) as represented by the single character between the
/// `[` and `]` of a checkbox marker, per `design.md` §3.1.
///
/// Order here matches the table in `design.md` §3.1.
enum TaskStateKind {
  /// `- [ ]`
  open,

  /// `- [/]`
  inProgress,

  /// `- [x]` (or `[X]`)
  completed,

  /// `- [>]`
  migrated,

  /// `- [<]`
  scheduled,

  /// `- [-]`
  dropped,

  /// `- [w]` (or `[W]`) -- Citrinium extension (waiting-for).
  waitingFor,

  /// Any other single character. Per `docs/milestones/m0.md` W2: "Unknown
  /// marker chars are preserved verbatim ... rather than normalized away --
  /// required for portability" (e.g. a vault edited by Obsidian's Tasks
  /// plugin with custom statuses we don't otherwise know about).
  unknown,
}

/// Maps a checkbox marker character (the literal char between `[` and `]`)
/// to its [TaskStateKind]. Never throws -- any unrecognized character maps
/// to [TaskStateKind.unknown], whose original character is preserved by the
/// caller (see `TaskInfo.markerChar` in `parsed_line.dart`) rather than
/// normalized away.
TaskStateKind taskStateKindForMarker(String markerChar) {
  switch (markerChar) {
    case ' ':
      return TaskStateKind.open;
    case '/':
      return TaskStateKind.inProgress;
    case 'x':
    case 'X':
      return TaskStateKind.completed;
    case '>':
      return TaskStateKind.migrated;
    case '<':
      return TaskStateKind.scheduled;
    case '-':
      return TaskStateKind.dropped;
    case 'w':
    case 'W':
      return TaskStateKind.waitingFor;
    default:
      return TaskStateKind.unknown;
  }
}

/// The canonical marker character to write for a given [TaskStateKind] when
/// an edit sets a *known* state (see `MarkdownDocument.setTaskState`).
///
/// [TaskStateKind.unknown] has no canonical character -- callers that want
/// to set an unknown/custom marker must pass the literal character
/// directly rather than going through this map.
String canonicalMarkerFor(TaskStateKind kind) {
  switch (kind) {
    case TaskStateKind.open:
      return ' ';
    case TaskStateKind.inProgress:
      return '/';
    case TaskStateKind.completed:
      return 'x';
    case TaskStateKind.migrated:
      return '>';
    case TaskStateKind.scheduled:
      return '<';
    case TaskStateKind.dropped:
      return '-';
    case TaskStateKind.waitingFor:
      return 'w';
    case TaskStateKind.unknown:
      throw ArgumentError(
        'TaskStateKind.unknown has no canonical marker character; '
        'pass the literal character to setTaskState instead.',
      );
  }
}
