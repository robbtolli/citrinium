# Citrinium File Schema (FR-04)

> **Status: DRAFT.** Written against `packages/citrinium_core`'s M0 parser/vault
> implementation (W1/W2/W3) and `design.md` §3. Frozen at M12 (`milestones.md`), per
> the "1.0 Release Readiness" milestone. Until then, this document changes whenever
> the parser's grammar does — `citrinium_core`'s `currentParserVersion`
> (`lib/src/parser/parser_version.dart`) is bumped alongside any change here that
> could alter how an existing file parses.

Parent: [`design.md`](../design.md) §3 (Vault & file schema), [`milestones.md`](../milestones.md),
[`docs/milestones/m0.md`](milestones/m0.md) W5.

## 0. Why this document exists

Per P-11/D-15, the vault is a folder of plain-text Markdown files, and the app is a
view/editor over those files — not a database with an export feature bolted on. That
claim is only as real as this document: everything below is what actually makes a
Citrinium vault readable, editable, and re-derivable by any other tool (a text editor,
Obsidian, a script), not just by Citrinium itself.

This is a **grammar/schema reference**, not a tutorial. It documents what
`packages/citrinium_core`'s parser (`lib/src/parser/`) and vault layer
(`lib/src/vault/`) actually implement, plus the handful of conventions those layers
assume but don't themselves enforce (file/folder placement, frontmatter field names).
Where the current implementation is silent or provisional, that's called out
explicitly in §9 rather than papered over.

## 1. Encoding, line endings, and whitespace

