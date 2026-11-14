# Features of Comparable Apps

## Todoist

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

### 6. What users value and complain about
Review themes are directional rather than prevalence claims: ratings measure general satisfaction, and individual reviews are anecdotal. Checked on 2026-08-08, Todoist showed 4.8/5 from 128K Apple App Store ratings and 4.6/5 from 303K Google Play reviews. G2 provides useful recent detail but its reviews have varying validation and incentive status.

**Recurring value themes**

* **Fast, forgiving capture:** users consistently value Quick Add's natural-language parsing of dates, recurrence, labels, projects, and priority. This lets a thought become a structured task without a form, which is particularly valuable when attention is fleeting.
* **A trusted external memory:** reviews praise putting a future commitment into Todoist, including flexible recurrence such as completion-relative intervals, then being able to let go of remembering it. Calendar, email, Teams, widget, and voice capture integrations reinforce that trust across contexts.
* **Simple core with enough structure:** projects, sections, subtasks, labels, priorities, filters, and multiple views scale from personal lists to light collaboration without requiring a full project-management system. Users value this balance more than feature density.

**Recurring complaint and risk themes**

* **Pricing and paywalled essentials:** users report that reminders and more than a small number of projects are important personal-organization basics, yet expensive or unavailable on the free tier. A 2026 Google Play reviewer specifically objected to paying for reminders and more than five projects. Do not make the external-memory features required by E-08 through E-12 dependent on a premium tier.
* **Scheduling is less rich than capture:** users and review summaries still ask for start dates, duration, timeboxing, and better calendar planning rather than relying on a due date that becomes overdue. This validates Citrine's separate soft-task, defer/start-date, duration, and hard-calendar model (P-09, G-05, E-06 through E-09).
* **Reliability failures destroy system trust:** some reviews report weak notifications, recurring-task problems, or sync/offline discrepancies. These reports are anecdotal and may be fixed, but a missed medication or invisible completion is disproportionately harmful; reminders, recurrence, local persistence, and audit/history need stronger guarantees than a productivity graph.
* **Task manager, not knowledge base:** Todoist is praised for action management but its task-first structure provides little place for long-form thinking and supporting reference material. Citrine should keep task capture as fast as Todoist while retaining notes, links, and task context in the same vault (N-01, N-02, D-07, D-14).

### 7. Review sources
* Apple App Store: ratings, product description, and individual reviews: https://apps.apple.com/us/app/todoist-to-do-list-planner/id572688855
* Google Play: ratings, current reviews, and product description: https://play.google.com/store/apps/details?id=com.todoist
* G2: recent verified-review themes for natural-language capture, integrations, and organization: https://www.g2.com/products/todoist/reviews?qs=pros-and-cons
* Product Hunt: community review summary of strengths and advanced-workflow gaps: https://www.producthunt.com/products/todoist/reviews

---

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

### 6. What users value and complain about
Review themes are directional rather than prevalence claims: high ratings do not establish that every feature works for every workflow, and individual reviews are anecdotal. Checked on 2026-08-08, Obsidian showed 4.5/5 from 2.7K Apple App Store ratings and 4.1/5 from about 18K Google Play reviews. G2 has only three reviews, so it is useful for examples, not a representative sample.

**Recurring value themes**

* **Data ownership and longevity:** users repeatedly value local plain-Markdown files, offline access, and the ability to leave or use alternative sync without losing their notes. This is the clearest market validation of P-11: ownership is not merely an export checkbox, but part of whether people trust a second brain.
* **Flexible linked thinking:** backlinks, tags, graph view, tabs/split panes, and Canvas help users grow from folders into a connected knowledge base. Reviewers value being able to start simple and add structure later rather than commit to a database schema upfront.
* **Adaptability without a subscription for the core:** users praise a capable free local app and the plugin/theme ecosystem for supporting specialized writing, research, task, and visual workflows. The app can adapt to a user's process instead of forcing one method.

**Recurring complaint and risk themes**

