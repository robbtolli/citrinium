/// Task states (D-02) as represented by the single character between the
/// `[` and `]` of a checkbox marker, per `design.md` §3.1.
enum TaskStateKind {
  /// `- [ ]`
  open,

  /// `- [/]`
  inProgress,

  /// `- [x]` (or `[X]`)
  completed,

  /// `- [-]` -- cancelled / dropped task.
  cancelled,

  /// `- [w]` (or `[W]`) -- Citrinium extension (waiting-for).
  waitingFor,

  /// Any other single character. Preserved verbatim.
  unknown;

  /// String value representation used in SQLite index and serialization.
  String get stateValue {
    switch (this) {
      case TaskStateKind.open:
        return 'open';
      case TaskStateKind.inProgress:
        return 'in-progress';
      case TaskStateKind.completed:
        return 'completed';
      case TaskStateKind.cancelled:
        return 'cancelled';
      case TaskStateKind.waitingFor:
        return 'waitingFor';
      case TaskStateKind.unknown:
        return 'unknown';
    }
  }
}

/// Parses a string representation back to [TaskStateKind].
TaskStateKind? taskStateKindFromValue(String? value) {
  if (value == null) return null;
  switch (value) {
    case 'open':
      return TaskStateKind.open;
    case 'in-progress':
    case 'inProgress':
      return TaskStateKind.inProgress;
    case 'completed':
      return TaskStateKind.completed;
    case 'cancelled':
    case 'dropped':
      return TaskStateKind.cancelled;
    case 'waitingFor':
      return TaskStateKind.waitingFor;
    default:
      return TaskStateKind.unknown;
  }
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
    case '-':
      return TaskStateKind.cancelled;
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
    case TaskStateKind.cancelled:
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
