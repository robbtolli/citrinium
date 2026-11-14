# High-Level Design

This document describes the technical architecture for Citrine, derived from `requirements.md`. It is written at the same level of detail as the requirements — component boundaries and rationale, not a full implementation spec. Concrete schemas (FR-04), a plugin host-bridge API reference, and a notification scheduling spec are follow-up documents once this design is accepted.

Non-goals X-01–X-06 from `requirements.md` are assumed and not re-litigated here.

---

## 1. Architecture overview

Citrine is a layered, offline-first Flutter application. The guiding principle (P-11, D-15) centers on **"the user owns their data"**:
1. **True user data ownership & open access (`P-11`, `T-02`, `FR-04`, `FR-12`, `FR-13`):** Every workspace has a vault folder on disk holding standard Markdown notes alongside a well-documented SQLite database. All data can be exported and imported (Markdown/JSON/SQLite), any data view can be exported to a static Markdown snapshot, and both a command-line tool (`citrine` CLI) and an MCP server (`citrine-mcp`) allow users and external tools to query, extract, and update data directly.
2. **Unified Daily Note with embedded data views (`B-01`):** The `Today` view is a single unified Markdown note (`daily/YYYY-MM-DD.md`, created from an editable template)—not a split screen—featuring a top date bar to navigate to past days and embedded ```` ```citrine ```` source code blocks that render live interactive task/data views directly inline.
3. **Pure database data views for Planning, Review & Actions (`B-02`):** Weekly, Monthly, Quarterly, Yearly, and Future planning/review screens (`Plan & Review`) are pure database-backed data views with no backing `.md` files required.

To combine freeform Markdown note-taking with rock-solid relational task management, Citrine uses a **bidirectional SQLite + Markdown task sync boundary (`D-15`, `FR-16`)**:
- **SQLite database** is the primary structured store for all tasks, events, habits, focus pins, review rituals, and operational history. Tasks created from the Citrine UI (Quick Capture to Inbox/Actions, `+ Add Task` in a data view, or during Planning/Review) are stored directly in SQLite with `source_rel_path = NULL` (no Markdown file backing them).
- **Markdown notes on disk** (`daily/YYYY-MM-DD.md` and standalone notes) support inline task authoring. When a user types a task line (`- [ ] ...`) in a note and navigates away from that line, Citrine saves the task to SQLite (`task_id`, `source_rel_path`, `source_byte_offset` hint) and appends a hidden Markdown comment (`<!-- citrine:task=<id> -->`) to that line.
- **Bidirectional synchronization:**
  - Updating a task in a note updates its SQLite record.
  - Updating a task in any data view updates SQLite and updates the source `.md` file using `(source_rel_path, source_byte_offset)` first, falling back to a full-file scan for `<!-- citrine:task=<id> -->`. If the source file is missing or the comment was removed, `source_rel_path` and `source_byte_offset` are cleared so the task gracefully becomes database-only.
  - External edits to `.md` files automatically sync tasks that have `<!-- citrine:task=<id> -->` comments; if new untagged tasks are detected, Citrine shows a dismissible banner (`FR-16`) asking whether to import them in the background (with an unobtrusive loading bar and an app-close confirmation guard).

```
┌─────────────────────────────────────────────────────────────┐
│ Presentation (Warm Paper & Ink UI · Single-Canvas Views)    │
│  ☀️ Today (Date Bar + Template Daily Note + ```citrine)     │
│  ✅ Actions & Inbox · 🧭 Plan & Review (Pure Data Views)    │
│  📓 Notes & Index · ☰ Hamburger Menu (About + 7-Tap Debug)  │
├─────────────────────────────────────────────────────────────┤
│ State (Riverpod + AppClock + BackgroundWorkManager)         │
│  Providers over SQLite & Vault · injectable clock (FR-14)   │
│  Background job progress bar & exit guard (FR-16)           │
├─────────────────────────────────────────────────────────────┤
│ Domain                                                      │
│  Task state machine (D-02) · recurrence & habits (D-16/17)  │
│  DataView query engine (B-01/02) · snapshot exporter (T-02) │
│  Bidirectional task comment splice engine (D-15)            │
├──────────────────────────┬──────────────────────────────────┤
│ SQLite Database (drift)  │ External Interfaces & Plugins    │
│  1. Authoritative tasks, │  • citrine CLI (FR-12)           │
│     habits, rituals, pins│  • citrine-mcp Server (FR-13)    │
│  2. Note index + FTS5    │  • QuickJS Plugin Host (PL-01)   │
├──────────────────────────┴──────────────────────────────────┤
│ Vault Folder on Disk                                        │
│  daily/YYYY-MM-DD.md + Markdown notes + .citrine/ templates │
│  File watcher · <!-- citrine:task=<id> --> parser/splicer   │
├─────────────────────────────────────────────────────────────┤
│ Platform services                                           │
│  Native notification scheduling (E-08–E-12, FR-05)          │
│  Filesystem access per OS (Android/iOS/Linux/macOS/Windows) │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Platform matrix (FR-09)

| Platform | v1 | Notes |
| --- | --- | --- |
| Android | Yes | Real filesystem, native notification channel |
| iOS | Yes | Real filesystem (app container/Files integration), local notifications; plugin runtime must stay interpreter-only (§5) |
| Linux | Yes | Primary dev/reference platform |
| macOS | Yes | Native notification center |
| Windows | Yes | Native notification center |
| Web | **Excluded** | No honest mapping to P-11 — no real filesystem (only OPFS/File System Access API, Chromium-only), so the vault-on-disk model can't be truthfully implemented. Revisit only as a read-only/companion mode, not core. |

Cross-platform consistency (A-08) is a design constraint on every layer above: the domain and index layers must be platform-agnostic Dart, with platform-specific code isolated to the vault-access and notification-scheduling boundaries.

---

## 3. Vault & file schema (P-11, D-15, FR-04)

The vault is a folder of plain-text Markdown files. Schema is an **Obsidian-compatible superset**: standard YAML frontmatter, `[[wikilinks]]`, and checkbox-based task states, so the vault stays genuinely portable (readable/editable by Obsidian or any text editor) and FR-03 (import) is close to free.

### 3.1 Task states (D-02) as checkbox markers

| Marker | State |
| --- | --- |
| `- [ ]` | open |
| `- [/]` | in-progress |
| `- [x]` | completed |
| `- [>]` | migrated |
| `- [<]` | scheduled |
| `- [-]` | dropped/canceled |
| `- [w]` | waiting-for (Citrine extension; still a valid checkbox line for any generic Markdown/Obsidian reader, and configurable as a custom status in the Obsidian Tasks plugin) |

### 3.2 Inline metadata

Rapid-log lines carry inline metadata rather than requiring a form, per C-03/C-04:

```
- [ ] Call pharmacy about refill 📅 2026-08-01 ⏰17:00 @phone #waiting-for/dr-lee ^t7f3a2b
- [ ] Stretch 🔁 every weekday ⏰08:00 #habit ^h9c21
- ○ Dentist appointment 📅 2026-08-03 15:00
- – Idea: batch prescription refills quarterly
```

`^t7f3a2b`-style block IDs give any log line a stable anchor for backlinks/threading (N-02, D-12) without requiring every task to live in its own file.

### 3.3 Frontmatter (notes, projects, collections)

Standalone files (notes, projects, collections, Areas of Focus) use YAML frontmatter. Citrine-specific fields are namespaced under `citrine:` so the file stays meaningful to any other Markdown tool that ignores unknown keys:

```yaml
---
citrine:
  type: project
  id: 7f3a2b1c
  outcome: "Ship v1.0 to TestFlight"
  status: active
  area: Health
tags: [project, health]
---
```

### 3.4 Daily Notes, Embedded Data Views & Pure Data-View Horizons (`B-01`, `B-02`, `D-11`)

- **Daily Note (`daily/YYYY-MM-DD.md`, `B-01`):** Created lazily on first use from an editable template (`.citrine/templates/daily.md`, `B-11`). Includes embedded ```` ```citrine ```` source code blocks that render live interactive data views inline (e.g., `view: top-focus`, `view: due-today`, `view: created-today`, `view: due-this-week`, or custom YAML filter rules) alongside freeform Markdown notes and tasks.
- **Planning & Review Surfaces (`Plan & Review`, `B-02`):** Weekly, Monthly, Quarterly, Yearly, and Future planning/review surfaces are **pure database-backed data views** (no backing `.md` files required), aggregating tasks, projects, habits, and reflections from SQLite and Markdown notes.
- **Static Snapshot Exports (`T-02`):** Any data view (whether a `Plan & Review` horizon view, an `Actions` filter, or an embedded ```` ```citrine ```` block) can be exported to a `.md` file at any time. The export dialog/screen states clearly that exported files are **static snapshots of the current data and will not be updated when the data changes**.

### 3.5 Bidirectional Task Synchronization & Hidden Task ID Comments (`P-11`, `D-15`, `FR-16`)

1. **Line-Exit Task Enrollment in Notes:**
   - When the user types a task line (`- [ ] ...`) in a daily note or any Markdown note and navigates away from that line, Citrine saves the task to the SQLite `tasks` table and appends a hidden Markdown comment (`<!-- citrine:task=<task_id> -->`) to the end of that line.
   - The Live Preview editor hides `<!-- citrine:task=... -->` comments from visual display so the note stays clean.
   - The SQLite row stores `task_id`, `source_rel_path` (path relative to vault root), and `source_byte_offset` (byte offset of the line start as a fast lookup hint).
2. **Note → Database Sync (Internal & External Edits):**
   - If the task line is edited inside Citrine's Markdown editor, Citrine updates the matching `task_id` record in SQLite.
   - If a Markdown file is modified in an external tool:
     - Tasks that already have `<!-- citrine:task=<task_id> -->` comments are automatically updated in SQLite.
     - If Citrine detects new or modified `.md` files containing untagged tasks (lines without a task ID comment), it displays a dismissible banner (`FR-16`): *"Citrine has detected new markdown files in the vault that contain tasks. Would you like to import them?"* (`Yes` / `No` / close). Clicking `Yes` imports those tasks into SQLite and writes `<!-- citrine:task=<task_id> -->` comments into the files in the background while showing an unobtrusive loading bar (and a confirmation dialog if the user tries to close Citrine while background work is active). Clicking `No` or closing the banner leaves the files untouched.
3. **Data View / UI → Database & Note Sync (with Fallback to DB-Only):**
   - If a user updates a task inside any Citrine data view (Planning/Review, Actions, or an embedded ```` ```citrine ```` block in the daily note), Citrine updates the SQLite row first and then attempts to update the source line in `source_rel_path`:
     1. Check `source_rel_path` at `source_byte_offset` (fast hint).
     2. If not at that offset, scan the entire `source_rel_path` file for `<!-- citrine:task=<task_id> -->`, splice the updated line, and update `source_byte_offset`.
     3. If the file is missing or `<!-- citrine:task=<task_id> -->` is no longer in the file, clear `source_rel_path = NULL` and `source_byte_offset = NULL` so the task becomes **database-only**.
4. **UI-Created Tasks:**
   - Tasks created directly from the Citrine UI (not typed inside a Markdown note) are stored in SQLite with `source_rel_path = NULL` and `source_byte_offset = NULL`.

Full grammar and SQLite table schemas are specified in [`docs/file-schema.md`](file-schema.md) (`FR-04`).

---

## 4. Database, Search, CLI & MCP Server (`N-03`, `FR-04`, `FR-06`, `FR-12`, `FR-13`)

- **SQLite via `drift`** is the primary structured store for tasks, events, habits (`D-17`), focus pins (`E-02`), review sessions (`R-04`), and workspace metadata, plus a note/backlink index and FTS5 virtual table for <200ms full-text search (`FR-06`).
- **Well-Documented Schema (`FR-04`):** Every SQLite table, column, and index is documented so users can inspect or query their database directly with standard SQLite tooling.
- **Command-Line Interface (`citrine` CLI, `FR-12`) & MCP Server (`citrine-mcp`, `FR-13`):**
  - Provide read and write access to query/filter tasks, notes, habits, reviews, and data views (outputting JSON or Markdown), create/complete/update tasks, export data-view snapshots, and inspect the database schema.

---

## 5. Plugin architecture (PL-01–PL-09)

**Decision: embedded QuickJS, not WASM**, given Citrine's plugin-author audience (per requirements.md's ADHD/BuJo/GTD knowledge-worker focus) most resembles Obsidian/Figma/VS Code's JS/TS-only ecosystems rather than the systems-programmer-adjacent audiences where multi-language WASM plugin ecosystems (Shopify Extism, Zellij) have taken hold. Multi-language support is deferred, not ruled out.

