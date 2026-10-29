import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/index/index_providers.dart';
import '../../core/workspace/workspace_state.dart';
import '../../shared/widgets/embedded_markdown_editor.dart';
import '../../shared/widgets/in_place_task_tile.dart';

enum ActionsSubTab {
  inbox('Inbox'),
  nextActions('Next Actions'),
  calendar('Calendar'),
  projects('Projects'),
  waiting('Waiting For'),
  someday('Someday');

  const ActionsSubTab(this.label);
  final String label;
}

/// Pillar 2 of the Hybrid Dual-Track UX (`design.md` §6.2):
/// GTD Inbox & Clarify Deck (`G-01`), Context-filterable Next Actions / Engage
/// (`E-01`, `G-04`), Projects with Zombie-Project Detection (`D-03`, `D-04`,
/// `G-03`), Waiting For (`D-06`), and Someday/Maybe (`D-05`).
///
/// Every task in every tab is editable 100% in-place (`D-19`) without
/// navigating away to the containing note.
class ActionsInboxScreen extends ConsumerStatefulWidget {
  const ActionsInboxScreen({super.key});

  @override
  ConsumerState<ActionsInboxScreen> createState() => _ActionsInboxScreenState();
}

class _ActionsInboxScreenState extends ConsumerState<ActionsInboxScreen> {
  ActionsSubTab _tab = ActionsSubTab.nextActions;
  String? _selectedContext;
  bool _inboxRawEditorMode = false;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(allEntriesWithDocumentsProvider);
    final docsAsync = ref.watch(documentListProvider);
    final workspace = ref.watch(workspaceStateProvider);

    final allEntries = entriesAsync.value ?? const [];
    final allDocs = docsAsync.value ?? const [];

    final inboxItems = allEntries.where((e) {
      return e.document.relPath == CadenceFiles.inboxRelPath &&
          e.entry.taskState != 'completed' &&
          e.entry.taskState != 'dropped' &&
          e.entry.taskState != 'migrated' &&
          e.entry.taskState != 'scheduled';
    }).toList();

