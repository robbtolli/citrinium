# AGENTS.md

## Project status

This repo is **pre-implementation**. `lib/main.dart` and `test/widget_test.dart` are still the unmodified `flutter create` counter-app template — they are not meaningful reference code and should be replaced wholesale when real implementation starts, not patched incrementally. `pubspec.yaml` only has stock dependencies (`cupertino_icons`, `flutter_lints`); none of the packages implied by the design (Riverpod, drift, freezed, etc.) have been added yet.

## Read these in order before writing code

1. `docs/requirements.md` — prioritized product requirements (MUST/SHOULD/COULD), each with a stable ID (e.g. `D-02`, `PL-01`). Treat these IDs as the vocabulary for referencing requirements in code/commits/PRs.
2. `docs/design.md` — locked architecture decisions and rationale, written against those requirement IDs. **Do not re-derive or silently contradict a decision already made here** (see below); if a decision needs revisiting, say so explicitly and update `docs/design.md`.
3. `docs/research/` — background research organized by topic (`comparable_apps.md`, `adhd_and_executive_function.md`, `productivity_systems.md`, `planning_habits_and_review.md`) that motivated the requirements. Useful context, not itself authoritative.

## Locked architecture decisions (from `docs/design.md`)

- **The user owns their data (`P-11`, `D-15`, `T-02`, `FR-04`, `FR-12`, `FR-13`, `FR-16`)**:
  - Every workspace has a vault folder on disk holding Markdown notes (including `daily/YYYY-MM-DD.md` generated from a template) alongside a well-documented SQLite database.
  - When a user types a task in a daily note or any Markdown note and navigates away from that line, Citrine saves the task to SQLite (`task_id`, `source_rel_path`, `source_byte_offset` hint) and appends a hidden `<!-- citrine:task=<id> -->` comment to that line.
  - Updating a task in a note updates SQLite; updating a task in a data view updates SQLite and updates the source `.md` file using `(source_rel_path, source_byte_offset)` first, then full-file scan, or clears `source_rel_path` (making the task DB-only) if the file or comment is missing. Tasks created from the Citrine UI live in SQLite with no backing `.md` file (`source_rel_path = NULL`).
  - External `.md` edits update tagged tasks automatically and prompt via a dismissible banner before importing untagged tasks in the background (with an unobtrusive loading bar and an app-close confirmation dialog).
  - Any data view can be exported to a static snapshot `.md` file (with a clear notice that snapshots do not auto-update), all data can be exported/imported, and both a CLI (`citrine`, `FR-12`) and MCP server (`citrine-mcp`, `FR-13`) provide read/write access.
- **UX architecture (`design.md` §6.2)**:
  - **Unified Single-View `Today` (`B-01`)** is the default home screen: a top Date Bar (for viewing past days and returning to Today) over the single unified `daily/YYYY-MM-DD.md` Live Preview editor with embedded ```` ```citrine ```` interactive data view blocks (no split screen).
  - **Pure Data Views for `Plan & Review` (`B-02`)**: Weekly, Monthly, Quarterly, Yearly, and Future planning/review screens are single-canvas database-backed data views with no backing `.md` files required.
  - **Warm Paper, Fountain-Pen Ink & Golden Citrine palette + Jargon-Free Copy (`A-01`, `A-02`)**: No internal requirement codes (`(B-12)`) or unexplained academic terms (`"Hard Landscape"`, `"Zombie Projects"`, `"Gollwitzer If-Then"`) in the UI.
  - **Hamburger Menu, About Screen, 7-Tap Debug Mode + Date Override & App Icon (`FR-14`, `FR-15`)**: Hamburger menu (`Drawer`) with About screen; tapping the app version 7 times enables Debug Mode with `Override Current Date` for testing; yellow-gold Citrine crystal + fountain pen app icon.
  - **In-place task editing everywhere (`D-19`, `B-05`)** and **user-configurable cadences (`B-12`)**.
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
- **Citation style in documentation**: Prefer clickable inline Markdown links over academic-style parenthetical citations like `(Lally et al., 2009)`. Link directly to sources, essays, interviews, and studies so references can be explored immediately.
