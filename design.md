# High-Level Design

This document describes the technical architecture for Citrinium, derived from `requirements.md`. It is written at the same level of detail as the requirements — component boundaries and rationale, not a full implementation spec. Concrete schemas (FR-04), a plugin host-bridge API reference, and a notification scheduling spec are follow-up documents once this design is accepted.

Non-goals X-01–X-06 from `requirements.md` are assumed and not re-litigated here.

---

## 1. Architecture overview

Citrinium is a layered, offline-first Flutter application. The guiding constraint (P-11) is that every layer above the vault is a **derived, rebuildable cache** — nothing above the file layer is allowed to become a second source of truth.

```
┌─────────────────────────────────────────────────────────────┐
│ Presentation                                                 │
│  Daily/Monthly/Future Log · Inbox/Clarify · Engage · Focus   │
│  Reviews (Daily/Weekly/Quarterly/Annual) · Graph · Canvas    │
│  Markdown editor (custom TextField + Live Preview decorator) │
├─────────────────────────────────────────────────────────────┤
│ State (Riverpod)                                             │
│  Providers over repositories · freezed sealed-state Notifiers│
│  for multi-step rituals (Clarify, Migration, Review)          │
├─────────────────────────────────────────────────────────────┤
│ Domain                                                        │
│  Task state machine (D-02) · recurrence engine (D-16)         │
│  habit/streak engine (D-17) · migration & review logic (B-*, R-*, Q-*, Y-*) │
│  zombie-project detection (D-04)                              │
├──────────────────────────┬──────────────────────────────────┤
│ Index (drift/SQLite)     │ Plugin host (QuickJS)             │
│  derived, rebuildable    │  per-plugin JSContext              │
│  cache of tasks/notes/   │  capability-scoped host bridge     │
│  links; FTS5 search      │  (PL-01–PL-09)                     │
├──────────────────────────┴──────────────────────────────────┤
│ Vault                                                         │
│  Plain Markdown files on disk (Obsidian-compatible schema)    │
│  File watcher · parser/serializer · frontmatter               │
├─────────────────────────────────────────────────────────────┤
│ Platform services                                             │
│  Native notification scheduling (E-08–E-12, FR-05)             │
│  Filesystem access per OS (Android/iOS/Linux/macOS/Windows)    │
└─────────────────────────────────────────────────────────────┘
```

Data flows down for writes (UI → domain → vault file rewrite) and up for reads (file watcher → reparse → index update → provider stream → UI). The index and plugin host are peers: both are derived/sandboxed consumers of the vault, neither is trusted as authoritative.

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
| `- [w]` | waiting-for (Citrinium extension; still a valid checkbox line for any generic Markdown/Obsidian reader, and configurable as a custom status in the Obsidian Tasks plugin) |

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

Standalone files (notes, projects, collections, Areas of Focus) use YAML frontmatter. Citrinium-specific fields are namespaced under `citrinium:` so the file stays meaningful to any other Markdown tool that ignores unknown keys:

```yaml
---
citrinium:
  type: project
  id: 7f3a2b1c
  outcome: "Ship v1.0 to TestFlight"
  status: active
  area: Health
tags: [project, health]
---
```

### 3.4 Logs

Daily/Monthly/Future Log surfaces (B-01–B-03, D-11) are one file per period (e.g. `daily/2026-07-30.md`), created on first use — never pre-generated — satisfying B-09/P-04.

A full frontmatter/inline-syntax reference (concrete grammar, edge cases, migration notes) is a follow-up spec under FR-04.

---

## 4. Index & search (N-03, FR-06)

- **SQLite via `drift`** holds a derived cache: parsed tasks, notes, backlinks, and an FTS5 virtual table for full-text search. Target: <200ms search across representative vault sizes (FR-06).
- The index is **rebuildable from files at any time** — deleting it and reparsing the vault must always converge to the same state. This is the concrete mechanism satisfying P-11's "derived, rebuildable, never sole record of truth."
- A file watcher triggers incremental reparse-and-upsert on external changes (e.g. edits made in another editor, or by a synced copy of the vault, once FR-01 exists).
- `drift`'s reactive `Stream` queries are the boundary the state layer (§6) consumes directly.

