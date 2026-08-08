# Product Requirements

Notes + tasks app for people with ADHD, supporting **Bullet Journal (BuJo)** and **Getting Things Done (GTD)** workflows (including hybrids).

Derived from `research.md`. Requirements are **unprioritized** for review. Suggest MoSCoW (Must / Should / Could / Won’t) or P0–P3 when prioritizing.

---

## 1. Product principles

These are non-negotiable design constraints, not features to ship later.

| ID | Principle | Priority |
| --- | --- | --- |
| P-01 | **Capture before organize** — Never force folders, projects, contexts, or tags at capture time. | MUST |
| P-02 | **Under-two-step capture** — From any primary surface, start capturing in ≤2 interactions (hotkey, FAB, widget, share sheet). | SHOULD |
| P-03 | **Externalize working memory** — Default to keeping commitments visible or easy to resurface; “out of sight” must not mean “gone.” | MUST |
| P-04 | **Forgiving, not shaming** — No guilt copy for missed days, broken streaks, or overdue soft tasks. Easy reschedule and drop. | MUST |
| P-05 | **Intentional friction on review, zero friction on capture** — Capture is instant; migration/weekly review may require deliberate keep / schedule / drop decisions. | MUST |
| P-06 | **Method-flexible, not method-locked** — Support BuJo-style logs *and* GTD lists; users may use one, the other, both, or neither. | MUST |
| P-07 | **Calm defaults, progressive disclosure** — Power features exist but do not dominate first-run or daily UI. | MUST |
| P-08 | **Search and links over perfect taxonomy** — Full-text search and linking beat mandatory hierarchy. | MUST |
| P-09 | **Hard calendar ≠ soft task list** — Date/time commitments stay distinct from undated next actions. | SHOULD |
| P-10 | **Stable core, optional novelty** — Themes/rewards may refresh interest without requiring system rebuild. | COULD |
| P-11 | **Files are the source of truth** — The vault is a folder of plain-text Markdown files on disk; the app is a view/editor over those files, not a database with an export feature bolted on. Any search index, cache, or sync layer is derived and rebuildable from the files, never the sole record of truth.  *NOTE: If there is any data where markdown files are not the source of truth, there MUST be a way to export the data to an easy to read/parse text format.* | SHOULD |

---

## 2. Core objects & data model

| ID | Requirement | Priority |
| --- | --- | --- |
| D-01 | Support a unified **entry** that can be typed as **task**, **event**, **note**, or left **untyped** (inbox stuff). | MUST |
| D-02 | Tasks have **states**: open, in-progress, completed, migrated, scheduled, dropped/canceled, waiting-for (delegated/blocked). | MUST |
| D-03 | Support **Projects** as multi-step outcomes with an outcome/title and zero or more linked next actions. | SHOULD |
| D-04 | Warn or surface **projects with no open next action** (“zombie projects”). | SHOULD |
| D-05 | Support **Someday/Maybe** as a first-class parking state/list (committed ≠ incubated). | SHOULD |
| D-06 | Support **Waiting For** items (person/system + optional follow-up date). | SHOULD |
| D-07 | Support **Reference** material (non-actionable notes/files/links) without converting them into tasks. | MUST |
| D-08 | Support **Contexts** (e.g. `@home`, `@computer`, `@errands`, `@phone`, custom) on actions. | MUST |
| D-09 | Support optional **time estimate**, **energy**, and **priority/signifier** on actions. | SHOULD |
| D-10 | Support **Collections** (BuJo): on-demand themed note/task groupings without mandatory folder trees at capture. | SHOULD |
| D-11 | Support **Daily Log**, **Monthly Log**, and **Future Log** surfaces (auto-created as used; no empty pre-printed days required). | SHOULD |
| D-12 | Support **threading/backlinks** between related notes, continued collections, projects, and logs. | SHOULD |
| D-13 | Optional **Areas of focus** (GTD Horizon 2) and higher-horizon notes (goals/vision/life) without blocking ground-level use. | COULD |
| D-14 | Entries support rich note body (Markdown) attached to a rapid-log line / task. | SHOULD |
| D-15 | **Local-first, file-based storage** — Notes and tasks are stored as Markdown files (with frontmatter/inline syntax for task/task-state metadata) directly on the user’s device/filesystem, per P-11. Offline use is fully functional; sync (if present) must not block capture and must reconcile against the files themselves, never a hidden database as the sole record.<br />*NOTE: If there is any data where markdown files are not the source of truth, there MUST be a way to export the data to an easy to read/parse text format.* | SHOULD |
| D-16 | Support **recurring tasks/events**: flexible recurrence rules (daily, weekly, monthly, yearly, custom intervals such as “every 1st Monday” or “every weekday”), independent of any single dated instance. Applies to tasks, events, and habit checks (D-17). | MUST |
| D-17 | Support **Habit tracking** as a first-class entity built on recurring tasks (D-16), with streak/completion history. Missed days must not produce shaming UI (per P-04/A-02); streak “breaks” are shown as history, not punitive resets. | MUST |
| D-18 | Tasks support lightweight **attachments and free-text notes/comments** (not only parent notes), e.g. links or short context, consistent with N-06. | SHOULD |

