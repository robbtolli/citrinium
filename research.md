## Features of Comparable Apps

### Todoist
### 1. Task Creation & Organization
* **Natural Language Input:** Quick Add parses dates, times, priorities, and projects as you type (e.g., "Buy milk tomorrow at 5pm #Groceries p1").
* **Hierarchy:** Projects, sections, tasks, and subtasks to structure work.
* **Recurring Due Dates:** Flexible scheduling like "every 1st Monday" or "every weekday".
* **Prioritization:** Four color-coded priority levels (P1 to P4).

### 2. Views & Customization
* **Core Views:** **Inbox** (for uncategorized tasks), **Today**, and **Upcoming** (7-day calendar/list view).
* **Layout Options:** Toggle between list view, Kanban board view, and calendar view.
* **Labels & Filters:** Tag tasks with labels (e.g., `@home`, `@computer`) and create custom views using powerful filter queries (e.g., `today & @work & p1`).

### 3. Collaboration
* **Shared Projects:** Invite others to collaborate on specific projects.
* **Task Delegation:** Assign individual tasks to specific collaborators.
* **Comments & Attachments:** Discuss tasks and attach files, voice notes, or links directly to them.

### 4. Productivity & Gamification
* **Todoist Karma:** A point-based gamification system tracking daily/weekly task completion and streaks.
* **Productivity Trends:** Visual charts showing completed tasks by project, label, or time period.

### 5. Ecosystem & Integrations
* **Cross-Platform Sync:** Real-time sync across Web, Mobile (iOS/Android), Desktop (Mac/Windows/Linux), and Wearables.
* **Integrations:** Direct syncing with Google Calendar, email clients (Outlook/Gmail), Slack, and automation tools (Zapier/IFTTT).

## Obsidian

### 1. Core Architecture
* **Local-First & Markdown-Based:** Notes are stored as plain-text `.md` files in a local folder ("vault"), ensuring offline speed, portability, and user ownership of data.
* **Bidirectional Linking:** The ability to link notes using `[[WikiLinks]]`. This builds a network of interconnected thoughts rather than just a hierarchical folder structure.
* **Backlinks & Outgoing Links:** A dedicated sidebar or section showing which notes link to the current note (backlinks) and which notes the current note links to.

### 2. Visualization & Organization
* **Graph View:** An interactive, node-based 2D/3D visualization of the entire vault, where notes are nodes and links are edges. Includes filtering, forces, and color-coding.
* **Canvas:** An infinite whiteboard interface where users can visually lay out, group, and connect notes, cards, images, and website embeds.
* **Folders & Nested Tags:** Traditional hierarchical folder organization coupled with tag support (including nested tags like `#project/status/active`) for multi-dimensional organization.

### 3. Editor Experience
* **Live Preview (WYSIWYG):** A hybrid editing mode that renders Markdown formatting (bold, links, lists, images) inline in real-time while remaining fully editable.
* **Source & Reading Modes:** Separate modes for raw Markdown editing and read-only, fully-rendered viewing.
* **Rich Media & Blocks:** Support for embedded images, PDFs, audio, video, LaTeX math equations (via MathJax), Mermaid.js diagrams, and code syntax highlighting.

### 4. Workspace & Navigation
* **Flexible Layouts:** Tabbed browsing, split panes (horizontal/vertical), and collapsible sidebars (left/right) for managing multiple open documents simultaneously.
* **Command Palette:** A central search interface (triggered by a hotkey) to run any application command or plugin action without leaving the keyboard.
* **Quick Switcher:** A rapid search tool to find and open files by name or content.

### 5. Extensibility
* **Core Plugins:** Modular built-in features that users can toggle on or off (e.g., Daily Notes, Outliner, Templates, Backlinks).
* **Community Plugins & CSS Themes:** An open ecosystem allowing users to install custom JavaScript plugins and custom CSS themes to modify aesthetics and expand functionality.

## ADHD

