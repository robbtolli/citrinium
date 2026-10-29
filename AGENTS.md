# AGENTS.md

## Project status

This repo is **pre-implementation**. `lib/main.dart` and `test/widget_test.dart` are still the unmodified `flutter create` counter-app template — they are not meaningful reference code and should be replaced wholesale when real implementation starts, not patched incrementally. `pubspec.yaml` only has stock dependencies (`cupertino_icons`, `flutter_lints`); none of the packages implied by the design (Riverpod, drift, freezed, etc.) have been added yet.

## Read these in order before writing code

1. `docs/requirements.md` — prioritized product requirements (MUST/SHOULD/COULD), each with a stable ID (e.g. `D-02`, `PL-01`). Treat these IDs as the vocabulary for referencing requirements in code/commits/PRs.
2. `docs/design.md` — locked architecture decisions and rationale, written against those requirement IDs. **Do not re-derive or silently contradict a decision already made here** (see below); if a decision needs revisiting, say so explicitly and update `docs/design.md`.
3. `docs/research.md` — background research (Obsidian, Todoist, ADHD/BuJo/GTD) that motivated the requirements. Useful context, not itself authoritative.

## Locked architecture decisions (from `docs/design.md`)

- **User data ownership, clean Markdown & structured operational state (`P-11`, `D-15`)**: Notes, projects, collections, cadence logs (`daily/`, `weekly/`, `monthly/`, `quarterly/`, `yearly/`, `future.md`, `inbox.md`), and inline rapid-logged tasks/events/notes live in plain-text Markdown files on disk (Obsidian-compatible schema: YAML frontmatter, `[[wikilinks]]`, checkbox task states). The search/task index over these files is derived and rebuildable from disk. Operational/history data that would clutter Markdown notes with "emoji soup" or duplicated recurring rows (habit completion history, Today's Top-3 pins, snooze state, review ritual checkpoints, cadence toggles, recent-view history) lives in local SQLite / `.citrinium/` and must be 100% exportable to human-readable Markdown/JSON (`T-02`).
- **UX architecture ("Hybrid Dual-Track", `design.md` §6.2)**:
  - **Today's Combined View** is the default home screen (collapsible Top-3 Focus Shelf + `daily/YYYY-MM-DD.md` Live Preview editor), with a **2-hour session-continuity restore window** and a **`🕒 Recent` Views/Documents switcher** (`A-08`, `N-04`).
  - **In-place task editing everywhere (`D-19`, `B-05`)**: Clicking/tapping a task in any list, filter, Focus Shelf, or review ritual edits it directly in-place (splicing changes into the source `.md` file in the background) without jumping to the source note; an explicit source badge (`[📄 note ↗]`) lets users peek at or open the note when they want surrounding context.
  - **User-configurable cadences (`B-12`)**: Daily, Weekly (`weekly/YYYY-Www.md`), Monthly, Quarterly, Yearly, and Future Log planning surfaces and review rituals can be individually toggled on/off by the user.
- **State management: Riverpod only**, not Bloc/Provider. Multi-step flows (Clarify, Migration, Review rituals) use `Notifier`s holding `freezed` sealed-class state rather than a second framework.
- **Local index/search: SQLite via `drift`**, FTS5 for full-text search — a rebuildable cache for vault files, plus operational tables for habits/pins/rituals per above.
- **Plugin sandbox: embedded QuickJS**, not WASM (deliberate choice — see `docs/design.md` §5 for why). One `JSContext` per plugin, no `std`/`os` modules linked, capability-scoped host bridge is the entire enforcement boundary.
- **Markdown editor: custom `EditableText`/`TextEditingController` + decoration overlay** (Obsidian-style Live Preview), not `super_editor`/`appflowy_editor`. The edit buffer must always be the literal file content — no document-tree/serialization round-trip.
- **Platforms for v1: Android, iOS, Linux, macOS, Windows.** Web is explicitly excluded.
- **Sync (FR-01) is deferred entirely for v1** — build single-device/offline-first; don't add sync transport code speculatively.

## Commands

- `flutter pub get` — install dependencies (run after any `pubspec.yaml` change).
- `flutter analyze` — static analysis (uses `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`, no repo-specific rule overrides currently).
- `flutter test` — run all tests; `flutter test test/some_test.dart` for a single file.
- No CI, pre-commit hooks, or task runner are configured yet — `analyze`/`test` must be run manually before considering work done.

## Conventions observed in history

- Doc-only commits use a `docs: <Capitalized summary>` message style (e.g. `docs: Added high-level design`).
- Code commits use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `chore:`, `test:`, `refactor:`, `ci:`), optionally scoped (e.g. `feat(vault): ...`). Reference requirement IDs (e.g. `D-02`, `FR-04`) in the commit body where a commit implements one. See `docs/milestones/m0.md` for an example.