---

## 3. Capture

| ID | Requirement | Priority |
| --- | --- | --- |
| C-01 | **Global quick capture** from app home, system share sheet, and desktop/global hotkey where platform allows. | COULD |
| C-02 | **Inbox** accepts undifferentiated stuff; organize is a separate step. | MUST |
| C-03 | **Rapid logging**: keyboard-first stream mixing tasks, events, and notes with minimal type switching (symbol, shortcut, or toggle). | MUST |
| C-04 | **Natural language parsing** for dates/times where provided (e.g. “tomorrow 5pm”), without requiring NL for every entry. | MUST |
| C-05 | Capture works **offline** and queues sync later if applicable. | MUST |
| C-06 | Optional **voice capture** to inbox (nice for mobile friction reduction). | COULD |
| C-07 | Widgets / OS surfaces that show Today/Now and allow one-tap add (platform-dependent). | COULD |

---

## 4. Clarify & organize (GTD)

| ID | Requirement | Priority |
| --- | --- | --- |
| G-01 | **Clarify flow** for inbox items: actionable? → trash / reference / someday / project+next / do-now / delegate / calendar / next-action. | MUST |
| G-02 | **2-minute rule affordance**: during clarify, offer “do now” for short items; mark done without full project setup.<br />*Note: this is a "could", because users can do tasks that take less than 2 minutes without enering them into the app. So, the app doesn't need to explicitly support that.* | COULD |
| G-03 | Creating a project prompts for **outcome** and **at least one next action** (skippable with warning). | SHOULD |
| G-04 | Next actions default onto **context-filterable** lists, not only onto a single undifferentiated dump. | SHOULD |
| G-05 | **Calendar** accepts only explicit date/time (or all-day) commitments; soft tasks can have optional defer/start dates without becoming calendar noise by default. | SHOULD |
| G-06 | One-click file-to-**Reference** from inbox or note. | COULD |
| G-07 | Bulk clarify and keyboard-driven processing for inbox-to-zero sessions. | COULD |

---

## 5. Bullet Journal surfaces & migration

| ID | Requirement | Priority |
| --- | --- | --- |
| B-01 | **Daily Log** view: today’s rapid-log stream; create day only when used. | MUST |
| B-02 | **Monthly Log** view: month overview (days/events) + month open loops. | MUST |
| B-03 | **Future Log** view: items beyond current month / undated-far planning. | SHOULD |
| B-04 | **Index** (auto): list of collections, projects, and key notes with navigation. | SHOULD |
| B-05 | **Stateful bullet actions** one gesture away: complete, migrate, schedule, drop. | SHOULD |
| B-06 | **Migration / review ritual**: present open items and require keep (migrate), schedule, or drop—do not silently eternal-carry without surfacing. | MUST |
| B-07 | Daily and/or end-of-period migration modes (day, week, month). | MUST |
| B-08 | **Signifiers** (priority, inspiration, etc.) as lightweight marks, filterable later. | SHOULD |
| B-09 | Missed days do not break the product; user resumes on a new Daily Log without penalty UI. | MUST |
| B-10 | Collections creatable on demand from any note/log; no forced template aesthetics onboarding. | SHOULD |
| B-11 | The app ships **default, fully editable/replaceable templates** for each planning/review cadence it supports (Daily, Weekly, Monthly, Quarterly, Yearly logs and their review rituals — see §8), so new users get a working structure without building one from scratch. Editing or replacing a template must never disable the underlying feature. | MUST |

