# Implementation Milestones

This document sequences `requirements.md` into buildable milestones, informed by the architecture in `design.md`. It is written against the same requirement IDs as `requirements.md` — treat those IDs as the vocabulary for referencing work in code/commits/PRs.

**Scope rule:** all **MUST** requirements ship by the end of Milestone 12 (v1.0). SHOULD/COULD requirements are folded into a milestone only when they are a near-free addition once an adjacent MUST is built (called out per milestone as "cheap-adjacent"), or when a MUST functionally depends on a SHOULD-rated data-model piece being fully built (called out as "full-build dependency"). Everything else is pushed to the **Post-1.0 backlog** at the end of this document.

**One exception to the scope rule:** M6 (Full Live Preview Editor) is the only *design-driven* rather than requirement-driven milestone. `design.md` §7 calls the Live Preview editor out as "a genuine engineering investment ... a significant, dedicated line item — not incidental UI work," but no single requirement ID owns it; it is the delivery vehicle for C-03, D-14, N-01, N-02, P-07 and A-07 rather than a requirement of its own. It gets its own milestone because sizing it as incidental UI work inside M1 would be dishonest.

---

## Cross-cutting notes (apply to every milestone, not scoped to one)

- **P-11 / D-15 discrepancy**: `requirements.md` rates "files are the source of truth" and "local-first file-based storage" as SHOULD, but `design.md` treats it as a locked, non-negotiable architecture decision — every layer above the vault is a derived, rebuildable cache. This is treated as a **Milestone 0 hard requirement** regardless of its MoSCoW label; it cannot be retrofitted later.
- **Principles P-01, P-04–P-08** (capture-before-organize, forgiving tone, method-flexibility, calm defaults, search-over-taxonomy) are not standalone build tasks — they are acceptance-criteria checks applied at every milestone's review (e.g. "does this UI force a folder/tag at capture?").
- **T-03, T-04, FR-08** (sync conflict handling, sync privacy defaults, E2E encryption) are all explicitly conditioned on FR-01 (sync), which `design.md` §9 defers entirely for v1. These MUSTs (T-03/T-04) are **vacuously satisfied** in v1 — no sync exists, so there is nothing to conflict or leak. No milestone task is needed for them.
- **QY-03** (quarterly/yearly reviews never mandatory) is similarly vacuous in v1 since Q-*/Y-* planning surfaces are SHOULD-rated and deferred to the post-1.0 backlog — nothing exists yet that could be "mandatory."
- **AC-03** (no leaderboards/gamification) is satisfied by simply never building X-01-style features — a guardrail, not a task.
- **T-01** (performance) and **A-08** (cross-platform consistency) are continuously verified during development, with an explicit validation pass in the final milestone.

---

## M0 — Foundations: Vault, Index & App Shell

Vault file I/O + watcher + Markdown parser/serializer for checkbox task states and frontmatter (design.md §3); drift/SQLite index scaffold with an FTS5 table stubbed in; Riverpod app shell, routing, calm/minimal theming; platform targets configured for Android/iOS/Linux/macOS/Windows with web excluded (`FR-09` initial scaffold); first draft of the concrete frontmatter/inline-metadata schema doc (`FR-04` draft).

**Requirements:** P-11 / D-15 (architecture-locked), FR-04 (draft), FR-09 (scaffold).

**Detailed plan:** [`docs/milestones/m0.md`](docs/milestones/m0.md)

## M1 — Capture Loop: Inbox, Rapid Log & Daily Log

Unified entry type (task/event/note/untyped), inbox, rapid logging with minimal type-switching, natural-language date parsing, fully offline capture, Daily Log view, notes-on-log-line integration, supportive copy tone, reschedule/snooze/drop affordances everywhere, functional-first UI.

Editing here is an **undecorated** `TextField` over the literal file buffer — correct plumbing, no Live Preview rendering. The decoration layer of `design.md` §7 lands in M6.

**Requirements:** **D-01, C-02, C-03, C-04, C-05, B-01, N-01, N-07, A-02, A-03, A-07**.
**Cheap-adjacent:** B-05 (one-gesture bullet actions), D-14 (rich note body on log line), D-18 (lightweight text comments), B-08 (signifier marks; filtering deferred to M9).

## M2 — Organize Primitives: Projects, Someday/Maybe, Waiting For, Reference, Contexts

Full versions of the data-model pieces Clarify (M3) and Weekly Review (M9) depend on.

**Requirements:** **D-07, D-08**.
**Full-build dependencies:** D-03 (Projects), D-04 (zombie-project detection), D-05 (Someday/Maybe), D-06 (Waiting For).
**Cheap-adjacent:** G-03 (project outcome + next-action prompt), G-04 (context-filterable next-action lists — doubles as a minimal Engage view for v1).

## M3 — Clarify Flow & Calendar

The GTD decision-tree flow routing inbox items to the primitives built in M2, plus the hard-landscape calendar surface it routes into.

**Requirements:** **G-01**.
**Full-build dependency:** G-05 (Calendar).