---

## 5. Plugin architecture (PL-01–PL-09)

**Decision: embedded QuickJS, not WASM**, given Citrinium's plugin-author audience (per requirements.md's ADHD/BuJo/GTD knowledge-worker focus) most resembles Obsidian/Figma/VS Code's JS/TS-only ecosystems rather than the systems-programmer-adjacent audiences where multi-language WASM plugin ecosystems (Shopify Extism, Zellij) have taken hold. Multi-language support is deferred, not ruled out.

### 5.1 Why this is enforceable (unlike Obsidian)

Obsidian's plugins share the *same JS realm* as the Electron host (Node integration enabled, same process/global scope) — Obsidian's own docs concede they cannot restrict plugins to specific permissions because of this. Citrinium's host is Dart (AOT-compiled); QuickJS is a separate embedded engine with **no filesystem, network, DOM, or `require` unless explicitly linked in**. This gives Citrinium a real capability boundary Obsidian structurally cannot have.

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
citrinium.tasks.list({ context: "@errands" });

// Present only if "tasks:write" granted
citrinium.tasks.setState(taskId, "completed");

// Present only if "network:fetch" granted
citrinium.net.fetch(url);
```

Plugins operate on the same Markdown files as the core app via this bridge (PL-05), never a private store.

### 5.5 iOS App Store compliance

Guideline 2.5.2 restricts downloading/executing code that changes app functionality, but interpreting downloaded script/bytecode through an engine compiled into the reviewed binary is an established, approved pattern (React Native/Expo OTA JS via JavaScriptCore; Roblox's downloaded Lua scripts via its own sandboxed VM). The binding technical constraint is that **iOS forbids runtime-generated native machine code (W^X)** for third-party apps — so the plugin runtime must run QuickJS in pure bytecode-interpreter mode (its default mode) on all platforms, never a JIT tier. This is a performance ceiling, not a legality blocker, and applies identically regardless of JS vs. WASM.

### 5.6 Core vs. community plugins (PL-08)

Core plugins (Daily Notes, Templates, Graph View, Canvas) ship compiled into the app and can be toggled off; they do not go through the QuickJS sandbox. Only third-party/community plugins run through the capability-scoped host bridge described above.

---

## 6. State management & app structure

**Riverpod** is the single state-management framework app-wide — chosen over Bloc because the majority of Citrinium's surfaces (Daily/Monthly/Future Log, Inbox, Someday/Maybe, Waiting For, Reference, Contexts, search, Graph View) are read-mostly views over the drift reactive streams from §4, which map directly onto `StreamProvider`/`AsyncNotifierProvider`/`family` providers with minimal glue code.

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
| P-11, D-15, FR-04, T-02, FR-07 (files as source of truth) | §3 Vault & file schema |
| D-01–D-18 (core data model) | §3 Vault & file schema, §6.1 `core/domain` |
| N-01–N-07 (notes, linking, search) | §3.2 block IDs, §4 Index & search |
| B-01–B-11 (BuJo surfaces & migration) | §3.4 Logs, §6 ritual Notifiers |
| G-01–G-07 (GTD clarify/organize) | §6 Clarify Notifier |
| R-01–R-05, Q-01–Q-02, Y-01–Y-02, QY-03–QY-04 (review rituals) | §6 Review Notifiers |
| E-01–E-12 (engage, focus, reminders) | §6 Engage/Focus features, §8 Notifications |
| PL-01–PL-09 (plugins) | §5 Plugin architecture |
| A-01–A-08 (ADHD UX, cross-platform) | §2 Platform matrix, §7 Editor (calm defaults) |
| T-01–T-05 (trust, reliability, platform) | §2 Platform matrix, §4 Index (perf), §10 Testing |
| FR-01, FR-08 (sync, encryption) | §9 Sync posture (deferred) |
| FR-09 (platform matrix) | §2 Platform matrix |
| FR-06 (search performance) | §4 Index & search |
| FR-05, E-08–E-12 (native notifications) | §8 Notifications & reminders |

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