---

## 6. Engage & focus (doing work)

| ID | Requirement | Priority |
| --- | --- | --- |
| E-01 | **Engage / Now view**: filter by context + available time + energy + priority (“what can I do here in N minutes?”). | SHOULD |
| E-02 | **Today / Top N** focus mode (e.g. Top 3) to limit overwhelm; hide the infinite backlog by default in this mode. | SHOULD |
| E-03 | **Focus / zen mode**: single task or single log, minimal chrome, optional hide notifications inside app. | SHOULD |
| E-04 | **Break down** action: split a task/project into micro-next-steps (manual; optional assisted later). | SHOULD |
| E-05 | **Start for 2 minutes** (or configurable short sprint) to defeat initiation paralysis. | SHOULD |
| E-06 | **Visual timer / timeboxing** (e.g. Pomodoro-style) with gentle transition cues, not punitive failure states. | SHOULD |
| E-07 | Show **time estimates** and relative time copy (“starts in”, “deferred until”) to counter time blindness. | SHOULD |
| E-08 | **Built-in reminders/alerts are a core feature, not optional or plugin-dependent** — any task or event may have one or more reminders. Defaults are gentle and non-spammy (per P-04/A-02), but the capability itself is a Must-have, not a nicety. | MUST |
| E-09 | Calendar-bound items take precedence in Engage when time-specific. | SHOULD |
| E-10 | Reminders support **configurable lead time** (e.g. “at due time,” “30 minutes before,” “morning of,” custom offsets) and are **recurrence-aware**, tied to D-16 recurring tasks/habits (e.g. “remind me every weekday at 8am” for a habit). | MUST |
| E-11 | Reminders are delivered via **native OS notification/alarm surfaces** on each supported platform (mobile local/push notifications, desktop notification center) — not only in-app banners. Notification permission is requested **contextually**: (a) the first time the user sets a reminder on a given device, and (b) when the user enables sync (FR-01) on a device, preceded by an explanatory message clarifying that permission is needed to receive reminders that were created on other devices. **Cross-device reminder delivery** (a reminder set on one device firing on another) depends on sync (FR-01) being enabled; it must not be assumed or required without sync. | MUST |
| E-12 | **Snooze and reschedule** are available directly from the reminder/notification itself, not only inside the app, consistent with A-03. | SHOULD |

---

## 7. Review rituals

Covers **daily** and **weekly** review. See §8 for **quarterly** and **yearly** planning/review.

| ID | Requirement | Priority |
| --- | --- | --- |
| R-01 | Guided **Weekly Review** checklist: inbox zero, calendar past/upcoming, projects have next actions, review Next Actions / Waiting For / Someday, purge stale. | MUST |
| R-02 | Guided **Daily review / migration** shorter path for BuJo users. | MUST |
| R-03 | Surface stale items (no touch in N days) during review without shame language. | SHOULD |
| R-04 | Review progress is savable/resumable mid-session. | SHOULD |
| R-05 | Optional reminder to start review; missing it does not punish the user. | SHOULD |

---

## 8. Quarterly & Annual planning and review