### 1. Core Executive Dysfunction Struggles
People with ADHD often experience executive dysfunction, which impacts their ability to plan, focus, remember instructions, and juggle multiple tasks. Key challenges include:
*   **Working Memory & "Out of Sight, Out of Mind":** If a task or note is not physically or visually present in their immediate field of vision, it effectively ceases to exist (leading to forgotten responsibilities and lost notes).
*   **Time Blindness:** Extreme difficulty estimating how much time has passed or how long a task will take to complete, leading to chronic lateness or last-minute rushes.
*   **Task Initiation & Overwhelm:** Large, ambiguous tasks trigger cognitive overwhelm, causing paralysis and procrastination because the brain struggles to sequence the required steps.
*   **Sustaining Focus & Novelty-Seeking:** ADHD brains suffer from chronic under-arousal (low dopamine). Once the initial novelty of a new app or system wears off, it is frequently abandoned.
*   **Friction Sensitivity:** High sensitivity to administrative friction. If entering a task or finding a note takes more than one or two steps, the user will avoid doing it.

### 2. Paper Notebook Strategies (Low-Tech Solutions)
Paper tools offer tactile, distraction-free environments that are highly effective for ADHD:
*   **The Bullet Journal (BuJo) Method:** Developed by Ryder Carroll (who has ADHD), this minimalist system uses rapid logging (simple symbols and short bullets) to drastically reduce the friction of capturing information.
*   **Tactile Memory Retention:** The physical act of writing by hand activates more areas of the brain, strengthening working memory and helping users process thoughts more deeply.
*   **Distraction Elimination:** Unlike smartphones, a paper notebook does not contain notifications, social media, or search tabs that can derail focus during task capture.
*   **Spatial Flexibility:** Pages can be used for anything—a daily log, a mind map, or free-form sketching—without being constrained by rigid database fields or app layouts.

### 3. Digital App Strategies (High-Tech Solutions)
Apps can compensate for executive dysfunction using automation and active prompting:
*   **Natural Language Input & Low Friction:** Quick-add engines (like Todoist) that parse text like "Call dentist tomorrow at 2pm" reduce capture friction before the thought is forgotten.
*   **Active Reminders & Alarms:** Persistent notifications, widgets, and alarms act as external "working memory" triggers to bring tasks back into focus.
*   **Visual Timers & Timeboxing:** Integrations of visual count-down clocks (e.g., Pomodoro timers) help fight time blindness by showing time as a shrinking visual block rather than abstract numbers.
*   **Micro-Task Breakdown:** Tools that help break down massive, daunting tasks into bite-sized, sequential checklists (sometimes using AI assistance) to lower the barrier to task initiation.
*   **Gamification & Instant Dopamine:** Point systems, badges, and completion streaks provide immediate positive feedback (dopamine hits) to motivate progress.

### 4. Product Design Implications
Design for ADHD should externalize executive function, minimize friction, and avoid punishing users for nonlinear attention.

*   **Capture in under two steps:** Global quick-add (hotkey, FAB, share sheet, widget) with natural-language parsing. If capture takes longer than a thought lasts, it will not happen.
*   **Externalize working memory:** Always-visible Today/Now surfaces, home-screen widgets, persistent side panels, and optional ambient reminders. Default to "out of sight still exists."
*   **Make time concrete:** Visual timers, time estimates next to tasks, "starts in / overdue by" labels, and gentle transition cues. Prefer supportive timeboxing over punitive deadlines.
*   **Shrink the start:** One-tap "break this down," suggested first micro-step, and a default "do this for 2 minutes" action to defeat initiation paralysis.
*   **Limit choice and clutter:** Calm defaults, progressive disclosure, focus/zen modes, and a "Top 3 today" constraint so infinite lists do not overwhelm.
*   **Forgiving systems:** Easy reschedule, no shame copy on missed tasks, migration/review rituals (BuJo-style) instead of guilt streaks that break and demotivate.
*   **Low-novelty-decay architecture:** Stable core UX with optional themes, seasonal accents, or lightweight rewards so novelty can refresh without forcing users to rebuild their whole system.
*   **Hybrid analog-digital:** Fast mobile/desktop capture + optional paper-like daily log or canvas; support handwriting/import where useful without requiring phone-only workflows.
*   **Emotion-aware, not pathologizing:** Soft language, optional mood check-ins tied to workload, and social/accountability scaffolds rather than rigid individualistic productivity theater.
*   **Search and continuity over perfect structure:** Full-text search, backlinks, and inbox-first capture beat mandatory folders/tags at entry time.

