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

### 6. What users value and complain about
Review themes are directional rather than prevalence claims: ratings measure general satisfaction, and individual reviews are anecdotal. Checked on 2026-08-08, Todoist showed 4.8/5 from 128K Apple App Store ratings and 4.6/5 from 303K Google Play reviews. G2 provides useful recent detail but its reviews have varying validation and incentive status.

**Recurring value themes**

* **Fast, forgiving capture:** users consistently value Quick Add's natural-language parsing of dates, recurrence, labels, projects, and priority. This lets a thought become a structured task without a form, which is particularly valuable when attention is fleeting.
* **A trusted external memory:** reviews praise putting a future commitment into Todoist, including flexible recurrence such as completion-relative intervals, then being able to let go of remembering it. Calendar, email, Teams, widget, and voice capture integrations reinforce that trust across contexts.
* **Simple core with enough structure:** projects, sections, subtasks, labels, priorities, filters, and multiple views scale from personal lists to light collaboration without requiring a full project-management system. Users value this balance more than feature density.

**Recurring complaint and risk themes**

* **Pricing and paywalled essentials:** users report that reminders and more than a small number of projects are important personal-organization basics, yet expensive or unavailable on the free tier. A 2026 Google Play reviewer specifically objected to paying for reminders and more than five projects. Do not make the external-memory features required by E-08 through E-12 dependent on a premium tier.
* **Scheduling is less rich than capture:** users and review summaries still ask for start dates, duration, timeboxing, and better calendar planning rather than relying on a due date that becomes overdue. This validates Citrinium's separate soft-task, defer/start-date, duration, and hard-calendar model (P-09, G-05, E-06 through E-09).
* **Reliability failures destroy system trust:** some reviews report weak notifications, recurring-task problems, or sync/offline discrepancies. These reports are anecdotal and may be fixed, but a missed medication or invisible completion is disproportionately harmful; reminders, recurrence, local persistence, and audit/history need stronger guarantees than a productivity graph.
* **Task manager, not knowledge base:** Todoist is praised for action management but its task-first structure provides little place for long-form thinking and supporting reference material. Citrinium should keep task capture as fast as Todoist while retaining notes, links, and task context in the same vault (N-01, N-02, D-07, D-14).

### 7. Review sources
* Apple App Store: ratings, product description, and individual reviews: https://apps.apple.com/us/app/todoist-to-do-list-planner/id572688855
* Google Play: ratings, current reviews, and product description: https://play.google.com/store/apps/details?id=com.todoist
* G2: recent verified-review themes for natural-language capture, integrations, and organization: https://www.g2.com/products/todoist/reviews?qs=pros-and-cons
* Product Hunt: community review summary of strengths and advanced-workflow gaps: https://www.producthunt.com/products/todoist/reviews

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
* **Configuration can become productivity procrastination:** community plugins add capability but can create incompatible conventions, maintenance burden, uneven quality, and an urge to design a system instead of use one. Citrinium should provide a complete, calm core workflow and editable defaults; plugins must extend it rather than be required to obtain daily capture, tasks, review, or reminders (PL-01 through PL-08, A-07).
* **Mobile and collaboration friction:** reviewers describe desktop as the stronger experience; mobile navigation, tables/outlines, and some plugin workflows are less polished. Users also report that real-time shared editing and cross-device sync need workarounds or paid Sync and may risk conflicts when poorly managed. Preserve cross-platform core behavior and make sync/backup safety explicit (A-08, T-03, FR-01, FR-07).
* **Too much structure can hide the next action:** Obsidian's links, files, tags, and graph are excellent for reference and reflection, but do not inherently clarify a commitment, surface a next action, or make time concrete. Citrinium must pair the vault's knowledge affordances with explicit task states, Today/Now, time/energy/context filters, and review rituals (D-02 through D-09, E-01 through E-07, R-01 through R-05).

### 7. Review sources
* Apple App Store: ratings, local-vault description, and individual reviews: https://apps.apple.com/us/app/obsidian-connected-notes/id1557175442
* Google Play: ratings, local-Markdown description, and current reviews: https://play.google.com/store/apps/details?id=md.obsidian
* G2: small-sample verified reviews on data control, learning curve, file scale, plugins, and collaboration: https://www.g2.com/products/obsidian/reviews
* Product Hunt: community review summary of linking/plugins and learning/mobile/search concerns: https://www.producthunt.com/products/obsidian/reviews