| ID | Requirement | Priority |
| --- | --- | --- |
| Q-01 | **Quarterly Log/planning surface**: themes, goals, and priorities for the upcoming quarter, tied to GTD Horizon 3 (1–2 year goals) and referencing active Areas of Focus (D-13). | SHOULD |
| Q-02 | Guided **Quarterly Review** ritual (checklist style, like Weekly Review): review prior quarter’s goals and Areas of Focus, surface stale Projects/Someday-Maybe items, and set the next quarter’s themes. | SHOULD |
| Y-01 | **Yearly Log/planning surface**: annual themes/vision, tied to GTD Horizon 3/4 (long-term vision); reviewable/editable at any time, not locked to a single fixed date. | SHOULD |
| Y-02 | Guided **Annual Review** ritual: reflect on the year (completed projects, habits, Areas of Focus drift), carry forward or retire goals, set next year’s themes. | SHOULD |
| QY-03 | Quarterly/Yearly reviews are **never mandatory on a strict calendar date** — the app may surface a gentle prompt near quarter/year boundaries, but must never block usage or shame a skipped ritual (per P-04). | MUST |
| QY-04 | Quarterly/Yearly planning surfaces **link to/from Monthly and Weekly logs** (threading, per B-04/N-02) so review at any cadence can see the next level up or down. | SHOULD |

---

## 9. Notes, linking & knowledge

| ID | Requirement | Priority |
| --- | --- | --- |
| N-01 | First-class **notes** alongside tasks (same vault/workspace). | MUST |
| N-02 | **Wiki-style links** and **backlinks** between notes, projects, and log entries. | MUST |
| N-03 | Full-text **search** across notes, tasks, logs, projects, reference. | MUST |
| N-04 | Quick switcher / command palette for navigation and actions (keyboard-first). | SHOULD |
| N-05 | Optional folders/tags; never required to save. | SHOULD |
| N-06 | Attach images/files to notes and project support material. | COULD |
| N-07 | Daily notes / log integration so journaling and tasks share one timeline when desired. | MUST |

---

## 10. Extensibility: plugins & visualization