### 5. Sources & Citations
*   Barkley, R. A. — ADHD as impairment of executive function / "doing what you know"; present-moment bias and weak future orientation (foundational clinical framing of time and self-regulation).
*   Kofler, M. J., et al. (2020). *Working memory and short-term memory deficits in ADHD: A bifactor modeling approach.* Neuropsychology. Large working-memory impairments relative to short-term memory; supports external memory aids. https://pmc.ncbi.nlm.nih.gov/articles/PMC7483636/
*   Kofler, M. J., et al. (2024). Executive function deficits in ADHD (review/meta context). https://pmc.ncbi.nlm.nih.gov/articles/PMC11485171
*   Sonuga-Barke, E., et al. (2010 area) — temporal/delay discounting: immediate rewards outweigh distant ones; informs gamification and "make the next step rewarding now."
*   Carroll, R. (2018). *The Bullet Journal Method.* Portfolio/Penguin. BuJo created from Carroll's own ADHD; rapid logging, migration, intentional review. https://bulletjournal.com/pages/rydercarroll
*   Mueller, P. A., & Oppenheimer, D. M. (2014). *The pen is mightier than the keyboard.* Psychological Science. Handwriting can improve encoding/processing vs. verbatim typing (often cited for analog capture benefits).
*   Chen, J., Meng, Y., & Nie, K. (2026). *"Not Just Me and My To-Do List": Understanding Challenges of Task Management for Adults with ADHD and the Need for AI-Augmented Social Scaffolds.* arXiv:2603.17258. Task management as emotional/relational, not only cognitive; design for co-regulation and adaptive routines. https://arxiv.org/abs/2603.17258
*   Simply Psychology — ADHD & time blindness overview (Barkley-linked "now vs not now"). https://www.simplypsychology.org/adhd-time-blindness.html
*   Ly, A. (2024). *Time Unbound – Managing Time Blindness at Work.* Neurodiversity-affirming strategies (adapt/adjust/ask/accommodate).

# Productivity systems

## Bullet Journal

### Overview
The **Bullet Journal** (BuJo) is an analog personal-organization system created by digital product designer **Ryder Carroll**. He developed it to manage his own ADHD and information overwhelm, then shared it publicly in **2013**; the book *The Bullet Journal Method* followed in **2018** (Portfolio/Penguin). Carroll frames it as a way to **track the past, organize the present, and plan the future**—and often as “a mindfulness practice disguised as a productivity system,” not as Instagram-style art spreads.

Core idea: one blank notebook + pen + a tiny visual language. Function first; decoration is optional community culture, not the official method.

### Rapid Logging (the language)
Rapid logging is how everything is written: short bullets under a topic/date, not long prose.

**Entry types**
*   **Task** — `•` things to do
*   **Event** — `○` time-bound happenings (appointments, experiences)
*   **Note** — `–` facts, ideas, observations

**Task state changes**
*   `×` completed
*   `>` migrated (moved forward; still worth doing)
*   `<` scheduled (parked on a future date / Future Log)
*   struck through / irrelevant — intentionally dropped

Rapid logging also includes: **topics**, **page numbers**, and **short sentences**—so capture stays fast enough that thoughts are not lost.

### Core modules (collections backbone)
1. **Index** — First few pages; table of contents. When you start a new collection/topic, add its title + page number so the notebook stays searchable.
2. **Future Log** — Multi-month overview for items beyond the current month (deadlines, trips, birthdays).
3. **Monthly Log** — Typically a calendar/day list + a month task list; set up at month start.
4. **Daily Log** — Day-to-day workspace. Write the date and rapid-log as life happens. Pages are created as needed (no pre-printed empty days), so space flexes with busy vs. quiet days.

### Collections, threading, and signifiers
*   **Collections** — Any themed page set: projects, reading lists, habit trackers, meeting notes, goals. Added only when needed.
*   **Threading** — If a collection continues on a later page, link pages both ways (e.g. “→ 89” / “← 47”) so split topics stay navigable.
*   **Signifiers** — Optional marks (priority `*`, inspiration `!`, explore, etc.) layered on bullets for glanceable meaning without extra systems.