## M4 — Monthly/Future Logs & Collections

**Requirements:** **B-02**.
**Cheap-adjacent:** B-03 (Future Log), B-04 (auto Index of collections/projects/notes), B-10 / D-10 (on-demand Collections).

## M5 — Migration Ritual & Daily Review

**Requirements:** **B-06, B-07, B-09, B-11, R-02**.

## M6 — Full Live Preview Editor

The dedicated `design.md` §7 investment: an Obsidian-style Live Preview over the literal file buffer. Semantic decoration engine in `citrinium_core` (pure Dart, incremental, line-scoped), a `TextEditingController` that maps decorations onto styled spans with cursor-aware reveal, a custom-painted backdrop for block-level geometry (code blocks, quote bars, indent guides), tap-to-toggle checkboxes, tap-to-follow wikilinks, Markdown editing affordances (list continuation, indent/outdent, emphasis shortcuts, smart paste), `[[`/`#`/`@` autocomplete fed by the M0 index, and a debounced write-through/external-change-reconciliation pipeline.

Sequenced here — after the surfaces that host it (M1–M5) exist and before the ones that lean hardest on it (M8 linking, M9 review) — so it is built against real callers rather than speculatively.

**Requirements:** none newly owned. **Completes** C-03, D-14, N-01, P-07, A-07 (claimed at plumbing level in M1) and delivers the authoring half of **N-02**.
**Cheap-adjacent:** B-05 (checkbox/bullet gestures in-editor), B-08 (signifier rendering), D-02 (state cycling from the checkbox glyph), T-05 partial (editor keyboard navigation, contrast, scalable type).

**Detailed plan:** [`docs/milestones/m6.md`](docs/milestones/m6.md)

## M7 — Recurrence & Habit Tracking

Domain-layer recurrence engine (daily/weekly/monthly/custom rules) and habit/streak engine on top of it, non-punitive by construction.

**Requirements:** **D-16, D-17**.

## M8 — Reminders & Native Notifications

Re-derives reminders from vault metadata each launch; per-platform native scheduling with graceful degradation (iOS pending-notification cap, Android exact-alarm gating).

**Requirements:** **E-08, E-10, E-11, FR-05**.
**Cheap-adjacent:** E-12 (snooze/reschedule from the notification itself).

## M9 — Notes Linking & Full-Text Search

**Requirements:** **N-02, N-03**.
**Cheap-adjacent:** N-04 (quick switcher — reuses M6's autocomplete overlay machinery), N-05 (optional folders/tags), D-12 (threading/backlinks), FR-06 (search performance target).

## M10 — Weekly Review

Now unblocked: Projects/Someday/Waiting-For (M2), Calendar (M3), the migration-ritual UX pattern (M5), and notifications (M8) all exist.

**Requirements:** **R-01**.
**Cheap-adjacent:** R-03 (stale-item surfacing), R-04 (resumable review), R-05 (optional review-start reminder).

## M11 — Plugin Architecture (QuickJS Sandbox)

Per-plugin `JSContext`, capability manifest, all-or-nothing install consent, central revoke surface, host bridge scoped to granted permissions only.

**Requirements:** **PL-01, PL-02, PL-03, PL-04**.
**Cheap-adjacent:** PL-05 (plugins operate on the same Markdown files), PL-08 (core vs. community plugin distinction).

## M12 — 1.0 Release Readiness

Manual full-vault export/backup/restore, data export for lock-in avoidance, `FR-04` schema doc frozen, full 5-platform QA pass (`A-08`), performance budget validation (`T-01`), onboarding pass (`A-06`), progressive-disclosure UI audit (`A-01`). Explicit documentation that T-03/T-04/FR-08/QY-03 are vacuously satisfied (no sync, no quarterly/yearly rituals in v1).

**Requirements:** **T-02, FR-07, FR-04 (freeze), FR-09 (verified), T-01, A-08**.

---

## Post-1.0 backlog (explicitly deferred, not oversights)

- **Engage/Focus depth**: E-01–E-07, E-09 (full context+time+energy filtering, Top-N focus mode, zen mode, timers, break-down action) — v1 ships only the minimal G-04 context-filterable list as a stand-in.
- **Quarterly/Annual planning & review**: Q-01, Q-02, Y-01, Y-02, QY-04.
- **Sync**: FR-01, plus everything conditioned on it (T-03, T-04, FR-08, cross-device reminder delivery).
- **Calendar/import ecosystem**: FR-02 (external calendar sync), FR-03 (importers), FR-10 (multi-vault).
- **Visualization**: PL-06 (Graph View), PL-07 (Canvas), PL-09 (per-permission revocation).
- **Accessibility & accountability**: T-05 (dyslexia font, reduced motion), AC-01/AC-02 (share links, check-in nudges).
- **Misc COULDs**: C-01/C-06/C-07 (global hotkey, voice capture, widgets), G-02/G-06/G-07, D-09 (time estimate/energy fields — tied to deferred Engage), D-13 (Areas of Focus), N-06 (file/image attachments), D-18's non-text attachments.
</content>