| ID | Requirement | Priority |
| --- | --- | --- |
| PL-01 | **Plugin architecture**: third-party/community plugins can extend functionality (new views, capture parsers, importers/exporters, integrations). | MUST |
| PL-02 | **Permission-scoped plugin model**: each plugin declares the capabilities it needs (e.g. view tasks, modify tasks, view notes, modify notes, create/delete files, network access) and the user must explicitly grant them at install time (and when the plugin is updated, if the permissions have changed). | MUST |
| PL-03 | **All-or-nothing install consent**: at install time, the user reviews the full list of permissions a plugin requests (e.g. view tasks, modify tasks, view notes, modify notes, create/delete files, network access) and either accepts all of them (installing the plugin) or declines (the plugin is not installed). Selective/partial granting per permission is not required for v1. | MUST |
| PL-04 | Users can **revoke a plugin at any time** from a central settings surface; for v1, revocation uninstalls/disables the plugin entirely (all-or-nothing), consistent with PL-03. | MUST |
| PL-05 | Plugins operate on the same Markdown files as the core app (per P-11) rather than a private/opaque store, so plugin-authored content stays portable and readable if the plugin is removed. | SHOULD |
| PL-06 | **Graph View**: visualize backlinks/links between notes, tasks, and projects (per N-02) as an interactive node graph. | COULD |
| PL-07 | **Canvas**: freeform, infinite-canvas surface for visually arranging notes, tasks, and images/embeds. | COULD |
| PL-08 | Core plugins (e.g. Daily Notes, Templates, Graph, Canvas) ship built-in and can be toggled off; this is distinct from community/third-party plugins, which always require explicit permission grants (PL-02) regardless of origin. | SHOULD |
| PL-09 | **Future/stretch**: granular, independently-revocable per-permission control (e.g. keep a plugin's "modify tasks" permission while revoking its "create files" permission, without fully uninstalling it), superseding the all-or-nothing model in PL-03/PL-04. | COULD |

---

## 11. ADHD-specific UX & tone

| ID | Requirement | Priority |
| --- | --- | --- |
| A-01 | Default UI is low-clutter; advanced filters/horizons behind progressive disclosure. | SHOULD |
| A-02 | Copy is supportive and neutral (no “you failed your streak” patterns). | MUST |
| A-03 | Easy **reschedule**, **snooze**, and **drop** everywhere tasks appear. | MUST |
| A-04 | Optional lightweight positive feedback on completion (points/celebration) that does not gate core features or punish breaks. | SHOULD |
| A-05 | Optional mood/energy check-in that can filter Engage suggestions—never required. | COULD |
| A-06 | Onboarding teaches capture → clarify/migrate → engage in minutes, not multi-hour setup. | SHOULD |
| A-07 | Avoid decoration-first templates; functional defaults first. | MUST |
| A-08 | Cross-platform consistency so the system is trusted on phone and desktop. | MUST |

---

## 12. Collaboration & accountability (lightweight, optional)

Research (Chen, Meng & Nie, 2026) notes that ADHD task management is often relational, not purely individual — people can benefit from light social/accountability scaffolds, not just solo lists. The following are lightweight, opt-in candidates. Full team collaboration remains a non-goal (X-02).

| ID | Requirement | Priority |
| --- | --- | --- |
| AC-01 | Optional **read-only share link/view** for a single log, project, or list (e.g. sharing today’s plan with a partner/coach/accountability buddy) without granting edit access. | COULD |
| AC-02 | Optional **check-in nudge** (e.g. “share a quick update with your accountability partner”) that is user-configured, never default-on, and never shaming if skipped. | COULD |
| AC-03 | No leaderboards, public feeds, or comparative social metrics (ties to X-01) — any accountability feature stays private/1:1, not competitive. | MUST |

---

## 13. Trust, reliability & platform

| ID | Requirement | Priority |
| --- | --- | --- |
| T-01 | Fast local performance; opening capture and Today is near-instant on target devices. | MUST |
| T-02 | Data export (e.g. markdown/JSON) so users are not locked in. | MUST |
| T-03 | Backup / sync conflict handling that does not silently drop inbox items. Applies once sync (FR-01) is enabled. | MUST |
| T-04 | Privacy-respecting defaults; clear about what leaves the device if cloud sync exists. Applies once sync (FR-01) is enabled. | MUST |
| T-05 | Accessibility: keyboard navigation, readable contrast, scalable type, optional **dyslexia-friendly font choice** (e.g. OpenDyslexic or similar), and a **reduced-motion/reduced-animation** setting for users sensitive to motion or visual noise. | COULD |

---

## 14. Concrete functional requirements

Many requirements above are principles or capabilities stated at a conceptual level. This section lists specific, testable, engineering-facing features that either underpin those principles or were previously buried as side-clauses inside other requirements.

| ID | Requirement | Priority |
| --- | --- | --- |
| FR-01 | Multi-device **sync** of the vault (mechanism TBD: cloud relay, CRDT/P2P, or user-provided storage like iCloud/Dropbox/WebDAV). | SHOULD |
| FR-02 | External **calendar integration** — subscribe to and/or export hard-landscape items to Google Calendar / Apple Calendar / CalDAV / ICS feed. | SHOULD |
| FR-03 | **Import** from other tools (Obsidian vault, Todoist, Things, TickTick) to ease migration/onboarding. | COULD |
| FR-04 | Documented **file/frontmatter schema** for tasks, notes, and logs (concrete spec behind P-11/D-15) so "files are the source of truth" is actually implementable and testable. | MUST |
| FR-05 | **Native OS push/local notification integration** per platform (iOS, Android, macOS, Windows, Linux) for reminders (concrete implementation behind E-08/E-11). | MUST |
| FR-06 | **Full-text search index** with a stated performance target (e.g. results in <200ms across a vault of N notes). | SHOULD |
| FR-07 | Manual **full-vault backup/export and restore**, distinct from continuous sync. | MUST |
| FR-08 | **End-to-end encryption** for any cloud-synced data, if FR-01 is implemented. | SHOULD |
| FR-09 | **Supported platform matrix** — explicit list of target platforms for v1 (project is scaffolded for Android/iOS/Linux/macOS/Windows/web). | MUST |
| FR-10 | **Multi-vault support** (multiple independent vaults, switchable, like Obsidian). | COULD |

---

## 15. Explicit non-goals (proposed)

Candidates to reject or defer unless prioritization says otherwise:

| ID | Non-goal |
| --- | --- |
| X-01 | Social network, public feeds, or heavy gamification leaderboards. |
| X-02 | Mandatory or full team collaboration (multi-editor shared vaults, task assignment, threaded comments) as v1 core. Lightweight 1:1 accountability sharing is a separate Could-have (see §12), not full collaboration. |
| X-03 | Pixel-perfect paper BuJo art/stickers as a product focus. |
| X-04 | Requiring users to pick “BuJo mode” *or* “GTD mode” exclusively. Users can use BuJo, GTD, both or neither. |
| X-05 | AI or plugins that auto-complete, auto-migrate, or act on files/tasks without user confirmation or without a granted permission scope (PL-02). Assistance OK; silent/unauthorized decisions not OK. |
| X-06 | Replacing a full calendar suite (integrate or simple hard-landscape is enough). |

---

## 16. Example user journeys (acceptance sketches)

Use these when prioritizing and writing acceptance criteria.

1. **Thought dump (ADHD + BuJo):** User hits capture, types three lines (task/event/note) into Today’s log in under 30 seconds, no filing.
2. **Inbox to zero (GTD):** User processes 20 inbox items via clarify; each lands in next action, project, someday, reference, calendar, waiting, trash, or done-now.
3. **Engage in context:** User filters `@errands` + 15 minutes + low energy; sees a short list, starts a 2-minute timer on one item.
4. **Migration:** End of day, open tasks appear; user migrates two, schedules one, drops one—none vanish silently.
5. **Weekly Review:** Guided flow surfaces a project with no next action; user adds one and finishes review.
6. **Resume after absence:** User returns after a week; no shame UI; new Daily Log; backlog available via review/migrate.
7. **Quarterly reset:** At the start of a new quarter, user gets a gentle prompt, opens the Quarterly Review, reflects on last quarter’s themes, marks two goals done, carries one forward, and sets three themes for the new quarter — fully skippable without guilt if ignored.
8. **A reminder that actually fires:** User adds a one-time reminder (“pick up prescription tomorrow 5pm”) and a recurring habit reminder (“stretch every weekday 8am”); both arrive as native OS notifications, and the user snoozes one directly from the notification.

---

## 17. Traceability (research → requirements)

| Research theme | Primary requirement groups |
| --- | --- |
| Working memory / out of sight | P-03, C-*, E-02, E-08, B-01 |
| Time blindness | E-06, E-07, E-09, G-05 |
| Initiation & overwhelm | E-02–E-05, A-01 |
| Friction sensitivity | P-01, P-02, C-01–C-03, A-06 |
| BuJo rapid log + migration | B-*, D-01, D-02, D-11 |
| GTD capture/clarify/engage | G-*, D-03–D-08, R-01, E-01 |
| Forgiving systems | P-04, B-09, A-02–A-03, R-05 |
| Notes + linking (Obsidian-like) | N-*, D-12, D-14 |
| Hybrid BuJo + GTD | P-06, X-04, journeys 1–5 |
| Recurring tasks, habits & reminders (Todoist-like; ADHD reinforcement) | D-16, D-17, E-08–E-12, FR-05, journey 8 |
| Quarterly/Annual planning & review | Q-01, Q-02, Y-01, Y-02, QY-03, QY-04, B-11, journey 7 |
| Data ownership / local files (Obsidian vault model) | P-11, D-15, PL-05, T-02, FR-04, FR-07 |
| Extensibility & visualization (Obsidian-like) | PL-01–PL-09 |
| Social/relational scaffolding (Chen et al. 2026) | AC-01–AC-03, X-02 |
| Accessibility beyond basics | T-05 |
| Ecosystem, sync & integrations (Todoist-like ecosystem, calendar sync) | FR-01, FR-02, FR-03, FR-05, FR-08, FR-09, FR-10 |

---

