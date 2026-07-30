# Product Requirements

Notes + tasks app for people with ADHD, supporting **Bullet Journal (BuJo)** and **Getting Things Done (GTD)** workflows (including hybrids).

Derived from `research.md`. Requirements are **unprioritized** for review. Suggest MoSCoW (Must / Should / Could / Won’t) or P0–P3 when prioritizing.

---

## 1. Product principles

These are non-negotiable design constraints, not features to ship later.

| ID | Principle |
| --- | --- |
| P-01 | **Capture before organize** — Never force folders, projects, contexts, or tags at capture time. |
| P-02 | **Under-two-step capture** — From any primary surface, start capturing in ≤2 interactions (hotkey, FAB, widget, share sheet). |
| P-03 | **Externalize working memory** — Default to keeping commitments visible or easy to resurface; “out of sight” must not mean “gone.” |
| P-04 | **Forgiving, not shaming** — No guilt copy for missed days, broken streaks, or overdue soft tasks. Easy reschedule and drop. |
| P-05 | **Intentional friction on review, zero friction on capture** — Capture is instant; migration/weekly review may require deliberate keep / schedule / drop decisions. |
| P-06 | **Method-flexible, not method-locked** — Support BuJo-style logs *and* GTD lists; users may use one, the other, or both. |
| P-07 | **Calm defaults, progressive disclosure** — Power features exist but do not dominate first-run or daily UI. |
| P-08 | **Search and links over perfect taxonomy** — Full-text search and linking beat mandatory hierarchy. |
| P-09 | **Hard calendar ≠ soft task list** — Date/time commitments stay distinct from undated next actions. |
| P-10 | **Stable core, optional novelty** — Themes/rewards may refresh interest without requiring system rebuild. |

---

## 2. Core objects & data model

| ID | Requirement |
| --- | --- |
| D-01 | Support a unified **entry** that can be typed as **task**, **event**, **note**, or left **untyped** (inbox stuff). |
| D-02 | Tasks have **states**: open, completed, migrated, scheduled, dropped/cancelled, waiting-for (delegated/blocked). |
| D-03 | Support **Projects** as multi-step outcomes with an outcome/title and zero or more linked next actions. |
| D-04 | Warn or surface **projects with no open next action** (“zombie projects”). |
| D-05 | Support **Someday/Maybe** as a first-class parking state/list (committed ≠ incubated). |
| D-06 | Support **Waiting For** items (person/system + optional follow-up date). |
| D-07 | Support **Reference** material (non-actionable notes/files/links) without converting them into tasks. |
| D-08 | Support **Contexts** (e.g. `@home`, `@computer`, `@errands`, `@phone`, custom) on actions. |
| D-09 | Support optional **time estimate**, **energy**, and **priority/signifier** on actions. |
| D-10 | Support **Collections** (BuJo): on-demand themed note/task groupings without mandatory folder trees at capture. |
| D-11 | Support **Daily Log**, **Monthly Log**, and **Future Log** surfaces (auto-created as used; no empty pre-printed days required). |
| D-12 | Support **threading/backlinks** between related notes, continued collections, projects, and logs. |
| D-13 | Optional **Areas of focus** (GTD Horizon 2) and higher-horizon notes (goals/vision/life) without blocking ground-level use. |
| D-14 | Entries support rich note body (markdown or equivalent) attached to a rapid-log line / task. |
| D-15 | Local-first or strong offline use with user-owned data preferred; sync if present must not block capture. |

---

## 3. Capture

| ID | Requirement |
| --- | --- |
| C-01 | **Global quick capture** from app home, system share sheet, and desktop/global hotkey where platform allows. |
| C-02 | **Inbox** accepts undifferentiated stuff; organize is a separate step. |
| C-03 | **Rapid logging**: keyboard-first stream mixing tasks, events, and notes with minimal type switching (symbol, shortcut, or toggle). |
| C-04 | **Natural language parsing** for dates/times where provided (e.g. “tomorrow 5pm”), without requiring NL for every entry. |
| C-05 | Capture works **offline** and queues sync later if applicable. |
| C-06 | Optional **voice capture** to inbox (nice for mobile friction reduction). |
| C-07 | Widgets / OS surfaces that show Today/Now and allow one-tap add (platform-dependent). |

---

## 4. Clarify & organize (GTD)

| ID | Requirement |
| --- | --- |
| G-01 | **Clarify flow** for inbox items: actionable? → trash / reference / someday / project+next / do-now / delegate / calendar / next-action. |
| G-02 | **2-minute rule affordance**: during clarify, offer “do now” for short items; mark done without full project setup. |
| G-03 | Creating a project prompts for **outcome** and **at least one next action** (skippable with warning). |
| G-04 | Next actions default onto **context-filterable** lists, not only onto a single undifferentiated dump. |
| G-05 | **Calendar** accepts only explicit date/time (or all-day) commitments; soft tasks can have optional defer/start dates without becoming calendar noise by default. |
| G-06 | One-click file-to-**Reference** from inbox or note. |
| G-07 | Bulk clarify and keyboard-driven processing for inbox-to-zero sessions. |

---

## 5. Bullet Journal surfaces & migration

| ID | Requirement |
| --- | --- |
| B-01 | **Daily Log** view: today’s rapid-log stream; create day only when used. |
| B-02 | **Monthly Log** view: month overview (days/events) + month open loops. |
| B-03 | **Future Log** view: items beyond current month / undated-far planning. |
| B-04 | **Index** (auto): list of collections, projects, and key notes with navigation. |
| B-05 | **Stateful bullet actions** one gesture away: complete, migrate, schedule, drop. |
| B-06 | **Migration / review ritual**: present open items and require keep (migrate), schedule, or drop—do not silently eternal-carry without surfacing. |
| B-07 | Daily and/or end-of-period migration modes (day, week, month). |
| B-08 | **Signifiers** (priority, inspiration, etc.) as lightweight marks, filterable later. |
| B-09 | Missed days do not break the product; user resumes on a new Daily Log without penalty UI. |
| B-10 | Collections creatable on demand from any note/log; no forced template aesthetics onboarding. |