## Amplenote

### 1. Product model: an "Idea Execution Funnel"
Amplenote combines four work modes that are commonly separate apps: **Jots** (capture), **Notes** (refine and organize), **Tasks** (make work actionable), and **Calendar** (schedule). Its central interaction model is that an item should move from an unstructured thought to an action and, when useful, a time block without re-entering it in another tool. This is a useful model for Citrinium's capture -> clarify/migrate -> engage path, but Amplenote is an account- and cloud-sync-based product, not a local Markdown vault model.

### 2. Work modes

| Mode | What it does | Transferable lesson |
| --- | --- | --- |
| **Jots** | A Jot is technically a note, presented as a date-oriented, low-clutter daily scratchpad. Daily Jots are automatically created, with virtual placeholders for uncreated recent days; they are sorted chronologically and normally carry the `daily-jots` tag. Free text and `[]` checkbox tasks can be mixed in the same capture stream; `@`/`[[...]]` linking can turn an idea into a separate note. | A chronological, unstructured first surface removes the "where does this go?" decision. A task must be creatable inline without leaving the log. |
| **Notes** | The same underlying content is shown with richer editing, tags, links/backlinks, sharing, and publishing. Jots are meant to be polished or organized later rather than perfectly structured at capture time. | Preserve the original capture and its context while allowing later refinement; do not require a separate task-description document. |
| **Tasks** | Tasks live in notes/Jots but are aggregated into a unified task list. Users can filter by tag, note, or date, save shortcuts, group by scheduled date or note, and inspect the source note. Recurrence, start/deadline, duration, urgency/importance, blocking, snooze, and task dependencies feed **Task Score**, a color-coded, editable heuristic ranking. | A unified action view must retain a route back to the note/log that explains the work. Decision support should narrow a large list, but remain transparent and user-overridable. |
| **Calendar** | Task Domains select the notes/tags whose tasks can appear in a calendar sidebar. Users filter to a domain/project, then drag a task onto day/week/month views to assign a start time and duration; dragging it back unschedules it. External calendars can be shown/synced. | Planning is more actionable when unscheduled work is beside real commitments and can be timeboxed by drag-and-drop. Keep time-blocked tasks reversible rather than treating the calendar as a permanent commitment. |

### 3. Bullet Journal-style rapid logging
Amplenote enables a **BuJo-adjacent digital daily log**, rather than reproducing the canonical method. Jots make today's page the default capture location; a line may be plain text, a `[]` task, or a link to a new/refined note. That supports rapid, chronological mixed capture of observations, actions, and emerging projects without mandatory folders or forms. Future date expressions can create future Jots, which provides a digital analogue of a Future Log.

Important differences matter for Citrinium:

* Amplenote has no first-class BuJo task-state vocabulary for migrate, schedule, and drop, and no core ritual that asks the user to decide what to carry forward. Completed tasks disappear from the active list; defer/snooze and unscheduling exist, but do not provide BuJo's deliberate migration friction.
* A community "Bullet Journal" plugin creates a prompted daily reflection/gratitude template. It is optional and should not be mistaken for core support for rapid logging, collections, or migration.
* The dated Jot model is valuable, but Citrinium should keep B-01/B-09's create-on-use and missed-day-forgiving behavior. Virtual or pre-created daily pages must never make an absence look like failure.

**Design conclusion:** use the daily log as the zero-friction front door and preserve mixed task/event/note capture (C-03, B-01), while adding the stateful migration and review decision that Amplenote's flow lacks (B-05 through B-07).

### 4. Getting Things Done-style workflow
Amplenote can be configured for GTD, but it does not enforce GTD as a workflow. Its own GTD guide maps Jots/quick tasks to **Capture**, asks users to clarify whether an item is actionable and define the next action/outcome, uses notes plus tags as project/reference organization, and relies on Task Score, shortcuts, and Calendar for **Engage**. A 2019 guide explicitly recommends capturing, clarifying, organizing, reflecting, and engaging, including a Someday/Maybe list.

This makes several GTD ideas easy to practice:

* Capture first, then turn selected lines into tasks while their supporting notes remain attached.
* Use tags, note-based projects, shortcuts, and Task Domains to separate active areas of work.
* Use duration, urgency, importance, and a unified list to decide what to do; the calendar can make a chosen task concrete through timeboxing.