* **Learning, setup, and plugin overload:** the same flexibility that power users value makes a blank vault, Markdown, links, plugin selection, and custom workflows intimidating. Users report that the product is easy for plain notes but becomes much steeper when they attempt a full "second brain." For ADHD-oriented onboarding, do not require customization before the first useful capture (P-01, P-07, A-06).
* **Configuration can become productivity procrastination:** community plugins add capability but can create incompatible conventions, maintenance burden, uneven quality, and an urge to design a system instead of use one. Citrine should provide a complete, calm core workflow and editable defaults; plugins must extend it rather than be required to obtain daily capture, tasks, review, or reminders (PL-01 through PL-08, A-07).
* **Mobile and collaboration friction:** reviewers describe desktop as the stronger experience; mobile navigation, tables/outlines, and some plugin workflows are less polished. Users also report that real-time shared editing and cross-device sync need workarounds or paid Sync and may risk conflicts when poorly managed. Preserve cross-platform core behavior and make sync/backup safety explicit (A-08, T-03, FR-01, FR-07).
* **Too much structure can hide the next action:** Obsidian's links, files, tags, and graph are excellent for reference and reflection, but do not inherently clarify a commitment, surface a next action, or make time concrete. Citrine must pair the vault's knowledge affordances with explicit task states, Today/Now, time/energy/context filters, and review rituals (D-02 through D-09, E-01 through E-07, R-01 through R-05).

### 7. Review sources
* Apple App Store: ratings, local-vault description, and individual reviews: https://apps.apple.com/us/app/obsidian-connected-notes/id1557175442
* Google Play: ratings, local-Markdown description, and current reviews: https://play.google.com/store/apps/details?id=md.obsidian
* G2: small-sample verified reviews on data control, learning curve, file scale, plugins, and collaboration: https://www.g2.com/products/obsidian/reviews
* Product Hunt: community review summary of linking/plugins and learning/mobile/search concerns: https://www.producthunt.com/products/obsidian/reviews

---

## Amplenote

### 1. Product model: an "Idea Execution Funnel"
Amplenote combines four work modes that are commonly separate apps: **Jots** (capture), **Notes** (refine and organize), **Tasks** (make work actionable), and **Calendar** (schedule). Its central interaction model is that an item should move from an unstructured thought to an action and, when useful, a time block without re-entering it in another tool. This is a useful model for Citrine's capture -> clarify/migrate -> engage path, but Amplenote is an account- and cloud-sync-based product, not a local Markdown vault model.

### 2. Work modes

| Mode | What it does | Transferable lesson |
| --- | --- | --- |
| **Jots** | A Jot is technically a note, presented as a date-oriented, low-clutter daily scratchpad. Daily Jots are automatically created, with virtual placeholders for uncreated recent days; they are sorted chronologically and normally carry the `daily-jots` tag. Free text and `[]` checkbox tasks can be mixed in the same capture stream; `@`/`[[...]]` linking can turn an idea into a separate note. | A chronological, unstructured first surface removes the "where does this go?" decision. A task must be creatable inline without leaving the log. |
| **Notes** | The same underlying content is shown with richer editing, tags, links/backlinks, sharing, and publishing. Jots are meant to be polished or organized later rather than perfectly structured at capture time. | Preserve the original capture and its context while allowing later refinement; do not require a separate task-description document. |
| **Tasks** | Tasks live in notes/Jots but are aggregated into a unified task list. Users can filter by tag, note, or date, save shortcuts, group by scheduled date or note, and inspect the source note. Recurrence, start/deadline, duration, urgency/importance, blocking, snooze, and task dependencies feed **Task Score**, a color-coded, editable heuristic ranking. | A unified action view must retain a route back to the note/log that explains the work. Decision support should narrow a large list, but remain transparent and user-overridable. |
| **Calendar** | Task Domains select the notes/tags whose tasks can appear in a calendar sidebar. Users filter to a domain/project, then drag a task onto day/week/month views to assign a start time and duration; dragging it back unschedules it. External calendars can be shown/synced. | Planning is more actionable when unscheduled work is beside real commitments and can be timeboxed by drag-and-drop. Keep time-blocked tasks reversible rather than treating the calendar as a permanent commitment. |

