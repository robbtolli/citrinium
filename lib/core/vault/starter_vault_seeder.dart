import 'dart:io';

import 'package:citrine_core/citrine_core.dart';
import 'package:path/path.dart' as p;

/// Seeds rich, realistic, non-filler starter content and practical guides
/// into a Citrine vault (`A-06`, `P-07`, `P-11`).
///
/// Designed to teach users by doing:
/// - Tasks can be edited in-place (`D-19`), checked off, or sprinted (`E-05`).
/// - Real GTD project and BuJo collection templates (`G-03`, `B-10`).
/// - Pre-seeded inbox items to try out 1-click Clarify (`G-01`).
/// - Never overwrites files that already exist on disk.
class StarterVaultSeeder {
  const StarterVaultSeeder._();

  /// Populates a new or starter vault with interactive learning data.
  ///
  /// Returns the `uniqueKey` (`relPath:lineIndex`) of the primary tutorial task
  /// in `daily/YYYY-MM-DD.md` so it can be pre-pinned to Today's Top-3 Focus Shelf.
  static Future<String?> seedStarterVault(
    String vaultPath, {
    DateTime? now,
  }) async {
    final currentNow = now ?? DateTime.now();
    final todayIso = NlDateParser.formatIsoDate(currentNow);
    final dailyRel = CadenceFiles.dailyRelPath(currentNow);
    final weeklyRel = CadenceFiles.weeklyRelPath(currentNow);

    // 1. Guides and Reference (always seeded if missing)
    await seedGuidesOnly(vaultPath);

    // 2. Today's Daily Log (with hands-on tutorial tasks & habit)
    final dailyFile = File(p.join(vaultPath, dailyRel));
    String? tutorialTaskKey;
    if (!await dailyFile.exists()) {
      await dailyFile.parent.create(recursive: true);
      final weekdayName = _weekdayName(currentNow.weekday);
      final monthName = _monthName(currentNow.month);
      final dailyContent = '''---
citrine.type: daily
date: $todayIso
---

# Daily Log · $weekdayName, $monthName ${currentNow.day}, ${currentNow.year}

## Hard Landscape (Events)
- ○ Welcome to Citrine — Hard-landscape events use "- ○" and appear on your Calendar 📅 $todayIso ⏰ 09:00

## Focus & Tasks
- [ ] Tap this task to edit it in-place, try the ⏱️ 2m Focus Sprint, or check it off @computer 📅 $todayIso
  - Citrine supports 100% in-place editing! Tap the row to expand inline controls without jumping to source files.
  - Notice the [📄 source ↗] badge on the right: you can peek at surrounding context anytime.
- [ ] Type "Review notes tomorrow at 10am @computer" in the Quick Capture bar below and tap the 📅 chip
  - Natural language dates parse offline instantly. The sticky [ Inbox | Today ] toggle controls where thoughts land.
- [ ] Drink a glass of water & stretch #habit 🔁 daily 📅 $todayIso
  - Non-punitive habits! When completed, Citrine records your progress in operational storage without duplicating lines in Markdown.

## Notes & Discoveries
- Bullet Journal and Getting Things Done work together seamlessly in Citrine.
- Read [[guides/getting-started]] to learn the 5-minute capture → clarify → focus → migrate loop.
''';
      await dailyFile.writeAsString(dailyContent);

      // Locate the line index of the tutorial task
      final lines = dailyContent.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('Tap this task to edit it in-place')) {
          tutorialTaskKey = '$dailyRel:$i';
          break;
        }
      }
    }

    // 3. Inbox with 3 unclarified items to practice GTD Clarify
    final inboxFile = File(p.join(vaultPath, 'inbox.md'));
    if (!await inboxFile.exists()) {
      await inboxFile.writeAsString('''---
citrine.type: inbox
---

# Quick Capture Inbox

- [ ] Save the Citrine Markdown & Symbol Cheat Sheet for quick lookup
  - Practice GTD Clarify: tap "Actions & Inbox", then tap "Clarify (3)". For reference material, choose "📚 File to Reference".
- [ ] Plan a weekend day trip or creative side project
  - In Clarify, route this to "🌱 Someday / Maybe" so it stays safe without cluttering your daily view.
- [ ] Waiting on feedback or a package delivery
  - In Clarify, route this to "⏳ Waiting For" and assign a person/system plus follow-up date.
''');
    }

    // 4. GTD Project with explicit outcome and next actions
    final projectFile = File(
      p.join(vaultPath, 'projects', 'setup-personal-workflow.md'),
    );
    if (!await projectFile.exists()) {
      await projectFile.parent.create(recursive: true);
      await projectFile.writeAsString('''---
citrine.type: project
title: Setup Personal Workflow in Citrine
outcome: Have a calm, trusted place for my daily tasks and notes
status: active
---

# Project: Setup Personal Workflow in Citrine

**Desired Outcome:** Have a calm, trusted place for my daily tasks and notes

In GTD, a project is any desired outcome requiring more than one action step. Every project needs an explicit outcome and at least one open Next Action (otherwise Citrine flags it as a "Zombie Project").

## Next Actions
- [ ] Customize planning & review cadences in Settings (B-12) @computer
  - Turn Daily, Weekly, Monthly, or Future Log on or off according to how you like to plan.
- [ ] Explore the 4-step Weekly Review in Horizons & Review @home
- [x] Create my first Citrine vault
''');
    }

    // 5. Weekly Log
    final weeklyFile = File(p.join(vaultPath, weeklyRel));
    if (!await weeklyFile.exists()) {
      await weeklyFile.parent.create(recursive: true);
      final weekId = weeklyRel.replaceAll('weekly/', '').replaceAll('.md', '');
      await weeklyFile.writeAsString('''---
citrine.type: weekly
week: $weekId
---

# Weekly Log · $weekId

## Desired Weekly Outcomes
- [ ] Complete onboarding walkthrough and establish a 5-minute daily capture routine @computer
- [ ] Organize reading list in [[collections/books-media-and-ideas]] @home

## Week Notes & Reflections
- Cadence logs thread automatically with your daily and monthly horizons.
- Customize templates anytime in Settings -> Customize Cadence Templates.
''');
    }

    // 6. Future Log
    final futureFile = File(p.join(vaultPath, 'future.md'));
    if (!await futureFile.exists()) {
      await futureFile.writeAsString('''---
citrine.type: future
---

# Future Log

The Future Log holds commitments, aspirations, and events slated for months ahead.

## Upcoming Horizons
- [ ] Seasonal goals & workflow reflection 📅 ${currentNow.year}-12-01
- [ ] Annual review and vision planning 📅 ${currentNow.year}-12-31
''');
    }

    // 7. BuJo Collection
    final collectionFile = File(
      p.join(vaultPath, 'collections', 'books-media-and-ideas.md'),
    );
    if (!await collectionFile.exists()) {
      await collectionFile.parent.create(recursive: true);
      await collectionFile.writeAsString('''---
citrine.type: collection
title: Books, Media & Ideas
tags: [reading, collection, bujo]
---

# Collection: Books, Media & Ideas

Collections are themed lists and notes that live alongside your logs without requiring nested folder trees.

## Books to Read
- [ ] *Getting Things Done* by David Allen
- [ ] *The Bullet Journal Method* by Ryder Carroll
- [ ] *Atomic Habits* by James Clear

## Creative Ideas & Sparks
- Try combining a 2-minute focus sprint with a Top-3 Focus Shelf pin when feeling stuck.
- Create on-demand collections from any note by typing `[[collections/your-topic]]`.
''');
    }

    return tutorialTaskKey;
  }

  /// Writes only the starter guide notes and reference cheat sheet into
  /// [vaultPath] (`guides/` and `reference.md`). Does not create or overwrite
  /// logs, projects, or user notes.
  static Future<void> seedGuidesOnly(String vaultPath) async {
    final guidesDir = Directory(p.join(vaultPath, 'guides'));
    if (!await guidesDir.exists()) {
      await guidesDir.create(recursive: true);
    }

    final gettingStarted = File(p.join(guidesDir.path, 'getting-started.md'));
    if (!await gettingStarted.exists()) {
      await gettingStarted.writeAsString('''---
citrine.type: note
title: Getting Started with Citrine
tags: [guide, onboarding]
---

# Getting Started with Citrine

Welcome to Citrine! This guide walks you through the 4 core pillars and the 5-minute daily loop.

## The 4 Pillars
1. **☀️ Today**: Your daily command center. A collapsible Top-3 Focus Shelf + today's rapid-log note.
2. **✅ Actions & Inbox**: Instant capture, 1-card-at-a-time GTD Clarify deck, and context-filtered Next Actions.
3. **🧭 Horizons & Review**: Configurable planning logs (Daily, Weekly, Monthly, Future Log) and guided reviews.
4. **📓 Notes & Index**: Plain Markdown notes, on-demand Collections, Reference material, and wiki links.

## The 5-Minute Daily Loop
1. **Morning Focus (1 min):** Open Today. Review your hard-landscape events and pin up to 3 priority tasks to the Top-3 Focus Shelf.
2. **Capture Freely (During the Day):** Whenever a thought strikes, use the Quick Capture bar. Send it to Inbox or Today with the sticky toggle.
3. **Clarify (1 min):** When you have a moment, open Actions & Inbox and tap **Clarify**. Decide in 1 click whether an item is an immediate action, a project, reference, or someday.
4. **Evening Migration (2 mins):** Tap **Daily Migration** on Today. Keep what matters, schedule what's future, and drop what's no longer relevant without guilt.

## Related Guides
- [[guides/bujo-and-gtd-guide|How BuJo and GTD Work Together]]
- [[guides/markdown-cheatsheet|Markdown & Token Cheat Sheet]]
- [[reference|Quick Reference & Syntax Guide]]
''');
    }

    final bujoGtd = File(p.join(guidesDir.path, 'bujo-and-gtd-guide.md'));
    if (!await bujoGtd.exists()) {
      await bujoGtd.writeAsString('''---
citrine.type: note
title: How Bullet Journal and GTD Work Together in Citrine
tags: [guide, bujo, gtd]
---

# How Bullet Journal and GTD Work Together in Citrine

Citrine bridges the chronological flow of **Bullet Journal (BuJo)** with the actionable clarity of **Getting Things Done (GTD)**.

## Why Both?
- **Bullet Journal** excels at rapid logging thoughts as they happen in a timeline (`daily/`, `weekly/`, `monthly/`) and intentional migration.
- **GTD** excels at taking vague open loops, clarifying the next physical action, and filtering by `@context` (so you only see what you can do *here and now*).

## How They Connect in Citrine
- Rapid-log tasks inline anywhere in your daily note.
- Add an `@context` (e.g. `@computer` or `@errands`) to make them show up in Next Actions.
- When an item needs multiple steps, promote it to a Project with an explicit Outcome.
- At the end of the day or week, the Migration ritual ensures nothing falls through the cracks or lingers forever without your deliberate choice.
''');
    }

    final cheatsheet = File(p.join(guidesDir.path, 'markdown-cheatsheet.md'));
    if (!await cheatsheet.exists()) {
      await cheatsheet.writeAsString('''---
citrine.type: note
title: Plain-Text Markdown & Live Preview Guide
tags: [guide, markdown]
---

# Plain-Text Markdown & Live Preview Guide

Citrine is built directly on plain text. There is no proprietary database locking up your notes.

## Live Preview Editor
- As you type standard Markdown, formatting (bold, italic, headings, lists, checkboxes) is rendered in-place while keeping your cursor exact.
- Clicking on a `[[wikilink]]` jumps directly to that note or creates it if it doesn't exist yet.

## In-Place Task Editing
- When looking at tasks in any aggregated list or review, you can edit them directly in-place.
- Citrine rewrites the source `.md` file safely in the background while preserving whitespace, frontmatter, and comments.
''');
    }

    final reference = File(p.join(vaultPath, 'reference.md'));
    if (!await reference.exists()) {
      await reference.writeAsString('''---
citrine.type: reference
title: Citrine Quick Reference & Syntax Guide
---

# Citrine Quick Reference & Syntax Guide

Citrine uses standard Markdown and keeps your notes 100% human-readable and compatible with Obsidian, VS Code, and any plain-text tool.

## Rapid-Logging Symbols
- `- [ ]` Open Task
- `- [/]` In-Progress Task (half-filled checkbox)
- `- [x]` Completed Task
- `- [-]` Cancelled Task (strikethrough & greyed checkbox)
- `- [?]` Waiting For / Blocked Task
- `- ○` Hard-Landscape Event (exact time commitment)
- `- –` Note or discovery

## Inline Metadata Tokens
- `📅 YYYY-MM-DD` Due Date (or calendar date)
- `⏰ HH:MM` Due Time
- `🔁 <rule>` Recurrence (`🔁 daily`, `🔁 every weekday`, `🔁 every week`, `🔁 every month`)
- `#habit` Tags a recurring task for non-punitive rhythm tracking
- `@context` GTD Action Context (e.g. `@computer`, `@home`, `@errands`, `@phone`)
- `#tag` Categorical tag
- `[[wikilink]]` Inter-note wiki link (supports `[[target|display text]]`)
''');
    }
  }

  static String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  static String _monthName(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return '';
    }
  }
}