It leaves important GTD discipline to the user: there is no first-class Clarify decision tree, guaranteed project outcome/next-action check, Waiting For list, or guided Weekly Review. Its Calendar also encourages scheduling tasks, whereas strict GTD reserves the calendar for hard landscape commitments. Timeboxing can help users with time blindness, but Citrinium should retain P-09/G-05: a soft next action must not become a false appointment merely because it is visible in planning.

**Design conclusion:** combine Amplenote's context-preserving capture-to-task transition with Citrinium's explicit G-01 Clarify flow, project/next-action safeguards, and guided review rather than assuming scores and tags replace them.

### 5. ADHD relevance and design lessons
These are feature-to-need hypotheses, not clinical evidence that Amplenote treats ADHD. They align with the executive-function challenges and product implications in the ADHD section above:

* **Working memory and friction:** Jots let a thought be written into today's chronological stream before the user decides whether it is a note, task, or project. Keeping a task in the note where it arose avoids retyping context and reduces app-switching; reviewers repeatedly describe the one-app workflow as its main value.
* **Overwhelm and initiation:** Task View turns note-embedded checkboxes into a filtered action list. Task Score uses visible, editable factors such as importance, urgency, start/deadline, duration, blocking, and recent attention to promote a small number of candidates. This can reduce the "where do I start?" decision, but an opaque or overconfident ranking must never replace user judgment, energy, or context.
* **Time blindness:** the calendar exposes tasks beside existing commitments and supports drag-to-timebox planning, fuzzy time options, start times, durations, and reminders via synced calendars. This makes intention more concrete than a floating task list.
* **Trust and non-shaming recovery:** users can unschedule/snooze instead of deleting a task. However, overdue highlighting and a score that rises with age could feel punitive or create red-list anxiety. Citrinium should surface stale work for a conscious keep/schedule/drop decision in supportive language, not escalate it indefinitely (P-04, A-02, A-03, B-06).
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

### 5. What helps: evidence and confidence

The strategies below are not interchangeable, and "helps" does not mean "works for everyone." The strongest conclusion across clinical guidance and research is that adults with ADHD benefit from **external structure tailored to the person's goals and environment**, often alongside professional treatment. A tool should support experimentation and adjustment rather than imply that a single routine, streak, or app can manage ADHD by itself.

#### Externalize memory and planning

Prospective memory means remembering to perform an intention later. A study of adults with ADHD found the largest difference from controls in complex task planning, not simply in remembering or executing a plan once it was well structured. This supports a design emphasis on making the plan concrete before the delay: define the next physical action, when/where it starts, required materials, expected duration, and a cue that will be visible at the right moment.

Useful external supports include:

* One trusted capture location for commitments, ideas, appointments, and follow-ups; loose notes and duplicated lists create retrieval failures.
* A calendar for hard appointments and a task list for flexible work, with an explicit connection between them rather than silently converting every task into a deadline.
* Written instructions, checklists, visual boards, widgets, alarms, and reminders placed where the action occurs. Multiple cues can be appropriate for high-consequence items.
* Event-based cues and habit stacking, such as "after brushing my teeth, take medication," because an event cue is often more concrete than a clock time alone.
* A daily review at predictable transition points, for example on waking, after lunch, and before closing work, to reconnect the person with the system.

#### Make time visible and bounded

Time blindness is not solved by showing a clock in isolation. Helpful systems make time concrete and reduce estimation demands:

* Use a visual timer or countdown, especially for starting, stopping, and transitions.
* Estimate task duration, then add travel, setup, switching, and recovery buffers. A schedule with no transition time is a plan for lateness.
* Put fixed commitments on the calendar first, then choose only a small number of realistic work blocks around them. Keep unscheduled next actions available without implying that every one must fit today.
* Use start and end prompts, not only due-date warnings. A due date says when failure is visible; a start cue helps the person begin.
* Offer fuzzy periods such as morning/afternoon and flexible rescheduling when exact times are not useful. Preserve explicit times for appointments, medication, and safety-critical events.

CHADD recommends choosing a planner that the person will actually use, paper or electronic, and combining appointments with to-do space, brain-dump capture, reminders, and regular review. Its guidance also recommends breaking adoption into manageable steps and using a trusted planner coach when helpful.