---

## 6. Engage & focus (doing work)

| ID | Requirement |
| --- | --- |
| E-01 | **Engage / Now view**: filter by context + available time + energy + priority (“what can I do here in N minutes?”). |
| E-02 | **Today / Top N** focus mode (e.g. Top 3) to limit overwhelm; hide the infinite backlog by default in this mode. |
| E-03 | **Focus / zen mode**: single task or single log, minimal chrome, optional hide notifications inside app. |
| E-04 | **Break down** action: split a task/project into micro-next-steps (manual; optional assisted later). |
| E-05 | **Start for 2 minutes** (or configurable short sprint) to defeat initiation paralysis. |
| E-06 | **Visual timer / timeboxing** (e.g. Pomodoro-style) with gentle transition cues, not punitive failure states. |
| E-07 | Show **time estimates** and relative time copy (“starts in”, “deferred until”) to counter time blindness. |
| E-08 | Optional **gentle reminders/alarms** for hard commitments and user-requested nudges; defaults must not spam. |
| E-09 | Calendar-bound items take precedence in Engage when time-specific. |

---

## 7. Review rituals

| ID | Requirement |
| --- | --- |
| R-01 | Guided **Weekly Review** checklist: inbox zero, calendar past/upcoming, projects have next actions, review Next Actions / Waiting For / Someday, purge stale. |
| R-02 | Guided **Daily review / migration** shorter path for BuJo users. |
| R-03 | Surface stale items (no touch in N days) during review without shame language. |
| R-04 | Review progress is savable/resumable mid-session. |
| R-05 | Optional reminder to start review; missing it does not punish the user. |

---

## 8. Notes, linking & knowledge

| ID | Requirement |
| --- | --- |
| N-01 | First-class **notes** alongside tasks (same vault/workspace). |
| N-02 | **Wiki-style links** and **backlinks** between notes, projects, and log entries. |
| N-03 | Full-text **search** across notes, tasks, logs, projects, reference. |
| N-04 | Quick switcher / command palette for navigation and actions (keyboard-first). |
| N-05 | Optional folders/tags; never required to save. |
| N-06 | Attach images/files to notes and project support material. |
| N-07 | Daily notes / log integration so journaling and tasks share one timeline when desired. |

---

## 9. ADHD-specific UX & tone

| ID | Requirement |
| --- | --- |
| A-01 | Default UI is low-clutter; advanced filters/horizons behind progressive disclosure. |
| A-02 | Copy is supportive and neutral (no “you failed your streak” patterns). |
| A-03 | Easy **reschedule**, **snooze**, and **drop** everywhere tasks appear. |
| A-04 | Optional lightweight positive feedback on completion (points/celebration) that does not gate core features or punish breaks. |
| A-05 | Optional mood/energy check-in that can filter Engage suggestions—never required. |
| A-06 | Onboarding teaches capture → clarify/migrate → engage in minutes, not multi-hour setup. |
| A-07 | Avoid decoration-first templates; functional defaults first. |
| A-08 | Cross-platform consistency so the system is trusted on phone and desktop. |

---

## 10. Trust, reliability & platform

| ID | Requirement |
| --- | --- |
| T-01 | Fast local performance; opening capture and Today is near-instant on target devices. |
| T-02 | Data export (e.g. markdown/JSON) so users are not locked in. |
| T-03 | Backup / sync conflict handling that does not silently drop inbox items. |
| T-04 | Privacy-respecting defaults; clear about what leaves the device if cloud sync exists. |
| T-05 | Accessibility: keyboard navigation, readable contrast, scalable type. |

---

## 11. Explicit non-goals (proposed)

Candidates to reject or defer unless prioritization says otherwise:

| ID | Non-goal |
| --- | --- |
| X-01 | Social network, public feeds, or heavy gamification leaderboards. |
| X-02 | Mandatory team collaboration as v1 core (optional later; GTD Waiting For can be solo). |
| X-03 | Pixel-perfect paper BuJo art/stickers as a product focus. |
| X-04 | Requiring users to pick “BuJo mode” *or* “GTD mode” exclusively. |
| X-05 | AI that auto-completes or auto-migrates without user confirmation (assistance OK; silent decisions not OK). |
| X-06 | Replacing a full calendar suite (integrate or simple hard-landscape is enough). |

---

## 12. Example user journeys (acceptance sketches)

Use these when prioritizing and writing acceptance criteria.

1. **Thought dump (ADHD + BuJo):** User hits capture, types three lines (task/event/note) into Today’s log in under 30 seconds, no filing.
2. **Inbox to zero (GTD):** User processes 20 inbox items via clarify; each lands in next action, project, someday, reference, calendar, waiting, trash, or done-now.
3. **Engage in context:** User filters `@errands` + 15 minutes + low energy; sees a short list, starts a 2-minute timer on one item.
4. **Migration:** End of day, open tasks appear; user migrates two, schedules one, drops one—none vanish silently.
5. **Weekly Review:** Guided flow surfaces a project with no next action; user adds one and finishes review.
6. **Resume after absence:** User returns after a week; no shame UI; new Daily Log; backlog available via review/migrate.

---

## 13. Traceability (research → requirements)

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

---

## 14. Prioritization worksheet

Copy and fill during review:

| ID | MoSCoW | Notes |
| --- | --- | --- |
| P-01 | | |
| … | | |

Or track in issues with labels `P0`–`P3` mapped from MoSCoW.