### 5.1 Why this is enforceable (unlike Obsidian)

Obsidian's plugins share the *same JS realm* as the Electron host (Node integration enabled, same process/global scope) — Obsidian's own docs concede they cannot restrict plugins to specific permissions because of this. Citrine's host is Dart (AOT-compiled); QuickJS is a separate embedded engine with **no filesystem, network, DOM, or `require` unless explicitly linked in**. This gives Citrine a real capability boundary Obsidian structurally cannot have.

### 5.2 Enforcement mechanism

- One `JSContext`/`JSRuntime` **per plugin instance** — no shared runtime, no cross-plugin state leakage.
- QuickJS's optional `std`/`os` modules (file/OS access) and any module loader with real file access are **never linked in**.
- Resource limits set on every plugin runtime via QuickJS's own public API: `JS_SetMemoryLimit`, `JS_SetMaxStackSize`, `JS_SetInterruptHandler` (cooperative step/time-based timeout) — the DoS-protection equivalent of a WASM engine's fuel metering.
- The **host bridge is the entire enforcement surface**: only functions corresponding to permissions the user granted (PL-02/PL-03) are attached to the plugin's global scope. Its design gets the same review rigor as a public API boundary.

### 5.3 Capability manifest (PL-02, PL-03)

```json
{
  "id": "com.example.weather-context",
  "name": "Weather Context",
  "version": "1.0.0",
  "permissions": ["tasks:read", "notes:read", "network:fetch"],
  "entry": "main.js"
}
```