#### Reduce activation energy

Task initiation improves when the first step is visible, small, and physically actionable:

* Convert outcomes such as "deal with taxes" into the next action, such as "open the tax folder and find the 2025 statement."
* Break work into steps that can be started in a few minutes, but do not force every task into tiny fragments when that creates administrative work.
* Offer a short start or "just begin" interval, with permission to stop or continue. The goal is initiation, not a punitive timer failure.
* Put materials at the point of use and reduce decisions: default note, default context, suggested next step, saved views, and one-tap resume.
* Use implementation intentions: "If it is 9:00 and I open my laptop, then I will open the project note and write one sentence." ADHD-specific evidence is still developing, but the method directly addresses the intention-to-action gap by pre-deciding the cue and first behavior.

#### Shape the environment instead of demanding willpower

NICE recommends assessing and reviewing environmental modifications. Examples include reducing noise and visual distraction, using headphones, providing written reinforcement for verbal instructions, and using shorter focus periods with movement breaks. Occupational-therapy guidance similarly emphasizes person-environment-occupation fit, designated places for important items, simple filing systems, routines, sensory regulation, and practicing strategies in real activities.

The transferable pattern is **cue visibility plus low search cost**:

* Keep frequently needed items in a consistent launch-pad location.
* Use physical or digital zones for active work, reference, waiting, and archive.
* Reduce notifications and visual clutter during focus, but make important cues more salient rather than hiding everything.
* Make the desired action easier than the distracting alternative, for example by opening the current task directly or placing materials in reach.
* Support movement and sensory needs without assuming one sensory profile. Some people need less input; others need controlled background stimulation.

#### Use social support without surveillance

Many adults report that body doubling, co-working, a check-in partner, or a coach makes starting and sustaining work easier. Possible mechanisms include social facilitation, a scheduled commitment, shared pacing, and gentle accountability. However, direct evidence for body doubling is still limited, and recent HCI work notes that social presence can help some people and distract or discomfort others. It should therefore be opt-in, private, and configurable:

* Let a person invite a trusted partner, join a low-pressure co-working session, or use an ambient presence such as a library/study stream.
* Share a goal and a planned end time, not the user's entire task database.
* Make cameras, status visibility, messages, and accountability intensity optional.
* Avoid leaderboards, public comparison, and language that turns a missed session into a moral failure.

#### Treat stress and recovery as part of productivity

Workplace research links ADHD-related stress with feeling overwhelmed, falling behind, and not staying on top of tasks. An organizational system that only adds obligations can worsen the problem. Helpful approaches include:

* A triage mode that identifies one next action and parks everything else without deleting it.
* A realistic daily capacity limit, such as Top 1/Top 3, with optional stretch items rather than an unbounded "must do" list.
* Planned breaks, meals, movement, sleep routines, and recovery blocks as legitimate schedule items.
* A reset flow after avoidance or absence: capture what changed, choose what still matters, reschedule or drop without shame, and resume with one small action.
* Brief optional check-ins for energy, stress, or sensory load that adapt suggestions but never gate capture or mark a user as failing.

CBT adapted for adult ADHD has evidence for reducing ADHD symptoms, and commonly targets organization, planning, time management, distraction, procrastination, and negative self-beliefs. NICE recommends structured supportive psychological intervention focused on ADHD with regular follow-up when non-pharmacological treatment is indicated. This supports product language that is compassionate and skills-oriented, but an app should not present itself as CBT or a substitute for clinical care.

Regular exercise, adequate sleep, balanced nutrition, and treatment adherence are relevant foundations, but they should not be framed as cures or as proof that someone is trying hard enough. NICE specifically recommends discussing healthy lifestyle and exercise as part of a shared treatment plan. Evidence for exercise, sleep, and mindfulness as ADHD-specific interventions varies by outcome and study quality; they are reasonable optional supports, not universal prescriptions.

### 6. System patterns to support

The most promising system is not a single named method. It is a **small, durable loop** that can borrow from BuJo, GTD, CBT skills training, occupational therapy, and assistive technology:

1. **Capture:** Put every thought somewhere trusted with minimal friction. Do not require project, context, priority, or perfect wording at the moment of capture.
2. **Clarify:** Decide whether the item is actionable, reference, someday, delegated/waiting, calendar-bound, or something to drop. If actionable, name the next physical step.
3. **Choose:** Select a small number of tasks using context, available time, energy, importance, and start cues. Keep a clear difference between hard commitments and flexible work.
4. **Start:** Show one next action, its context, materials, and a short starting option. Make the first interaction obvious.
5. **Resurface:** Use visual, event-based, time-based, location-based, and social cues as the person chooses. A reminder that is easy to dismiss without a recovery path is not enough.
6. **Review and repair:** At the end of a work period, day, or week, review open loops and adjust the system. Carry forward only what still matters, schedule what has a real date, and drop or incubate the rest.
7. **Learn without self-punishment:** Track patterns such as task duration, time of day, environment, energy, and interruption only when that data helps the user make a decision. Do not turn completion counts into a measure of worth.

This loop supports a hybrid user: a BuJo-style chronological log for capture and reflection, GTD-style clarification and next actions, calendar timeboxing for concrete commitments, and optional social or clinical support. Users should be able to use only the capture/review core without adopting every productivity method.

### 7. Product design requirements derived from this research

* **External memory first:** Every commitment should have a durable place, source context, and a way to resurface; never rely on the user remembering to check an invisible backlog.
* **One trusted system, many views:** The same entry may appear in a daily log, task list, project, review, and calendar without duplicate copies or conflicting completion state.
* **Zero-friction capture, deliberate clarify:** Do not burden the moment of capture with organization, but make later clarification easy and explicit.
* **Start cues, not just deadlines:** Support start dates, preparation reminders, duration, transitions, buffers, and event-based cues.
* **Small-focus defaults:** Today/Now should show a manageable subset, with one active task and Top N options; the full backlog remains searchable and reviewable.
* **Adaptive, user-controlled prompting:** Let users set reminder intensity, snooze/reschedule behavior, quiet periods, cue salience, and social support. Do not silently infer high-stakes decisions or flood users with notifications.
* **Environment-aware planning:** Context, location, available tools, energy, sensory load, and time available should be optional inputs to suggestions, not mandatory fields.
* **Recovery is a first-class path:** Missed tasks, skipped reviews, and abandoned plans should lead to a calm reset flow, not broken streaks, red overdue walls, or shame copy.
* **Support routines without rigid repetition:** Recurrence and habit support should allow completion-relative schedules, exceptions, pauses, and restart after absence.
* **Protect privacy and agency:** Social features, mood data, health-related notes, and any AI assistance must be opt-in, explainable, exportable, and never used to rank or shame the user.
* **Measure functioning, not productivity theater:** Useful outcomes include fewer forgotten commitments, lower rescheduling friction, clearer next actions, improved perceived control, and reduced overwhelm, not merely task count or streak length.

### 8. Limitations and safety boundaries

ADHD is heterogeneous. The same reminder can be helpful, irritating, or anxiety-provoking depending on the person, task, sensory environment, and current stress. Tools that work during a stable period may fail during burnout, illness, depression, anxiety, sleep deprivation, or major life changes. The app should invite experimentation, allow easy changes, and avoid diagnosing, prescribing, or claiming that productivity features treat ADHD.

Medication, psychotherapy, coaching, occupational therapy, workplace accommodations, sleep care, and other supports should be discussed with qualified professionals where appropriate. A productivity app can complement those supports by making plans and cues easier to use; it cannot evaluate symptoms, replace treatment, or guarantee safety-critical adherence.