### 3. Bullet Journal-style rapid logging
Amplenote enables a **BuJo-adjacent digital daily log**, rather than reproducing the canonical method. Jots make today's page the default capture location; a line may be plain text, a `[]` task, or a link to a new/refined note. That supports rapid, chronological mixed capture of observations, actions, and emerging projects without mandatory folders or forms. Future date expressions can create future Jots, which provides a digital analogue of a Future Log.

Important differences matter for Citrine:

* Amplenote has no first-class BuJo task-state vocabulary for migrate, schedule, and drop, and no core ritual that asks the user to decide what to carry forward. Completed tasks disappear from the active list; defer/snooze and unscheduling exist, but do not provide BuJo's deliberate migration friction.
* A community "Bullet Journal" plugin creates a prompted daily reflection/gratitude template. It is optional and should not be mistaken for core support for rapid logging, collections, or migration.
* The dated Jot model is valuable, but Citrine should keep B-01/B-09's create-on-use and missed-day-forgiving behavior. Virtual or pre-created daily pages must never make an absence look like failure.

**Design conclusion:** use the daily log as the zero-friction front door and preserve mixed task/event/note capture (C-03, B-01), while adding the stateful migration and review decision that Amplenote's flow lacks (B-05 through B-07).

### 4. Getting Things Done-style workflow
Amplenote can be configured for GTD, but it does not enforce GTD as a workflow. Its own GTD guide maps Jots/quick tasks to **Capture**, asks users to clarify whether an item is actionable and define the next action/outcome, uses notes plus tags as project/reference organization, and relies on Task Score, shortcuts, and Calendar for **Engage**. A 2019 guide explicitly recommends capturing, clarifying, organizing, reflecting, and engaging, including a Someday/Maybe list.

This makes several GTD ideas easy to practice:

* Capture first, then turn selected lines into tasks while their supporting notes remain attached.
* Use tags, note-based projects, shortcuts, and Task Domains to separate active areas of work.
* Use duration, urgency, importance, and a unified list to decide what to do; the calendar can make a chosen task concrete through timeboxing.

It leaves important GTD discipline to the user: there is no first-class Clarify decision tree, guaranteed project outcome/next-action check, Waiting For list, or guided Weekly Review. Its Calendar also encourages scheduling tasks, whereas strict GTD reserves the calendar for hard landscape commitments. Timeboxing can help users with time blindness, but Citrine should retain P-09/G-05: a soft next action must not become a false appointment merely because it is visible in planning.

**Design conclusion:** combine Amplenote's context-preserving capture-to-task transition with Citrine's explicit G-01 Clarify flow, project/next-action safeguards, and guided review rather than assuming scores and tags replace them.

### 5. ADHD relevance and design lessons
These are feature-to-need hypotheses, not clinical evidence that Amplenote treats ADHD. They align with the executive-function challenges and product implications in the ADHD section above:

* **Working memory and friction:** Jots let a thought be written into today's chronological stream before the user decides whether it is a note, task, or project. Keeping a task in the note where it arose avoids retyping context and reduces app-switching; reviewers repeatedly describe the one-app workflow as its main value.
* **Overwhelm and initiation:** Task View turns note-embedded checkboxes into a filtered action list. Task Score uses visible, editable factors such as importance, urgency, start/deadline, duration, blocking, and recent attention to promote a small number of candidates. This can reduce the "where do I start?" decision, but an opaque or overconfident ranking must never replace user judgment, energy, or context.
* **Time blindness:** the calendar exposes tasks beside existing commitments and supports drag-to-timebox planning, fuzzy time options, start times, durations, and reminders via synced calendars. This makes intention more concrete than a floating task list.
* **Trust and non-shaming recovery:** users can unschedule/snooze instead of deleting a task. However, overdue highlighting and a score that rises with age could feel punitive or create red-list anxiety. Citrine should surface stale work for a conscious keep/schedule/drop decision in supportive language, not escalate it indefinitely (P-04, A-02, A-03, B-06).
* **Avoid administrative overload:** Task Domains, tag hierarchies, default task destinations, and score settings are powerful after habits form, but they impose setup and categorization work before the system is useful. For ADHD users, start with one capture surface, an inbox/default destination, and a short Today/Now list; progressively disclose domains, contexts, filters, and scoring (P-01, P-07, A-01, A-06).