- Files are UTF-8 text, with or without a leading BOM. Both are round-tripped exactly
  as found: a file with a BOM keeps its BOM on every write; a file without one never
  gains one (`vault_file_io.dart`'s `VaultFileContents.hadBom`).
- Line endings (`\n`, `\r\n`, `\r`, or a mix of these within one file) are preserved
  verbatim, per line, forever. Citrinium does not normalize a `CRLF` file to `LF` (or
  vice versa) on save, and does not "fix" a file with mixed line endings — that's a
  human/tool decision, not the app's to make silently.
- Trailing-newline presence (or absence) at end-of-file is preserved.
- Tabs and spaces are both accepted as list-bullet indentation and as the whitespace
  between a bullet and its marker/content; whichever the file already uses is kept.
- All offsets — everywhere in the parser, and everywhere a splice/edit is described —
  are **Dart `String` UTF-16 code-unit offsets**, never byte offsets and never
  Unicode-rune counts. This matters concretely for inline metadata markers (`📅⏰🔁`),
  which are outside the Basic Multilingual Plane and are therefore surrogate pairs (2
  code units each).
- File/folder path segments are Unicode-normalized to NFC for comparison purposes
  (`path_normalization.dart`'s `VaultPath`) — macOS/APFS hands back NFD names from
  directory listings even for files created with NFC names, and without normalizing at
  this boundary a `[[wikilink]]` written in NFC would silently fail to resolve against
  a scanned NFD filename. **The bytes on disk are never rewritten to enforce this** —
  only the in-memory comparison key is normalized.

## 2. File & folder conventions

- **Extension:** only `.md` files are recognized as vault content
  (`ignore_rules.dart`'s `isMarkdownFileName`). Anything else in the vault directory is
  invisible to the scanner/watcher/index.
- **Ignored paths**, pruned entirely from scanning/watching/indexing
  (`ignore_rules.dart`'s `defaultIgnoredDirNames` + generic dotfile rule):
  - `.git/`, `.obsidian/`, `.citrinium/`, `.trash/`, `node_modules/`
  - Any file or directory whose name starts with `.` (so `.DS_Store`, `.hidden.md`,
    `.anything/`, etc. are all invisible too)
- **`.citrinium/`** is reserved for future app-level vault configuration (per
  `docs/milestones/m0.md`'s "Vault config" decision: portable, travels with the vault,
  excluded from scan/index). **Nothing is written there yet as of M0** — this is a
  reserved namespace, not an active feature.
- **Symlinks** to `.md` files are not followed by default (a size/cycle-safety
  default); `VaultScanner(options: VaultScanOptions(followSymlinks: true))` opts in.
- **File size cap:** files over 10MB are excluded from scanning/indexing by default
  (`VaultScanOptions.maxFileSizeBytes`) rather than loaded fully into memory.
- **Folder structure is otherwise unconstrained.** Nothing in the parser or index
  requires a particular directory layout — a flat vault and a deeply-nested one are
  equally valid. Specific conventions for particular content types (daily logs,
  inbox, projects) are introduced by name below where they're locked, and left as
  explicit open questions in §9 where they're not yet decided.
- **Daily/Monthly/Future Log naming** (`design.md` §3.4 gives `daily/2026-07-30.md` as
  an example) and **`inbox.md`'s location** are **not yet locked** — they're M1 W3
  work (see `docs/milestones/m1.md`). This draft will be updated then; don't treat the
  example path in `design.md` as final.

## 3. Frontmatter

Recognized **only** as a `---`-delimited block at byte offset 0 of the file
(`frontmatter.dart`). A `---` block anywhere else in the file is just a thematic break
or table-adjacent text, not frontmatter — this matches CommonMark/Obsidian convention.

- Parsed as YAML (`package:yaml`). A frontmatter block that fails to parse as YAML, or
  that parses to something other than a mapping, is still recognized structurally (its
  span round-trips correctly) but offers no structured field access — a syntax error
  in your frontmatter never corrupts the rest of the file or blocks parsing.
- Edited surgically via `package:yaml_edit`'s `YamlEditor` against the *raw YAML
  substring*, never by re-serializing a parsed structure — untouched keys, comments,
  quoting style, and key order elsewhere in the block survive every edit
  (`MarkdownDocument.setFrontmatterValue`/`removeFrontmatterValue`).
- **Citrinium-specific fields are namespaced under a top-level `citrinium:` map**, so
  the file stays meaningful to any other Markdown/frontmatter-aware tool that ignores
  unknown keys:

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

- **`citrinium.type`** is how the index (`documents.docType`, W3) classifies a file.
  Recognized/planned values (only `note` and `project` are meaningfully exercised as
  of M0 — the rest are named here so future milestones don't need to invent the field
  again):

  | Value | Meaning | Milestone |
  | --- | --- | --- |
  | *(absent)* | Defaults to `note` | M0 |
  | `note` | A plain note | M0 |
  | `project` | A GTD/BuJo project (D-03) | M2 |
  | `collection` | A BuJo collection (D-10) | M2 |
  | `dailyLog` / `monthlyLog` / `futureLog` | Log surfaces (D-11) | M1/M3/M4 |
  | `areaOfFocus` | GTD Horizon 2 (D-13) | M2+ |

  Unrecognized `citrinium.type` values are stored and indexed as-is (`docType` is a
  free-text column, not an enum at the SQL layer) rather than rejected — forward
  compatibility with a future type the current app version doesn't know about yet is
  more important than validation.
- **Top-level `title:`** (outside the `citrinium:` namespace, i.e. plain frontmatter
  YAML that any static-site generator or Obsidian itself would also recognize) is used
  as `documents.title` in the index if present, ahead of falling back to the first `#`
  heading line, then an empty string (see `document_indexer.dart`'s `_title`). An
  empty index title is itself a UI-layer concern, not the index's: the document-list
  screen (W4) falls back further to the file's relative path for display, but that
  fallback isn't baked into the index row itself.
- Frontmatter is **not required**. A file with no frontmatter block at all is exactly
  as valid as one with an empty `---\n---\n` block or a fully-populated one.

## 4. Task states (D-02)

Tasks are `- `/`* `/`+ ` bullet lines with a `[x]`-style checkbox
(`markdown_parser.dart`'s task regex), matching `design.md` §3.1 exactly:

| Marker | State | `TaskStateKind` |
| --- | --- | --- |
| `- [ ]` | open | `open` |
| `- [/]` | in-progress | `inProgress` |
| `- [x]` or `- [X]` | completed | `completed` |
| `- [>]` | migrated | `migrated` |
| `- [<]` | scheduled | `scheduled` |
| `- [-]` | dropped/canceled | `dropped` |
| `- [w]` or `- [W]` | waiting-for (Citrinium extension) | `waitingFor` |
| any other single character | preserved verbatim, **not** normalized | `unknown` |

Notes:

- The bullet character itself (`-`, `*`, or `+`) is preserved as written; Citrinium
  never rewrites `*` bullets to `-` or vice versa.
- **The marker character between `[` and `]` must be exactly one character.**
  Multi-character or empty bracket contents (`- []`, `- [ab]`) don't match the task
  grammar at all and fall back to being classified as `listItem`/`text`.
- **Unknown marker characters are preserved verbatim, never normalized away.** This is
  deliberate, not a gap: a vault edited by a third-party tool with its own custom
  checkbox statuses (e.g. Obsidian's Tasks plugin, which supports arbitrary custom
  status characters) must round-trip through Citrinium without losing that
  information, even though Citrinium doesn't understand what the custom character
  means. The index stores these as `"unknown:<char>"` in `entries.taskState`
  (`document_indexer.dart`) rather than discarding the character.
- `[w]`/`[W]` (waiting-for) is a **Citrinium extension** to the standard
  Obsidian-Tasks-plugin-compatible set — it's still a syntactically valid checkbox
  line for any generic Markdown or Obsidian reader (it just renders as an unchecked
  box with a stray letter to a tool that doesn't know about it), and is configurable
  as a custom status string in the Obsidian Tasks plugin if a user wants visual parity
  there.
- `setTaskState`/`setTaskMarkerChar` (`markdown_document.dart`) only ever splice the
  single marker character — a task-state change is provably a one-character edit to
  the file, satisfying exit criterion #3 ("a single-line edit ... provably alters only
  the expected byte range").

## 5. BuJo event/note signifiers

Rapid-log lines that are a bullet followed by a signifier character (not a checkbox)
rather than free text (`design.md` §3.2, `bujo.dart`):

| Signifier | Meaning | `BujoKind` |
| --- | --- | --- |
| `○` (U+25CB WHITE CIRCLE) | Event — a dated/timed happening, not a task | `event` |
| `–` (U+2013 EN DASH) | Note — a free-form observation/idea, not a task | `note` |

```
- ○ Dentist appointment 📅 2026-08-03 15:00
- – Idea: batch prescription refills quarterly
```

A bullet line that's neither a task nor one of these two signifiers is a **plain
bullet** (`LineKind.listItem`) — the "untyped" entry kind in the index (D-01's
task/event/note/*untyped* unified entry). This is the rapid-log line for something the
user hasn't classified yet (BuJo's plain `•`/`-` bullet, GTD's raw inbox capture)
without requiring the app to invent a marker for "nothing decided yet."

This is a deliberately small, literal set, not a guessed-at superset — `design.md`
gives these two signifiers as examples, and this M0 draft only locks down exactly
what's implemented. See §9 for what's still open (priority/inspiration signifiers,
B-08).

## 6. Inline metadata

Rapid-log lines (tasks, BuJo events/notes, and plain bullets alike) carry metadata
inline rather than in separate fields, per C-03/C-04 and `design.md` §3.2:

```
- [ ] Call pharmacy about refill 📅 2026-08-01 ⏰17:00 @phone #waiting-for/dr-lee ^t7f3a2b
```

| Marker | Kind | Grammar | Example |
| --- | --- | --- | --- |
| `📅` | `date` | `📅` + optional space/tab + `YYYY-MM-DD` | `📅 2026-08-01` |
| `⏰` | `time` | `⏰` + optional space/tab + `H:MM` or `HH:MM` | `⏰17:00`, `⏰ 9:05` |
| `🔁` | `recurrence` | `🔁` + optional space/tab + free text, extending until the next metadata marker preceded by whitespace, or end of line | `🔁 every weekday` |
| `@context` | `context` | `@` + one or more of `[A-Za-z0-9_-/]` | `@phone`, `@waiting-for` |
| `#tag` | `tag` | `#` + one or more of `[A-Za-z0-9_-/]` (Obsidian-style nested tags via `/`) | `#groceries`, `#waiting-for/dr-lee` |
| `^blockid` | `blockId` | `^` + one or more of `[A-Za-z0-9-]` | `^t7f3a2b` |

Notes on the grammar as actually implemented (`inline_metadata.dart`):

- **Multiple occurrences per line are allowed** for every kind. `allMetadata`/
  `line.metadata` returns every match, in left-to-right document order. The *edit* API
  (`upsertInlineField`) treats `date`/`time`/`recurrence`/`blockId` as singleton
  fields (replacing the first match), and `context`/`tag` as multi-valued (idempotent
  append — adding an already-present exact value is a no-op).
- **`🔁` recurrence values are unbounded free text** (there's no fixed grammar for
  "every 1st Monday" the way there is for a date), so its value is scanned forward
  from the marker until the next occurrence of another metadata marker character that
  is itself preceded by whitespace, or end of line. A recurrence description that
  happens to contain, say, a bare `#` with no space before it is *not* treated as a
  tag-boundary (only a *whitespace-preceded* marker char terminates the scan) — this
  is the one piece of the grammar with a "look at the neighboring character" rule
  rather than a self-contained regex.
- **Block IDs are conventionally last on the line** — `upsertInlineField`'s append
  behavior inserts new metadata *before* an existing block ID rather than after it, so
  `^blockid` stays anchored at the end as new fields accumulate. This is convention
  enforced by the edit API, not something the parser rejects if violated by hand-edited
  content — a block ID in the middle of a line still parses correctly, it's just not
  what Citrinium itself will produce.
- **No escaping mechanism exists yet.** There is currently no way to write a literal
  `#`, `@`, `📅`, etc. in rapid-log body text without it being parsed as metadata (e.g.
  "call about the #1 issue" *will* extract `#1` as a tag). This is a known gap, not a
  design decision — see §9.
- **Precedence between wikilinks and inline metadata:** wikilink spans
  (`[[...]]`/`![[...]]`) are extracted *first* and excluded from inline-metadata
  matching, so `[[Note#heading]]`'s `#heading` is never misparsed as a `#tag`, and
  `[[user@example.com]]`-style targets (if anyone writes one) won't spawn a spurious
  `@context`. This is the one documented precedence rule as of M0; see §9 for the
  general "what wins when two markers overlap" question, which doesn't yet arise
  beyond this wikilink case.
- **Metadata inside a code span or fenced/indented code block is never extracted** —
  see §7.

## 7. Code awareness

Fenced (` ``` `/`~~~`) and indented code blocks are recognized structurally
(`code_blocks.dart`) before task/BuJo/heading/inline-metadata/wikilink classification
runs, and are excluded from all of it:

- A `- [ ]` inside a fence is literal text, never a task.
- A `[[wikilink]]`-shaped string inside a fence never becomes a link.
- `📅`/`@`/`#`/etc. inside a fence are never extracted as metadata.
- Fence delimiter lines themselves (` ``` ` / `~~~`, opening or closing) are their own
  line kind (`codeFenceDelimiter`), distinct from the code content between them.

This is treated as a data-integrity bug class, not a cosmetic one (per
`docs/milestones/m0.md`'s risk table): a false positive here would mean Citrinium
silently reinterprets someone's code sample as task/link data.

## 8. Wikilinks & embeds (N-02)

Obsidian-compatible forms (`wikilink.dart`), extracted with byte-accurate spans for
every component:

| Form | Meaning |
| --- | --- |
| `[[target]]` | Link to `target` |
| `[[target\|alias]]` | Link to `target`, displayed as `alias` |
| `[[target#heading]]` | Link to a specific heading within `target` |
| `[[target#heading\|alias]]` | Both of the above combined |
| `![[target]]` | Embed of `target` (image, another note, etc.) rather than a navigable link |

- Targets **cannot contain `[` or `]`** (matches Obsidian's own documented
  restriction) — `[[a[b]]` does not parse as a wikilink.
- `|alias` is split off before `#heading` is looked for within the remaining target
  portion, so a `|` inside what would otherwise look like a heading fragment is
  unambiguous: `[[Note#a|b]]` means target=`Note`, heading=`a`, alias=`b`, not
  target=`Note#a|b`.
- **Link resolution** (mapping a `target` string to an actual `documents` row) is an
  **index-layer (W3) concern, not a parser concern** — the parser only extracts the
  literal target string. `IndexService`'s resolution (`index_operations.dart`) tries,
  in order: (1) exact relative path match (with or without a `.md` suffix, so
  `[[Projects/Citrinium]]` matches `Projects/Citrinium.md`), then (2) a case-insensitive
  match on a *unique* filename anywhere in the vault (Obsidian-style shortest-path
  linking). A link that matches zero or more-than-one candidate is left unresolved
  (`links.targetDocumentId = NULL`) — this is expected, not an error: a link to a note
  that doesn't exist yet, or an intentionally ambiguous short name, are both valid
  vault states. Resolution is retried on every index rebuild/incremental update, so a
  previously-dangling link resolves automatically once its target is created.

## 9. Open questions (explicitly unresolved as of M0)

These are acknowledged gaps this draft doesn't paper over, each tied to the milestone
expected to resolve it:

1. **Inbox/Daily/Monthly/Future Log file locations and naming.** `design.md` §3.4's
   `daily/2026-07-30.md` is an example, not a locked convention. → M1 W3
   (`docs/milestones/m1.md`).
2. **No escaping mechanism for inline metadata markers.** There's currently no way to
   write a literal `#`/`@`/`📅`/etc. in body text without it being parsed as metadata.
   → unscheduled; needs a decision (backslash-escape? require whitespace boundaries
   more strictly? both?) before it's a real gap for users writing prose that happens
   to contain `#1`, `user@host`, etc.
3. **BuJo priority/inspiration signifiers (B-08)** — `design.md` §3.2 doesn't specify
   these beyond event/note, and the parser's `entries.signifier` index column exists
   but is never populated as of M0. → filtering deferred to M9 per `milestones.md`;
   the signifier *grammar* itself isn't scheduled yet.
4. **Recurrence rule grammar (D-16).** `🔁` is currently captured as an opaque free-text
   string (`entries.recurrenceRaw`) with no structured parsing into a rule (daily/
   weekly/custom interval/etc). → M7.
5. **Natural-language date/time phrases (C-04).** Only the explicit `📅`/`⏰` marker
   grammar above is parsed as of M0; free text like "tomorrow 5pm" is not yet
   recognized, and the precedence between an existing explicit `📅` and a newly-typed
   NL phrase on the same line is undecided. → M1 W2.
6. **Attachments/embedded non-Markdown files (N-06).** `![[embed]]` is parsed as a
   link-layer construct, but there's no convention yet for *where* attached
   images/files live relative to the note that embeds them (Obsidian-style
   `attachments/` folder? co-located? configurable?). → unscheduled.
7. **Multi-vault (FR-10).** Nothing here assumes single-vault, but nothing has been
   designed for disambiguating identical relative paths across vaults either, since
   FR-10 is post-1.0 scope.
