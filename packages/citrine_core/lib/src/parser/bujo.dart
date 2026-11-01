/// BuJo (Bullet Journal) rapid-log signifiers for **event** and **note**
/// lines, per `design.md` §3.2:
///
/// ```
/// - ○ Dentist appointment 📅 2026-08-03 15:00
/// - – Idea: batch prescription refills quarterly
/// ```
///
/// Unlike task lines (`- [ ]`), events and notes are marked by a single
/// signifier character after the bullet, not a checkbox. `design.md` gives
/// examples, not a full grammar (that's pinned down for real in W5's
/// `docs/file-schema.md`); this is a deliberately small, literal set for
/// now rather than a guessed-at superset.
enum BujoKind {
  /// `- ○ ...` -- a dated/timed happening, not a task.
  event,

  /// `- – ...` -- a free-form observation/idea, not a task.
  note,
}

/// The signifier character for each [BujoKind], matching `design.md` §3.2
/// literally: `○` (U+25CB WHITE CIRCLE) for events, `–` (U+2013 EN DASH)
/// for notes.
const Map<String, BujoKind> bujoSignifiers = {
  '○': BujoKind.event,
  '–': BujoKind.note,
};

/// Reverse lookup used when serializing a new BuJo line (not part of W2's
/// required edit API, but kept alongside [bujoSignifiers] so the mapping
/// only lives in one place).
String bujoSignifierFor(BujoKind kind) {
  switch (kind) {
    case BujoKind.event:
      return '○';
    case BujoKind.note:
      return '–';
  }
}