### Migration (the editorial engine)
Migration is the practice most people skip—and the part that makes BuJo more than a dump of open loops.

At day/month boundaries, unfinished tasks are reviewed one by one:
*   Still matter? → migrate (`>`) into the new Daily/Monthly Log
*   Has a date? → schedule (`<`) into Future/Monthly Log
*   No longer worth it? → cancel/strike

Rewriting creates **intentional friction**: you confront whether each open loop deserves more attention. That decision pressure is the point—not perfect completion rates.

### Practice rhythm
*   **Daily:** ~5–15 minutes rapid logging + light review
*   **Monthly setup/review:** ~15–30+ minutes (new Monthly Log + migration)
*   **Initial setup:** Index + Future Log + current Monthly Log (~30–60 minutes)

Start minimal (four core modules only); add collections only if they survive ongoing use.

### Why it works (especially for ADHD / overload)
*   **Externalizes working memory** — Write it once; brain stops juggling.
*   **Ultra-low capture friction** — Next empty line is always the inbox.
*   **No app distractions** — Paper has no notifications or infinite tabs.
*   **Forgiving structure** — Miss a week? Start a new Daily Log; no wasted pre-printed pages.
*   **Intentional prioritization** — Migration forces “is this still worth my time?”
*   **Handwriting encoding** — Often cited benefit vs. verbatim typing (see Mueller & Oppenheimer, 2014).
*   **One artifact for tasks + notes + reflection** — Reduces tool-switching.

### Common failure modes
*   **Aesthetics trap** — Hours on spreads; system abandoned. Official method is plain pen + notebook.
*   **Skipping migration** — Open tasks vanish across pages with no decision.
*   **Collection sprawl** — Dozens of trackers die after weeks; prune ruthlessly.
*   **Index neglect** — After ~100 pages the notebook becomes unsearchable.
*   **Perfectionism** — Fear of “messing up” pages blocks use; messy-and-used beats pretty-and-dead.

### Analog vs digital
| Strength of paper BuJo | Gap vs apps |
| --- | --- |
| Tactile focus, no notifications | No automatic reminders/alarms |
| Flexible spatial layout | Weak full-text search / backup |
| Migration friction = intentional review | Recurring tasks & sync are manual |
| Cheap, portable, private | Collaboration and sharing are hard |

Hybrid pattern many people use: **BuJo (or BuJo-like daily log) for capture + reflection**; **calendar/reminders app for time-critical anchors**.

### Product design implications (for an Obsidian-like / notes+tasks app)
*   **Rapid-log inbox** — One stream for tasks, events, notes with type toggles and keyboard-first entry.
*   **Stateful bullets** — Complete / migrate / schedule / drop as first-class actions, not buried menus.
*   **Daily + Monthly surfaces** — Auto “today” log; month overview; Future Log for undated-far items.
*   **Migration ritual UX** — End-of-day/week review that presents open items and requires keep / schedule / drop (preserve intentional friction; don’t silent-auto-carry everything forever without surfacing it).
*   **Index & threading** — Auto index of collections; backlinks between continued notes (digital threading).
*   **Collections without mandatory taxonomy** — Create on demand; don’t force folders at capture time.
*   **Signifiers & filters** — Priority/inspiration marks; filter views without complex query languages at entry.
*   **Resist decoration debt** — Themes OK; don’t make setup/templates a multi-hour onboarding.
*   **Missed-day forgiveness** — No broken streak shame; empty days simply don’t exist until used.
*   **Optional handwriting / paper import** — Bridge analog fans without requiring phone-only flow.

### Sources
*   Carroll, R. — Official method & FAQ: https://bulletjournal.com/
*   Carroll, R. (2018). *The Bullet Journal Method.* Portfolio/Penguin.
*   Carroll, R. — Personal ADHD origin: https://bulletjournal.com/pages/rydercarroll
*   Wikipedia — *Bullet journal* (history, components overview).
*   Mueller, P. A., & Oppenheimer, D. M. (2014). *The pen is mightier than the keyboard.* Psychological Science.
*   Supporting practice write-ups: rapid logging, migration, and module structure (community + official summaries; e.g. balancejournal / practicejournaling explainers aligned with Carroll’s core four modules).

