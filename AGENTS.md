# AGENTS.md

## Project status

This repo is **pre-implementation**. `lib/main.dart` and `test/widget_test.dart` are still the unmodified `flutter create` counter-app template — they are not meaningful reference code and should be replaced wholesale when real implementation starts, not patched incrementally. `pubspec.yaml` only has stock dependencies (`cupertino_icons`, `flutter_lints`); none of the packages implied by the design (Riverpod, drift, freezed, etc.) have been added yet.

## Read these in order before writing code

1. `requirements.md` — prioritized product requirements (MUST/SHOULD/COULD), each with a stable ID (e.g. `D-02`, `PL-01`). Treat these IDs as the vocabulary for referencing requirements in code/commits/PRs.
2. `design.md` — locked architecture decisions and rationale, written against those requirement IDs. **Do not re-derive or silently contradict a decision already made here** (see below); if a decision needs revisiting, say so explicitly and update `design.md`.
3. `research.md` — background research (Obsidian, Todoist, ADHD/BuJo/GTD) that motivated the requirements. Useful context, not itself authoritative.

## Locked architecture decisions (from `design.md`)

- **Markdown files on disk are the source of truth** (Obsidian-compatible schema: YAML frontmatter, `[[wikilinks]]`, checkbox task states). Any SQLite/index/cache layer must be derived and fully rebuildable from the files — never treat it as authoritative.
- **State management: Riverpod only**, not Bloc/Provider. Multi-step flows (Clarify, Migration, Review rituals) use `Notifier`s holding `freezed` sealed-class state rather than a second framework.
- **Local index/search: SQLite via `drift`**, FTS5 for full-text search — a rebuildable cache, per above.
- **Plugin sandbox: embedded QuickJS**, not WASM (deliberate choice — see `design.md` §5 for why). One `JSContext` per plugin, no `std`/`os` modules linked, capability-scoped host bridge is the entire enforcement boundary.
- **Markdown editor: custom `TextField`/`TextEditingController` + decoration overlay** (Obsidian-style Live Preview), not `super_editor`/`appflowy_editor`. The edit buffer must always be the literal file content — no document-tree/serialization round-trip.
- **Platforms for v1: Android, iOS, Linux, macOS, Windows.** Web is explicitly excluded (no real filesystem access maps to the source-of-truth requirement above).
- **Sync (FR-01) is deferred entirely for v1** — build single-device/offline-first; don't add sync transport code speculatively.

## Commands

- `flutter pub get` — install dependencies (run after any `pubspec.yaml` change).
- `flutter analyze` — static analysis (uses `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`, no repo-specific rule overrides currently).
- `flutter test` — run all tests; `flutter test test/some_test.dart` for a single file.
- No CI, pre-commit hooks, or task runner are configured yet — `analyze`/`test` must be run manually before considering work done.

## Conventions observed in history

- Doc-only commits use a `docs: <Capitalized summary>` message style (e.g. `docs: Added high-level design`).
- Code commits use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `chore:`, `test:`, `refactor:`, `ci:`), optionally scoped (e.g. `feat(vault): ...`). Reference requirement IDs (e.g. `D-02`, `FR-04`) in the commit body where a commit implements one. See `docs/milestones/m0.md` for an example.