Install is all-or-nothing (PL-03): the user reviews the full permission list once and accepts or declines. Revocation (PL-04) disables/uninstalls entirely for v1; per-permission revocation (PL-09) is an explicit future stretch, not v1 scope.

### 5.4 Host bridge sketch

```js
// Present only if "tasks:read" granted
citrine.tasks.list({ context: "@errands" });

// Present only if "tasks:write" granted
citrine.tasks.setState(taskId, "completed");

// Present only if "network:fetch" granted
citrine.net.fetch(url);
```

Plugins operate on the same Markdown files as the core app via this bridge (PL-05), never a private store.

### 5.5 iOS App Store compliance

Guideline 2.5.2 restricts downloading/executing code that changes app functionality, but interpreting downloaded script/bytecode through an engine compiled into the reviewed binary is an established, approved pattern (React Native/Expo OTA JS via JavaScriptCore; Roblox's downloaded Lua scripts via its own sandboxed VM). The binding technical constraint is that **iOS forbids runtime-generated native machine code (W^X)** for third-party apps — so the plugin runtime must run QuickJS in pure bytecode-interpreter mode (its default mode) on all platforms, never a JIT tier. This is a performance ceiling, not a legality blocker, and applies identically regardless of JS vs. WASM.

### 5.6 Core vs. community plugins (PL-08)

Core plugins (Daily Notes, Templates, Graph View, Canvas) ship compiled into the app and can be toggled off; they do not go through the QuickJS sandbox. Only third-party/community plugins run through the capability-scoped host bridge described above.

---

## 6. State management & app structure

**Riverpod** is the single state-management framework app-wide — chosen over Bloc because the majority of Citrine's surfaces (Daily/Monthly/Future Log, Inbox, Someday/Maybe, Waiting For, Reference, Contexts, search, Graph View) are read-mostly views over the drift reactive streams from §4, which map directly onto `StreamProvider`/`AsyncNotifierProvider`/`family` providers with minimal glue code.

The handful of genuinely multi-step, stateful flows — **Clarify** (G-01), **Migration** (B-06/B-07), and the guided **Weekly/Quarterly/Annual Review** rituals (R-01, R-04, Q-02, Y-02, resumable per R-04) — are modeled as `Notifier`s holding a `freezed` sealed-class state, giving Bloc-style explicit transition discipline and testability without a second framework.

### 6.1 Proposed module layout

```
lib/
  app/                    # shell, routing, theming, onboarding (A-06)
  core/
    vault/                # file I/O, watcher, Markdown parse/serialize (§3)
    index/                # drift database, DAOs, FTS5 queries (§4)
    domain/                # task state machine, recurrence engine, habit engine,
                            # migration/review logic, zombie-project detection
    plugins/               # QuickJS host, capability bridge, manifest model (§5)
    notifications/         # scheduling engine, platform channel wrappers (§7)
  features/
    daily_log/  monthly_log/  future_log/
    inbox_clarify/  projects/  someday_maybe/  waiting_for/  reference/
    engage/  focus/
    reviews/                # daily/weekly/quarterly/yearly rituals
    search/  graph_view/  canvas/
    plugin_manager/  settings/
  shared/
    widgets/
    markdown_editor/        # custom TextField + Live Preview decorator (§8)
```

Feature-first under `features/`, with `core/` as the platform-agnostic domain/data layer plugins and features both depend on.

### 6.2 UX architecture, visual identity & core workflows

Citrine's UI pairs a **Warm Paper, Deep Fountain-Pen Ink & Golden Citrine** visual palette (`A-01`), **jargon-free everyday wording** (`A-02` — no `"Hard Landscape"`, `"Zombie Projects"`, `"Gollwitzer If-Then"`, or internal spec IDs in user-facing copy), and **single-canvas views** (eliminating split screens):

1. **Four Primary Navigation Pillars + Hamburger Drawer (`FR-14`):**
   - **☀️ Today (Unified Daily Note + Past-Day Navigator, `B-01`):** A single unified view (no split screen) with a **Date Bar** at the top (`◀ Prev | Date Picker | Next ▶` + `Back to Today` for viewing past days) above the full-page `daily/YYYY-MM-DD.md` note generated from a customizable template and containing embedded ```` ```citrine ```` interactive data view blocks.
   - **✅ Actions & Inbox (GTD Engine):** Pure database-driven views for **Inbox** (+ 1-tap **Clarify** `G-01`), **Next Actions** (filterable by `@context`, time available, and energy `E-01`), **Projects** (surfacing **Stalled Projects** needing a next step `D-04`), **Waiting For** (`D-06`), and **Someday/Maybe** (`D-05`).
   - **🧭 Plan & Review (Pure Data Views, `B-02`, `B-12`):** Single-canvas database-driven planning and review views for enabled horizons (**Daily**, **Weekly**, **Monthly**, **Quarterly**, **Yearly**, and **Future**) without requiring backing `.md` files, plus 1-click static Markdown snapshot export (`T-02`).
   - **📓 Notes & Index (Knowledge Base):** Auto-generated **Index** (`B-04`: Collections, Projects, Areas of Focus, Recent Notes), Folder/Tag browser (`N-05`), and FTS5 Search / Quick Switcher (`N-03`, `N-04`).
   - **☰ Hamburger Menu (`Drawer`, `FR-14`):** Houses secondary utilities (Recent Views, Data Import/Export, Planning Process Setup, Field Guide, Settings, and **About Citrine**). Tapping/clicking the app version **7 times** on the About screen enables **Debug Mode**, revealing a **Debug** section in the Hamburger menu with **Override Current Date** (backed by an injectable `AppClock` provider and a top-bar active indicator with `-1d / +1d / Reset` controls).

2. **Persistent Global Affordances:**
   - **Quick Capture Bar (`P-01`, `P-02`, `C-01`):** Available from every primary surface via bottom bar or global hotkey, featuring a **sticky `[ Inbox | Today ]` destination toggle** that remembers the user's last choice.
   - **Recent Views & Documents Switcher (`🕒 Recent`, `N-04`, `A-08`):** Header strip/drawer listing recently visited notes, logs, projects, and task filters so users can immediately recover context after an interruption.
   - **Unobtrusive Background Progress Bar & Exit Guard (`FR-16`):** When Citrine runs background tasks (such as importing untagged tasks from externally added `.md` files), a slim progress bar appears at the top while keeping the app interactive, and an exit confirmation dialog warns the user if they attempt to close Citrine before background work completes.

3. **Launch, Onboarding & Session Continuity (`A-06`, `A-08`, `B-09`, `P-04`):**
   - **First launch (new vault):** 1-step folder setup + optional cadence toggle selection, seeding `daily/YYYY-MM-DD.md` from the default Daily Note template.
   - **External untagged task detection (`FR-16`):** Whenever new or externally modified `.md` files contain untagged tasks, Citrine shows a dismissible banner asking whether to import them into the database and append `<!-- citrine:task=<id> -->` comments in the background.
   - **Return within <2 hours:** Restores the user's **exact last open view/document and cursor/scroll position**.
   - **Return after ≥2 hours (same day):** Opens **Today** with a prominent `↩ Resume [[Last Open Note/View]]` chip at the top.
   - **Return on a new day (1–3 days) or after an absence (4+ days):** Never shows punitive red overdue badges or broken-streak alerts (`P-04`, `A-02`). Surfaces a calm migration pill (1–3 days) or a **"Fresh Start" card** (4+ days) to pick 1–3 focus items for today and sweep remaining open items into the review queue.

4. **In-Place Task Editing Everywhere (`D-19`, `B-05`, `D-15`):**
   - Clicking/tapping any task in *any* Citrine data view (Plan & Review, Actions, or an embedded ```` ```citrine ```` block inside the Daily Note) expands an **inline task editor** right inside the current view.
   - Edits update SQLite immediately and, if the task has a `source_rel_path`, update the source `.md` file via `(source_rel_path, source_byte_offset)` hint first, then full-file scan for `<!-- citrine:task=<id> -->`, or detach `source_rel_path = NULL` if the file or comment was removed.
   - A dedicated source badge (`[📄 source-note ↗]`) is shown when `source_rel_path != NULL` so the user can peek at or open the containing note when desired.