    return Column(
      children: [
        // Top navigation bar across GTD Organize & Calendar views
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (tab, label) in [
                (ActionsSubTab.inbox, '📥 Inbox (${inboxItems.length})'),
                (ActionsSubTab.nextActions, '⚡ Next Actions'),
                (ActionsSubTab.calendar, '📅 Calendar'),
                (ActionsSubTab.projects, '📁 Projects'),
                (ActionsSubTab.waiting, '⏳ Waiting'),
                (ActionsSubTab.someday, '🌱 Someday'),
              ])
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(label),
                  selected: _tab == tab,
                  onSelected: (_) => setState(() => _tab = tab),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (_tab) {
            ActionsSubTab.inbox => _buildInboxView(
              context,
              inboxItems,
              allDocs,
            ),
            ActionsSubTab.nextActions => _buildNextActionsView(
              context,
              allEntries,
              workspace,
            ),
            ActionsSubTab.calendar => _buildCalendarView(
              context,
              allEntries,
            ),
            ActionsSubTab.projects => _buildProjectsView(
              context,
              allDocs,
              allEntries,
            ),
            ActionsSubTab.waiting => _buildWaitingView(context, allEntries),
            ActionsSubTab.someday => _buildSomedayView(context, allEntries),
          },
        ),
      ],
    );
  }

  Widget _buildInboxView(
    BuildContext context,
    List<IndexedEntryWithDocument> inboxItems,
    List<Document> allDocs,
  ) {
    final hasInboxFile =
        allDocs.any((d) => d.relPath == CadenceFiles.inboxRelPath);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Inbox (${inboxItems.length} unclarified)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (inboxItems.isNotEmpty)
                FilledButton.icon(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) => _ClarifyDeckModal(items: inboxItems),
                    );
                  },
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: Text('Clarify (${inboxItems.length})'),
                ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _inboxRawEditorMode
                    ? 'Switch to Task Cards'
                    : 'Edit inbox.md in Live Preview',
                icon: Icon(
                  _inboxRawEditorMode ? Icons.view_list : Icons.edit_note,
                ),
                onPressed: () async {
                  if (!hasInboxFile) {
                    await ref.read(vaultMutationProvider).captureLine(
                      rawInput: '- [ ] ',
                      toTodayLog: false,
                    );
                  }
                  setState(() => _inboxRawEditorMode = !_inboxRawEditorMode);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _inboxRawEditorMode
              ? const EmbeddedMarkdownEditor(relPath: CadenceFiles.inboxRelPath)
              : inboxItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inbox_outlined, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              'Inbox Zero — Mind Like Water',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Use the Quick Capture bar below (with Inbox selected) to dump thoughts without organizing them first.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: inboxItems.length,
                      itemBuilder: (context, index) {
                        return InPlaceTaskTile(
                          item: inboxItems[index],
                          showSourceBadge: false,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildNextActionsView(
    BuildContext context,
    List<IndexedEntryWithDocument> allEntries,
    WorkspaceState workspace,
  ) {
    final now = DateTime.now();
    final cutoffMs = now
        .subtract(Duration(days: workspace.historicalTaskCutoffDays))
        .millisecondsSinceEpoch;

    // Collect all open next actions (excluding Someday and Waiting For)
    final allOpenActions = allEntries.where((e) {
      if (!e.isOpenTask) return false;
      if (e.isSomedayTask || e.isWaitingTask) return false;
      if (workspace.filterOlderUndatedTasks &&
          e.entry.dueDate == null &&
          e.document.mtimeMs < cutoffMs) {
        return false;
      }
      return true;
    }).toList();

    final availableContexts = <String>{
      'computer',
      'phone',
      'errands',
      'home',
      for (final e in allOpenActions) ...e.contexts,
    }.toList();

    final filtered = _selectedContext == null
        ? allOpenActions
        : allOpenActions
            .where((e) => e.contexts.contains(_selectedContext))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Context filter bar (E-01, G-04)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: Text('All Contexts (${allOpenActions.length})'),
                selected: _selectedContext == null,
                onSelected: (_) => setState(() => _selectedContext = null),
              ),
              const SizedBox(width: 6),
              for (final ctx in availableContexts) ...[
                FilterChip(
                  label: Text('@$ctx'),
                  selected: _selectedContext == ctx,
                  onSelected: (selected) {
                    setState(() => _selectedContext = selected ? ctx : null);
                  },
                ),
                const SizedBox(width: 6),
              ],
              if (workspace.filterOlderUndatedTasks)
                InputChip(
                  avatar: const Icon(Icons.filter_alt_outlined, size: 14),
                  label: Text(
                    'Last ${workspace.historicalTaskCutoffDays}d filter ON',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onDeleted: () {
                    ref
                        .read(workspaceStateProvider.notifier)
                        .setHistoricalTaskFilter(filterOlderUndatedTasks: false);
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _selectedContext == null
                        ? 'No open Next Actions right now.'
                        : 'No open actions for @$_selectedContext.',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return InPlaceTaskTile(item: filtered[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCalendarView(
    BuildContext context,
    List<IndexedEntryWithDocument> allEntries,
  ) {
    final now = DateTime.now();
    final todayIso = NlDateParser.formatIsoDate(now);
    final tomorrowIso = NlDateParser.formatIsoDate(
      DateTime(now.year, now.month, now.day + 1),
    );
    final nextWeekIso = NlDateParser.formatIsoDate(
      DateTime(now.year, now.month, now.day + 7),
    );

    // G-05: Calendar accepts ONLY explicit date/time commitments or events;
    // undated soft next actions never clutter the calendar.
    final commitments = allEntries.where((e) {
      if (e.entry.taskState == 'dropped' || e.entry.taskState == 'migrated') {
        return false;
      }
      return e.entry.dueDate != null || e.isEvent;
    }).toList()
      ..sort((a, b) {
        final da = a.entry.dueDate ?? '9999-99-99';
        final db = b.entry.dueDate ?? '9999-99-99';
        final cmp = da.compareTo(db);
        if (cmp != 0) return cmp;
        final ta = a.entry.dueTime ?? '99:99';
        final tb = b.entry.dueTime ?? '99:99';
        return ta.compareTo(tb);
      });

    final todayItems = commitments
        .where((e) => e.entry.dueDate == todayIso ||
            (e.entry.dueDate == null &&
                e.document.relPath == CadenceFiles.dailyRelPath(now)))
        .toList();
    final tomorrowItems =
        commitments.where((e) => e.entry.dueDate == tomorrowIso).toList();
    final upcomingWeekItems = commitments.where((e) {
      final d = e.entry.dueDate;
      if (d == null) return false;
      return d.compareTo(tomorrowIso) > 0 && d.compareTo(nextWeekIso) <= 0;
    }).toList();
    final laterItems = commitments.where((e) {
      final d = e.entry.dueDate;
      if (d == null) return false;
      return d.compareTo(nextWeekIso) > 0;
    }).toList();
    final earlierItems = commitments.where((e) {
      final d = e.entry.dueDate;
      if (d == null) return false;
      return d.compareTo(todayIso) < 0 && !e.isCompletedTask;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hard-Landscape Calendar (${commitments.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Only explicit date/time commitments appear here — undated tasks stay in Next Actions (G-05).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openAddCalendarCommitmentDialog(context),
                icon: const Icon(Icons.event_available, size: 16),
                label: const Text('Add Commitment'),
              ),
            ],
          ),
        ),
        Expanded(
          child: commitments.isEmpty
              ? const Center(
                  child: Text(
                    'No date-specific commitments yet. Add 📅 YYYY-MM-DD to any task or event.',
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    if (earlierItems.isNotEmpty)
                      _buildCalendarSection(
                        context,
                        'EARLIER OPEN COMMITMENTS',
                        earlierItems,
                      ),
                    _buildCalendarSection(
                      context,
                      'TODAY ($todayIso)',
                      todayItems,
                    ),
                    _buildCalendarSection(
                      context,
                      'TOMORROW ($tomorrowIso)',
                      tomorrowItems,
                    ),
                    if (upcomingWeekItems.isNotEmpty)
                      _buildCalendarSection(
                        context,
                        'NEXT 7 DAYS',
                        upcomingWeekItems,
                      ),
                    if (laterItems.isNotEmpty)
                      _buildCalendarSection(
                        context,
                        'LATER SCHEDULED',
                        laterItems,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCalendarSection(
    BuildContext context,
    String heading,
    List<IndexedEntryWithDocument> items,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              '$heading (${items.length})',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'No hard commitments scheduled.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            for (final item in items) InPlaceTaskTile(item: item),
        ],
      ),
    );
  }

  void _openAddCalendarCommitmentDialog(BuildContext context) {
    final now = DateTime.now();
    final titleCtrl = TextEditingController();
    final dateCtrl = TextEditingController(
      text: NlDateParser.formatIsoDate(now),
    );
    final timeCtrl = TextEditingController();
    var isEvent = true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Hard-Landscape Commitment (G-05)'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('○ Event')),
                    ButtonSegment(value: false, label: Text('[ ] Due Task')),
                  ],
                  selected: {isEvent},
                  onSelectionChanged: (s) =>
                      setDialogState(() => isEvent = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Commitment title',
                    hintText: 'e.g. Dentist appointment',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Date (YYYY-MM-DD)',
                          prefixText: '📅 ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: timeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Time (optional HH:MM)',
                          prefixText: '⏰ ',
                          hintText: '14:00',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final date = dateCtrl.text.trim();
                final time = timeCtrl.text.trim();
                if (title.isEmpty || date.isEmpty) return;

                final prefix = isEvent ? '- ○ ' : '- [ ] ';
                final timePart = time.isNotEmpty ? ' ⏰$time' : '';
                final line = '$prefix$title 📅 $date$timePart';

                await ref.read(vaultMutationProvider).captureLine(
                  rawInput: line,
                  toTodayLog: true,
                  defaultPrefix: prefix,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsView(
    BuildContext context,
    List<Document> allDocs,
    List<IndexedEntryWithDocument> allEntries,
  ) {
    final projects = allDocs.where((d) {
      return d.docType == 'project' || d.relPath.startsWith('projects/');
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Text(
                'Active Projects (${projects.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openCreateProjectDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Project'),
              ),
            ],
          ),
        ),
        Expanded(
          child: projects.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder_special_outlined, size: 40),
                        const SizedBox(height: 12),
                        const Text('No Projects yet'),
                        const SizedBox(height: 6),
                        Text(
                          'In GTD, any outcome requiring 2+ steps is a Project with a clear Outcome and at least one Next Action.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final proj = projects[index];
                    final projTasks = allEntries
                        .where((e) => e.document.id == proj.id && e.isTask)
                        .toList();
                    final openTasks =
                        projTasks.where((e) => e.isOpenTask).toList();
                    final isZombie = openTasks.isEmpty; // D-04 Zombie Project!

                    return _ProjectCard(
                      project: proj,
                      openTasks: openTasks,
                      isZombie: isZombie,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWaitingView(
    BuildContext context,
    List<IndexedEntryWithDocument> allEntries,
  ) {
    final waiting = allEntries.where((e) => e.isWaitingTask).toList();
    if (waiting.isEmpty) {
      return const Center(
        child: Text(
          'No Waiting For items (`- [w]` or `#waiting-for`).',
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: waiting.length,
      itemBuilder: (context, index) => InPlaceTaskTile(item: waiting[index]),
    );
  }

  Widget _buildSomedayView(
    BuildContext context,
    List<IndexedEntryWithDocument> allEntries,
  ) {
    final someday = allEntries
        .where((e) => e.isSomedayTask && e.entry.taskState != 'completed')
        .toList();
    if (someday.isEmpty) {
      return const Center(
        child: Text(
          'No Someday / Maybe items incubated right now.',
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: someday.length,
      itemBuilder: (context, index) => InPlaceTaskTile(item: someday[index]),
    );
  }

  void _openCreateProjectDialog(
    BuildContext context, {
    String? initialTitle,
    IndexedEntryWithDocument? promoteFromEntry,
    VoidCallback? onCreated,
  }) {
    showCreateProjectDialogWithOutcomePrompt(
      context,
      ref,
      initialTitle: initialTitle,
      promoteFromEntry: promoteFromEntry,
      onCreated: onCreated,
    );
  }
}

/// Shared Project Creation Dialog (`D-03`, `G-03`) that prompts for Project
/// Outcome and at least one physical Next Action, displaying a gentle skippable
/// warning if either is omitted so projects don't start out as "Zombie Projects"
/// (`D-04`).
void showCreateProjectDialogWithOutcomePrompt(
  BuildContext context,
  WidgetRef ref, {
  String? initialTitle,
  IndexedEntryWithDocument? promoteFromEntry,
  VoidCallback? onCreated,
}) {
  final titleCtrl = TextEditingController(text: initialTitle ?? '');
  final outcomeCtrl = TextEditingController();
  final nextActionCtrl = TextEditingController();
  var warnedAboutSkip = false;

  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('New Project (G-03)'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Project Name',
                  hintText: 'e.g. Renew Passport',
                ),
                autofocus: initialTitle == null || initialTitle.isEmpty,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: outcomeCtrl,
                autofocus: initialTitle != null && initialTitle.isNotEmpty,
                decoration: const InputDecoration(
                  labelText: 'Desired Successful Outcome (G-03)',
                  hintText: 'e.g. Valid passport in hand before July trip',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nextActionCtrl,
                decoration: const InputDecoration(
                  labelText:
                      'First Physical Next Action (prevents Zombie Project)',
                  hintText: 'e.g. Download renewal form PDF @computer',
                ),
              ),
              if (warnedAboutSkip) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚠️ GTD Tip (G-03 / D-04): Creating a project without an Outcome and at least one Next Action makes it a "Zombie Project". You can add one above, or click "Create Anyway (Skip)" to proceed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              final outcome = outcomeCtrl.text.trim();
              final nextAction = nextActionCtrl.text.trim();

              if (!warnedAboutSkip && (outcome.isEmpty || nextAction.isEmpty)) {
                setDialogState(() => warnedAboutSkip = true);
                return;
              }

              await ref.read(vaultMutationProvider).createNoteOrProject(
                title: title,
                docType: 'project',
                outcome: outcome,
                firstNextAction: nextAction,
                promoteFromEntry: promoteFromEntry,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              onCreated?.call();
            },
            child: Text(
              warnedAboutSkip ? 'Create Anyway (Skip)' : 'Create Project',
            ),
          ),
        ],
      ),
    ),
  );
}

/// Project card with automatic Zombie-Project warning (`D-04`) and inline
/// Next Action creation + in-place task editing (`D-19`).
class _ProjectCard extends ConsumerStatefulWidget {
  const _ProjectCard({
    required this.project,
    required this.openTasks,
    required this.isZombie,
  });

  final Document project;
  final List<IndexedEntryWithDocument> openTasks;
  final bool isZombie;

  @override
  ConsumerState<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends ConsumerState<_ProjectCard> {
  final TextEditingController _nextActionCtrl = TextEditingController();

  @override
  void dispose() {
    _nextActionCtrl.dispose();
    super.dispose();
  }

  Future<void> _appendActionToProject() async {
    final text = _nextActionCtrl.text.trim();
    if (text.isEmpty) return;
    _nextActionCtrl.clear();

    await ref.read(vaultMutationProvider).appendLineToDocument(
      relPath: widget.project.relPath,
      lineText: '- [ ] $text',
      initialContentIfMissing: '# ${widget.project.title}\n',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  color: widget.isZombie
                      ? colorScheme.error
                      : colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.project.title.isNotEmpty
                        ? widget.project.title
                        : widget.project.relPath,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.isZombie)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⚠️ Needs Next Action',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Open Project Note',
                  onPressed: () {
                    context.push(
                      '/documents/${widget.project.id}',
                      extra: widget.project,
                    );
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                ),
              ],
            ),
            if (widget.openTasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final task in widget.openTasks)
                InPlaceTaskTile(
                  item: task,
                  showSourceBadge: false,
                  dense: true,
                ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'This project has no open next action. Define the next visible physical step so it doesn\'t stall:',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nextActionCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Add next action (e.g. "Email Alex re: draft @computer")...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _appendActionToProject(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _appendActionToProject,
                    child: const Text('Add Step'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Guided GTD Clarify Card Deck (`G-01`, `G-02`, `G-06`):
/// walks through Inbox items one card at a time.
class _ClarifyDeckModal extends ConsumerStatefulWidget {
  const _ClarifyDeckModal({required this.items});

  final List<IndexedEntryWithDocument> items;

  @override
  ConsumerState<_ClarifyDeckModal> createState() => _ClarifyDeckModalState();
}

class _ClarifyDeckModalState extends ConsumerState<_ClarifyDeckModal> {
  int _index = 0;

  void _advance() {
    if (_index + 1 >= widget.items.length) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Inbox clarified! Every item has a trusted place.'),
        ),
      );
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty || _index >= widget.items.length) {
      return const SizedBox.shrink();
    }
    final item = widget.items[_index];
    final theme = Theme.of(context);
    final now = DateTime.now();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Clarify Inbox (${_index + 1} of ${widget.items.length})',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Pause'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: (_index + 1) / widget.items.length),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INBOX ITEM', style: theme.textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text(
                      item.entry.textContent,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ACTIONABLE',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    await ref.read(vaultMutationProvider).setTaskStateInPlace(
                      item,
                      TaskStateKind.completed,
                    );
                    _advance();
                  },
                  icon: const Icon(Icons.bolt, size: 16),
                  label: const Text('≤2 Min: Done Now!'),
                ),
                for (final ctx in const ['computer', 'phone', 'errands', 'home'])
                  FilledButton.tonal(
                    onPressed: () async {
                      await ref.read(vaultMutationProvider).updateEntryInPlace(
                        item,
                        newState: TaskStateKind.open,
                        addContext: ctx,
                      );
                      await ref
                          .read(vaultMutationProvider)
                          .migrateOrScheduleEntry(
                            item,
                            targetRelPath: CadenceFiles.dailyRelPath(now),
                            targetInitialContent:
                                CadenceFiles.defaultContentForCadence(
                                  CadenceKind.daily,
                                  now,
                                ),
                          );
                      _advance();
                    },
                    child: Text('Next Action @$ctx'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _promptScheduleOnCalendar(context, item),
                  icon: const Icon(Icons.event, size: 16),
                  label: const Text('Schedule on Calendar (G-05)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _promptDelegateWaitingFor(context, item),
                  icon: const Icon(Icons.hourglass_top, size: 16),
                  label: const Text('Delegate / Waiting For ([w])'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    showCreateProjectDialogWithOutcomePrompt(
                      context,
                      ref,
                      initialTitle: item.entry.textContent,
                      promoteFromEntry: item,
                      onCreated: _advance,
                    );
                  },
                  icon: const Icon(Icons.folder_outlined, size: 16),
                  label: const Text('Promote to Project (G-03)'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'NOT ACTIONABLE RIGHT NOW',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(vaultMutationProvider)
                        .migrateOrScheduleEntry(
                          item,
                          targetRelPath: CadenceFiles.somedayRelPath,
                          targetInitialContent:
                              CadenceFiles.defaultSomedayContent(),
                          sourceMarker: TaskStateKind.scheduled,
                        );
                    _advance();
                  },
                  icon: const Icon(Icons.spa_outlined, size: 16),
                  label: const Text('Someday / Maybe (D-05)'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(vaultMutationProvider).fileToReference(item);
                    _advance();
                  },
                  icon: const Icon(Icons.menu_book_outlined, size: 16),
                  label: const Text('File to Reference (D-07)'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(vaultMutationProvider).setTaskStateInPlace(
                      item,
                      TaskStateKind.dropped,
                    );
                    _advance();
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Drop / Trash (-)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptDelegateWaitingFor(
    BuildContext context,
    IndexedEntryWithDocument item,
  ) async {
    final whoCtrl = TextEditingController();
    final dateCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delegate / Waiting For (D-06)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: whoCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Person or system you are waiting on',
                hintText: 'e.g. Alex, IT Support, Vendor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dateCtrl,
              decoration: const InputDecoration(
                labelText: 'Follow-up date (optional YYYY-MM-DD)',
                prefixText: '📅 ',
                hintText: '2026-11-05',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Mark Waiting For ([w])'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(vaultMutationProvider).delegateToWaitingFor(
        item,
        delegateTo: whoCtrl.text,
        followUpDate: dateCtrl.text,
      );
      _advance();
    }
    whoCtrl.dispose();
    dateCtrl.dispose();
  }

  Future<void> _promptScheduleOnCalendar(
    BuildContext context,
    IndexedEntryWithDocument item,
  ) async {
    final now = DateTime.now();
    final dateCtrl = TextEditingController(
      text: NlDateParser.formatIsoDate(
        DateTime(now.year, now.month, now.day + 1),
      ),
    );
    final timeCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Schedule on Hard-Landscape Calendar (G-05)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dateCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Commitment Date (YYYY-MM-DD)',
                prefixText: '📅 ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: timeCtrl,
              decoration: const InputDecoration(
                labelText: 'Time (optional HH:MM)',
                prefixText: '⏰ ',
                hintText: '10:00',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Schedule'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final dateStr = dateCtrl.text.trim();
      final timeStr = timeCtrl.text.trim();
      if (dateStr.isNotEmpty) {
        await ref.read(vaultMutationProvider).updateEntryInPlace(
          item,
          newState: TaskStateKind.open,
          dueDate: dateStr,
          dueTime: timeStr.isNotEmpty ? timeStr : null,
        );
        await ref.read(vaultMutationProvider).migrateOrScheduleEntry(
          item,
          targetRelPath: CadenceFiles.dailyRelPath(now),
          targetInitialContent: CadenceFiles.defaultContentForCadence(
            CadenceKind.daily,
            now,
          ),
          sourceMarker: TaskStateKind.scheduled,
          overrideDueDate: dateStr,
        );
        _advance();
      }
    }
    dateCtrl.dispose();
    timeCtrl.dispose();
  }
}