### 9. Sources & Citations
*   Barkley, R. A. — ADHD as impairment of executive function / "doing what you know"; present-moment bias and weak future orientation (foundational clinical framing of time and self-regulation).
*   Kofler, M. J., et al. (2020). *Working memory and short-term memory deficits in ADHD: A bifactor modeling approach.* Neuropsychology. Large working-memory impairments relative to short-term memory; supports external memory aids. https://pmc.ncbi.nlm.nih.gov/articles/PMC7483636/
*   Kofler, M. J., et al. (2024). Executive function deficits in ADHD (review/meta context). https://pmc.ncbi.nlm.nih.gov/articles/PMC11485171
*   Sonuga-Barke, E., et al. (2010 area) — temporal/delay discounting: immediate rewards outweigh distant ones; informs gamification and "make the next step rewarding now."
*   Carroll, R. (2018). *The Bullet Journal Method.* Portfolio/Penguin. BuJo created from Carroll's own ADHD; rapid logging, migration, intentional review. https://bulletjournal.com/pages/rydercarroll
*   Mueller, P. A., & Oppenheimer, D. M. (2014). *The pen is mightier than the keyboard.* Psychological Science. Handwriting can improve encoding/processing vs. verbatim typing (often cited for analog capture benefits).
*   Chen, J., Meng, Y., & Nie, K. (2026). *"Not Just Me and My To-Do List": Understanding Challenges of Task Management for Adults with ADHD and the Need for AI-Augmented Social Scaffolds.* arXiv:2603.17258. Twenty-two interviews and a follow-up speed-dating study with twenty ADHD-identifying adults found task management to be emotional and relational as well as cognitive; design implications include co-regulation, adaptive routines, and user-controlled support. This is emerging preprint research, not clinical efficacy evidence. https://arxiv.org/abs/2603.17258
*   Simply Psychology — ADHD & time blindness overview (Barkley-linked "now vs not now"). https://www.simplypsychology.org/adhd-time-blindness.html
*   Ly, A. (2024). *Time Unbound – Managing Time Blindness at Work.* Neurodiversity-affirming strategies (adapt/adjust/ask/accommodate).
*   NICE. *Attention deficit hyperactivity disorder: diagnosis and management* (NG87; recommendations updated 2019). Environmental modifications, structured ADHD-focused psychological support, healthy lifestyle, exercise, written/visual reminders, and adherence support. https://www.nice.org.uk/guidance/ng87/chapter/recommendations
*   Young, Z., Moghaddam, N., & Tickle, A. (2020). *The Efficacy of Cognitive Behavioral Therapy for Adults With ADHD: A Systematic Review and Meta-Analysis of Randomized Controlled Trials.* Journal of Attention Disorders. CBT showed benefit over waitlist and active controls, with limitations and a small evidence base. https://pubmed.ncbi.nlm.nih.gov/27554190/
*   Adamou, M., et al. (2021). *Recommendations for occupational therapy interventions for adults with ADHD: a consensus statement from the UK adult ADHD network.* BMC Psychiatry. Person-environment fit, routines, organization, time management, task breakdown, sensory regulation, and stress management; consensus and practice guidance, not a definitive efficacy trial. https://pmc.ncbi.nlm.nih.gov/articles/PMC7863422/
*   Fuermaier, A. B. M., et al. (2013). *Complex Prospective Memory in Adults with Attention Deficit Hyperactivity Disorder.* PLOS ONE. Adults with ADHD showed a substantial planning difficulty in a complex delayed-intention task, supporting careful planning and external help. https://doi.org/10.1371/journal.pone.0058338
*   Holmefur, M., et al. (2026). *Effectiveness of a group-based time-management intervention: a pragmatic randomised controlled trial.* Journal of Mental Health. Let’s Get Organised and individual occupational therapy improved perceived time-management skills; the study included adults with ADHD, autism, or other mental disorders and should not be generalized to ADHD alone without caution. https://doi.org/10.1080/09638288.2026.2614218
*   Hwang, S., et al. (2022). *Stress and work-related mental illness among working adults with ADHD: a qualitative study.* BMC Psychiatry. Overwhelm, falling behind, inadequate structure, and workplace support were prominent themes. https://doi.org/10.1186/s12888-022-04409-w
*   Ara, Z., et al. (2025). *You Are Not Alone: Designing Body Doubling for ADHD in Virtual Reality.* Emerging HCI research; direct evidence for body doubling remains limited and preferences vary. https://arxiv.org/abs/2509.12153
*   Kim, H.-H., & Jung, N.-H. (2025). *Mindfulness-based interventions for adults with ADHD: A systematic review and meta-analysis.* Medicine. Evidence was inconsistent and heterogeneous, so mindfulness is an optional support rather than a guaranteed treatment. https://pubmed.ncbi.nlm.nih.gov/40958241/
*   CHADD National Resource Center on ADHD. *Time Management and ADHD: Day Planners* and *Time Management and ADHD: To-Do Lists.* Practical guidance on choosing a planner, brain dumps, reminders, review, and manageable adoption steps. https://chadd.org/for-adults/time-management-planner/ and https://chadd.org/for-adults/time-management-and-adhd-to-do-lists/

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