5. **Guided Review & Migration Rituals & Three-Layer Process Customization (`B-02`, `B-06`, `B-07`, `B-11`, `B-12`, `R-01`–`R-04`, `Q-02`, `Y-02`):**
   - **Cadence Ritual Structure:** Daily uses two lightweight bookends (**Daily Morning Plan** and **Daily Evening Wind-Down** surfaced directly on `☀️ Today` and `🧭 Plan & Review`), while Weekly, Monthly, Quarterly, and Yearly each use a unified **"Review & Plan"** transition ritual tailored to that horizon (`weeklyReviewPlan`, `monthlyReviewPlan`, `quarterlyReviewPlan`, `yearlyReviewPlan`).
   - **Full vs. Quick Mode + Low-Energy Day Mode:** Every ritual includes a 1-click toggle between the **Full Process** and a 2–3 minute **⚡ Quick Mode** for low-energy days, plus a **🛟 Low-Energy Day (Focus on 1 Thing)** toggle that caps daily focus to 1 priority item so finishing a single task counts as a complete win.
   - **Three-Layer Process Customization (`PlanningPresetCatalog`, `RitualProcessConfig`):**
     1. *Built-In Presets (`guidedPreset`)*: 14 curated presets across all 6 rituals (Citrine Default, Ivy Lee, Benjamin Franklin Morning/Evening/Virtue Ledger, Cal Newport Shutdown, GTD Weekly Review, 5-Minute Quick Reset, Bullet Journal Monthly Migration, 12-Week Quarterly Plan, Tim Ferriss 80/20 Past Year Review).
     2. *Step Customizer (`customSteps`)*: Enable/disable steps, mark which steps belong to Quick mode, reorder steps, or add custom **Reflection Prompt** and **Checklist** steps.
     3. *Unassisted Data View (`freeformMarkdown` / `unassistedView`)*: Bypass the guided step wizard and work directly in the daily note (`daily/YYYY-MM-DD.md`) or pure horizon data view (`B-02`).
   - **Progressive Learning & 1-Click Opt-Out (`LearningStage`):** Introduces rituals across 4 contextual stages (Stage 1: Morning Focus → Stage 2: Evening Wind-Down → Stage 3: Weekly Reset → Stage 4: Multi-Horizon), auto-collapses step coaching tips after 3 completions of a ritual, and provides a 1-click **Disable Guidance** toggle everywhere.
   - **Storage Boundary (`P-11`, `D-15`, `B-01`, `B-02`, `T-02`):** Daily notes live in `daily/YYYY-MM-DD.md` (with embedded ```` ```citrine ```` data view blocks), while Weekly, Monthly, Quarterly, and Yearly planning/review outcomes, reflections, and task decisions are stored in SQLite (with one-click static Markdown snapshot export `T-02`).

---

## 7. Markdown editing surface (C-03, D-14, N-01, P-07, A-07)

**Decision: a custom editor built on Flutter's `TextField`/`TextEditingController` with a cursor-aware decoration overlay** — an Obsidian-style Live Preview, not a structured block editor (super_editor/appflowy_editor).

Rationale: Obsidian's own Live Preview is built the same way (CodeMirror 6 — a plain-text buffer with a decoration/widget layer, not a document tree), so this is the more faithful analog for an "Obsidian-like" feel. It also means the edit buffer **is** the literal file content at all times — zero round-trip risk against P-11, versus a block-editor's document-tree model requiring a lossless parse↔serialize round-trip against the Obsidian-compatible schema (§3) on every load/save.

Mechanics: `**bold**` renders bold with asterisks hidden/dimmed except near the cursor; checkboxes render as tappable glyphs; `[[wikilinks]]` hide brackets except when the cursor is inside them. This is a genuine engineering investment (Flutter provides no CodeMirror-equivalent decoration engine out of the box) and is called out as a significant, dedicated line item — not incidental UI work.

---

## 8. Notifications & reminders (E-08–E-12, FR-05)

Reminders are **re-derived from the vault**, not stored only as a separate schedule: parsing a task/habit line's inline metadata (`📅`, `⏰`, `🔁`) is the source of truth for what should be scheduled, consistent with P-11. Each device independently re-derives and schedules its own native notifications (`flutter_local_notifications` or equivalent per platform) into a rolling window, since:

- iOS caps pending local notifications (historically 64), so a full recurrence expansion can't be scheduled at once — only a forward-rolling window, refreshed periodically.
- Android 13+ gates exact alarms behind permission and Doze; the scheduler must degrade gracefully to inexact-but-close delivery when exact-alarm permission isn't granted, consistent with P-04 (no punitive UX for a missed exact time).
- Cross-device reminder delivery explicitly depends on sync (FR-01) being enabled (E-11) — with sync deferred (§9), v1 reminders are single-device only, which is consistent with the requirement as written.

Notification permission requests are contextual (E-11): first reminder set, and (deferred until FR-01 exists) first sync enablement.

---

## 9. Sync posture (FR-01)

**Deferred entirely for v1.** T-01 and C-05 (fast local performance, offline capture) are MUSTs; FR-01 is a SHOULD. v1 ships single-device, fully offline, so the seams below are preserved for a later sync layer without requiring a rewrite:

- The vault is plain files — any sync transport (CRDT/P2P, cloud relay, or user-provided storage like Dropbox/iCloud/WebDAV) operates on files, not a private format.
- The index (§4) is a pure, rebuildable cache — a sync layer never needs to reconcile index state, only file state, then let the existing file-watcher/reparse path pick it up.
- T-03/T-04 (conflict handling, privacy defaults) and FR-08 (E2E encryption) are explicitly out of scope until FR-01 is prioritized, per the requirement's own phrasing ("applies once sync is enabled").

---

## 10. Testing strategy (sketch)

- **Domain layer** (task state machine, recurrence engine, habit streaks, migration/review logic): plain Dart unit tests, no widget harness needed.
- **State layer**: `ProviderContainer` + overrides for Notifiers/providers in isolation; ritual Notifiers tested via explicit state-transition assertions (Clarify decision tree, Migration, Review resumability).
- **Vault parser/serializer**: round-trip tests (parse → in-memory edit → serialize) asserting byte-stable output for untouched lines, since the vault is the source of truth and any drift here is a real data-integrity bug, not cosmetic.
- **Plugin host bridge**: permission-boundary tests asserting an unlisted capability's host function is genuinely absent from a plugin's global scope, not just unused.
- **Markdown editor decoration layer**: golden tests for rendering, since this is the highest-touch custom UI surface.

---

## 11. Traceability (requirements → design)

| Requirement group | Design section |
| --- | --- |
| P-11, D-15, FR-04, T-02, FR-07, FR-12, FR-13, FR-16 (user owns their data, task ID sync, CLI/MCP) | §1 Overview, §3.4–§3.5 Task sync, §4 Database/CLI/MCP |
| D-01–D-19 (core data model & in-place task edit) | §3 Vault & database schema, §6.1 `core/domain`, §6.2 |
| N-01–N-07 (notes, linking, search) | §3.2 block IDs, §4 Database & search |
| B-01–B-12 (unified Today note, pure data-view horizons, migration) | §3.4 Data views, §6.2 UX architecture |
| G-01–G-07 (GTD clarify/organize) | §6 Clarify Notifier |
| R-01–R-05, Q-01–Q-02, Y-01–Y-02, QY-03–QY-04 (review rituals) | §6 Review Notifiers, §6.2 |
| E-01–E-12 (engage, focus, reminders) | §6 Engage/Focus features, §8 Notifications |
| PL-01–PL-09 (plugins) | §5 Plugin architecture |
| A-01–A-08 (warm palette, jargon-free UX, cross-platform) | §2 Platform matrix, §6.2 UX, §7 Editor |
| T-01–T-05 (trust, reliability, snapshot export, platform) | §2 Platform matrix, §3.4 Snapshot export, §4 Perf, §10 Testing |
| FR-01, FR-08 (sync, encryption) | §9 Sync posture (deferred) |
| FR-09 (platform matrix) | §2 Platform matrix |
| FR-06 (search performance) | §4 Database & search |
| FR-05, E-08–E-12 (native notifications) | §8 Notifications & reminders |
| FR-14, FR-15 (Hamburger menu, About, 7-tap Debug & clock override, App icon) | §1 Overview, §6.2 UX architecture |

---

## 12. Explicitly deferred / open follow-ups

These are acknowledged gaps, not oversights — each depends on a decision this document intentionally scoped out:

- **FR-04 concrete schema spec** — full frontmatter/inline-syntax grammar as a standalone document.
- **Plugin host-bridge API reference** — full function-by-function spec per capability.
- **FR-02 calendar integration** mechanism (CalDAV/ICS/Google/Apple) — not designed here.
- **FR-03 import** scope and mapping (Obsidian, Todoist, Things, TickTick) — depends on FR-04 being finalized first.
- **FR-10 multi-vault support** — not addressed; single-vault assumed for v1.
- **AC-01–AC-03 accountability sharing** mechanism — not designed here.
- **T-05 accessibility specifics** (dyslexia-friendly font, reduced-motion) — flagged as a v1 settings-surface requirement, not yet designed.
- **Sync mechanism selection** (FR-01) — deferred per §9; revisit once v1's single-device experience is validated.