### 6. What users value and complain about
Review sources have different sample sizes and incentives, so treat themes as directional rather than prevalence claims. Checked on 2026-08-08, the Apple App Store showed 4.6/5 from 475 ratings, Google Play 4.3/5 from 819 reviews, and G2 4.9/5 from only 8 reviews. Individual reviews are anecdotal; dated complaints may have been fixed.

**Recurring value themes**

* **One context-preserving workspace:** Apple and G2 reviewers value replacing separate notes, task, and calendar apps, particularly the ability to convert note lines into tasks and then schedule the same task without duplication. This directly reduces context-switching friction.
* **Fast daily brain dump plus later organization:** a G2 reviewer specifically values Jots as a place to drop material during the day and sort it later. The dated daily capture surface is therefore valuable independently of complex knowledge-management features.
* **Prioritization and scheduling support:** reviewers call out Task Score, urgency/importance, reminders, and drag-to-calendar scheduling as ways to decide what matters and make a plan. One Google Play reviewer praised fast note updates and two-way task/calendar changes after learning the tag setup.
* **Desktop depth with mobile access:** reviews describe the desktop app as powerful for planning while mobile is useful for capture and companion access. Keyboard shortcuts, quick open, widgets, and offline work reinforce low-friction capture across contexts.

**Recurring complaint and risk themes**

* **Learning/setup burden:** positive reviewers still describe a learning curve. Tag-dependent Task Domains and calendar sync are not self-evident; a Google Play reviewer needed days to discover that tags were required for Google Calendar tasks. Do not hide essential setup rules behind tutorials.
* **Complex or cluttered information architecture:** G2 reviewers report Jots, notes, archived items, and plugin notes feeling jumbled, and the full Task View can expose hundreds or thousands of tasks by default. This validates calm defaults, a bounded focus view, and progressive disclosure rather than an all-items landing page.
* **Tasks require a parent note:** some users value task context; others find having to choose or create a note for every task cumbersome. Preserve a sensible automatic home such as today's log/inbox, but always retain a source link and let users organize later.
* **Mobile parity and accessibility:** Google Play reviews say the desktop experience is stronger and report missing mobile tagging capabilities; the App Store does not list supported accessibility features. Cross-platform capture and core task state must be equivalent, while advanced planning can adapt to the screen size (A-08, T-05).
* **Reliability is foundational:** a 2026 Google Play review reports duplicated/deleted note sections, while the store's current release notes include repeated persistence and crash fixes. This is anecdotal, not proof of a systemic defect, but reinforces that data integrity, revision history, and portable primary storage are more important than productivity polish (P-11, T-01 through T-04).

### 7. Sources
* Amplenote Help — Idea Execution Funnel and four work modes: https://www.amplenote.com/help/idea_execution_funnel_explained
* Amplenote Help — Jots versus Notes, daily Jots, inline task and link syntax: https://www.amplenote.com/help/future_jots
* Amplenote Help — unified Task View, filters, grouping, and task-source context: https://www.amplenote.com/help/organizing_sorting_viewing_task_lists
* Amplenote Help — Task Score inputs, color thresholds, and manual override: https://www.amplenote.com/help/tasks_and_todos_task_score
* Amplenote Help — Task Domains, calendar filtering, task timeboxing/unscheduling, and mobile calendar: https://www.amplenote.com/help/calendar_visual_guided_walkthrough
* Amplenote Blog — GTD implementation guidance: https://www.amplenote.com/blog/getting_things_done_with_amplenote
* Amplenote public plugin — optional Bullet Journal daily reflection template: https://public.amplenote.com/aaEcia9F4yr56ro3pvZ52hjg
* Apple App Store — ratings, product description, and individual reviews: https://apps.apple.com/us/app/amplenote/id1436769674
* Google Play — ratings, product description, current reviews, and release notes: https://play.google.com/store/apps/details?id=com.amplenote
* G2 — small-sample verified-review themes and quoted pros/cons: https://www.g2.com/products/amplenote/reviews?qs=pros-and-cons