## Getting Things Done (GTD)

### Overview
**Getting Things Done (GTD)** is a personal productivity methodology by **David Allen**, published in *Getting Things Done: The Art of Stress-Free Productivity* (**2001**; revised **2015**). Core claim: there is an inverse relationship between how much is on your mind and how much gets done. The mind is for *having* ideas, not *holding* them.

GTD externalizes all commitments (“open loops,” “incompletes,” or “stuff”) into a **trusted system**, then breaks work into clear outcomes and **next actions** so attention can stay on doing—not remembering.

Tagline ideals: **stress-free productivity**, **mind like water** (respond appropriately to inputs, then return to calm), and tool-agnostic implementation (paper or digital).

### Five-step workflow
Official stages (2nd edition naming):

1. **Capture** — Collect anything that has your attention into inboxes (physical tray, email, notes app, voice memos). Don’t organize at capture time.
2. **Clarify** — Process each inbox item: What is it? Is it actionable?
3. **Organize** — Park clarified items in the right lists/files/calendar.
4. **Reflect** — Review the system often enough that you trust it (especially the **Weekly Review**).
5. **Engage** — Choose what to do next with confidence, using context, time, energy, and priority.

(1st edition labels: collect → process → organize → plan → do; substance is the same.)

### Clarify decision tree (inbox processing)
For each item:

*   **Not actionable?**
    *   Trash / delete
    *   **Reference** (file for later lookup)
    *   **Someday/Maybe** (incubate; not committed now)
*   **Actionable?**
    *   Define the successful **outcome**
    *   Define the **next physical, visible action**
    *   If **≥2 steps** → it is a **Project** (outcome + at least one next action)
    *   If next action takes **≤2 minutes** → **Do it now** (2-minute rule)
    *   If someone else should do it → **Delegate** + track on **Waiting For**
    *   If it must happen on a date/time → **Calendar** (hard landscape only)
    *   Otherwise → **Next Actions** list(s), usually by **context**

Rule: empty inboxes regularly; never use the inbox as a to-do list; don’t put clarified items back in.

### Core lists and tools
*   **Inbox(es)** — Capture only
*   **Next Actions** — Single-step doables, often split by context (`@computer`, `@phone`, `@errands`, `@home`, `@office`, `@agenda-with-X`)
*   **Projects** — Multi-step outcomes currently committed (each needs ≥1 next action)
*   **Waiting For** — Delegated or blocked items with follow-up
*   **Someday/Maybe** — Ideas not currently active
*   **Calendar** — Date/time-specific commitments only (not a dumping ground for vague tasks)
*   **Reference** — Non-actionable support material
*   **Trash**

Optional supporting habits: project support material, checklists, tickler/43-folders-style future filing (classic paper implementation).

### Horizons of Focus (perspective)
GTD pairs **control** (workflow) with **perspective**. Six altitudes (bottom-up emphasis: clear the runway before big vision work feels real):

*   **Ground** — Current actions
*   **Horizon 1** — Current projects
*   **Horizon 2** — Areas of focus & accountability (roles/domains)
*   **Horizon 3** — 1–2 year goals
*   **Horizon 4** — Long-term vision
*   **Horizon 5** — Life / purpose

Unlike pure top-down goal systems, GTD argues people can’t sustainably focus on higher horizons while day-to-day open loops flood working memory.

### Weekly Review (the trust engine)
The Weekly Review keeps the system honest. Typical contents:

*   Get **inbox to zero** (capture + clarify + organize)
*   Review **calendar** (past week + upcoming)
*   Review **Projects** (each has a current next action)
*   Review **Next Actions**, **Waiting For**, **Someday/Maybe**
*   Capture new commitments; kill stale ones
*   Glance at higher horizons as needed

Without regular review, lists rot and the brain stops trusting the system—defeating the whole method.

### How you choose what to do (Engage)
When engaging, pick from next actions using:

1. **Context** — Where you are / tools available  
2. **Time available** — Fit the action to the slot  
3. **Energy available** — Match cognitive/physical demand  
4. **Priority** — Given the above, what matters most now  

Calendar items override discretionary next-action choice when time-bound.

### Why it works
*   **Externalizes prospective memory** — Reduces anxiety from open loops (aligned with distributed/extended-mind ideas; see Heylighen & Vidal, 2008).
*   **Front-end planning** — Ambiguity (“work on website”) becomes a next action (“email designer re: homepage draft”).
*   **2-minute rule** — Clears grit that would otherwise clog the system.
*   **Contexts** — Surface the right work at the right place/time.
*   **Projects vs actions** — Prevents mistaking multi-step outcomes for single tasks.
*   **Someday/Maybe** — Lets ideas exist without fake commitment.
*   **Tool-agnostic** — Method > app; many tools claim GTD support.

### Common failure modes
*   **Capture without clarify** — Inbox becomes a second brain dump of guilt.
*   **Projects without next actions** — “Zombie projects” that never move.
*   **Calendar as wish list** — Soft tasks pollute hard landscape; trust collapses.
*   **Skipping Weekly Review** — Stale lists; return to mental juggling.
*   **Over-contexting / over-tooling** — Endless setup, little engage.
*   **Next actions that aren’t physical/visible** — “Think about budget” is not a next action; “Open spreadsheet and list fixed costs” is.
*   **Using GTD as perfectionism** — System maintenance crowds out doing.

### GTD vs Bullet Journal (quick contrast)
| | **GTD** | **Bullet Journal** |
| --- | --- | --- |
| Primary metaphor | Trusted external system + decision workflow | Rapid log + migration in one notebook |
| Structure | Lists by type/context; projects; horizons | Chronological daily/monthly logs + collections |
| Review ritual | Weekly Review (system-wide) | Daily/monthly migration |
| Strength | Clarity of actionability & scale | Low-friction capture + intentional rewrite |
| Risk | Complexity / maintenance load | Lost items without index/migration |

Many people hybridize: BuJo-style capture + GTD clarify/organize rules + calendar for hard dates.

### Product design implications (for a notes + tasks app)
*   **Ubiquitous capture** — Global inbox, share sheet, email-to-inbox, quick add; zero organize-at-entry friction.
*   **Clarify wizard** — Actionable? Project? 2-minute? Delegate? Defer? Reference? Someday?
*   **First-class Project entity** — Outcome statement + guaranteed next action; warn on projects with none.
*   **Context tags/lists** — Filter Next Actions by `@context`, energy, time estimate.
*   **Waiting For + Someday/Maybe** — Separate from active next actions.
*   **Hard calendar vs soft tasks** — Don’t auto-dump todos onto calendar; support date-optional defer.
*   **Weekly Review mode** — Guided checklist: inbox zero, calendar sweep, project next-actions, stale purge.
*   **2-minute affordance** — Suggest “do now” for short items during clarify.
*   **Reference library** — File non-actionable notes/links without turning them into fake tasks.
*   **Engage view** — “What can I do *here* in *N* minutes with *this* energy?” not one infinite mega-list.
*   **Keep method visible, tools simple** — GTD fails when UX requires a second degree in the app.

### Sources
*   Allen, D. (2001; rev. 2015). *Getting Things Done: The Art of Stress-Free Productivity.* Penguin.
*   Official overview — Five steps: https://gettingthingsdone.com/what-is-gtd/
*   Wikipedia — *Getting Things Done* (workflow, horizons, reception).
*   Heylighen, F., & Vidal, C. (2008). *Getting Things Done: The Science behind Stress-Free Productivity.* Long Range Planning. Cognitive-science support for external reminders / distributed cognition. http://pespmc1.vub.ac.be/Papers/GTD-cognition.pdf
*   Fallows, J. (2004). “Organize Your Life!” *The Atlantic* — early mainstream reception.
*   Newport, C. (2020). “The Rise and Fall of Getting Things Done.” *The New Yorker* — later critique of GTD in knowledge-work culture.
*   Allen, D. — related: *Ready for Anything* (2003); *Making It All Work* (2008); *Team* (GTD with others).
