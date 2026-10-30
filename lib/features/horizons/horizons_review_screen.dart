import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/index/index_providers.dart';
import '../../core/workspace/workspace_state.dart';
import '../../shared/widgets/embedded_markdown_editor.dart';
import '../../shared/widgets/in_place_task_tile.dart';

/// Pillar 3 of the Hybrid Dual-Track UX (`design.md` §6.2):
/// User-configurable planning & review cadences (`B-12`):
/// - Daily (`daily/YYYY-MM-DD.md`, `B-01`, `R-02`)
/// - Weekly (`weekly/YYYY-Www.md`, `B-02`, `R-01`)
/// - Monthly (`monthly/YYYY-MM.md`, `B-02`, `B-07`)
/// - Quarterly (`quarterly/YYYY-QN.md`, `Q-01`, `Q-02`)
/// - Yearly (`yearly/YYYY.md`, `Y-01`, `Y-02`)
/// - Future Log (`future.md`, `B-03`)
///
/// Includes dynamic horizon threading (`QY-04`) across enabled cadences,
/// editable/replaceable cadence templates (`B-11`), and a guided review/migration
/// ritual (`B-06`, `B-07`, `R-01`, `R-02`) for each cadence.
class HorizonsReviewScreen extends ConsumerStatefulWidget {
  const HorizonsReviewScreen({super.key});

  @override
  ConsumerState<HorizonsReviewScreen> createState() =>
      _HorizonsReviewScreenState();
}

class _HorizonsReviewScreenState extends ConsumerState<HorizonsReviewScreen> {
  CadenceKind _selectedCadence = CadenceKind.weekly;
  bool _periodShelfExpanded = true;

  List<IndexedEntryWithDocument> _entriesForCadencePeriod({
    required CadenceKind cadence,
    required String currentRelPath,
    required DateTime now,
    required List<IndexedEntryWithDocument> allEntries,
  }) {
    final monthPrefix = CadenceFiles.monthlyRelPath(now)
        .replaceAll('monthly/', '')
        .replaceAll('.md', ''); // YYYY-MM
    return allEntries.where((e) {
      if (e.document.relPath == currentRelPath) {
        return e.isTask || e.isEvent;
      }
      if (cadence == CadenceKind.monthly &&
          e.entry.dueDate != null &&
          e.entry.dueDate!.startsWith(monthPrefix)) {
        return e.isTask || e.isEvent;
      }
      return false;
    }).toList();
  }

  void _openQuickAddToCadenceDialog(
    BuildContext context, {
    required CadenceKind cadence,
    required String targetRelPath,
    required DateTime now,
  }) {
    final textCtrl = TextEditingController();
    var entryPrefix = '- [ ]';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Add to ${cadence.label} ($targetRelPath)'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: '- [ ]', label: Text('• Task')),
                    ButtonSegment(value: '- ○', label: Text('○ Event')),
                    ButtonSegment(value: '- –', label: Text('– Note')),
                  ],
                  selected: {entryPrefix},
                  onSelectionChanged: (s) =>
                      setDialogState(() => entryPrefix = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  decoration: InputDecoration(
                    labelText: 'Entry for $targetRelPath',
                    hintText: cadence == CadenceKind.future
                        ? 'e.g. Renew passport 📅 2026-12-15'
                        : 'e.g. Ship milestone outcomes @computer',
                    border: const OutlineInputBorder(),
                  ),
                  autofocus: true,
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
                final raw = textCtrl.text.trim();
                if (raw.isEmpty) return;
                await ref
                    .read(vaultMutationProvider)
                    .ensureCadenceDocument(cadence, now);
                await ref.read(vaultMutationProvider).appendLineToDocument(
                  relPath: targetRelPath,
                  lineText: '$entryPrefix $raw',
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceStateProvider);
    final docsAsync = ref.watch(documentListProvider);
    final entriesAsync = ref.watch(allEntriesWithDocumentsProvider);

    final enabledList = CadenceKind.values
        .where((c) => workspace.enabledCadences.contains(c))
        .toList();

    final activeCadence = enabledList.contains(_selectedCadence)
        ? _selectedCadence
        : (enabledList.isNotEmpty ? enabledList.first : CadenceKind.daily);

    final now = DateTime.now();
    final currentRelPath = CadenceFiles.relPathForCadence(activeCadence, now);
    final docs = docsAsync.value ?? const [];
    final allEntries = entriesAsync.value ?? const [];
    final existsOnDisk = docs.any((d) => d.relPath == currentRelPath);
    final periodEntries = _entriesForCadencePeriod(
      cadence: activeCadence,
      currentRelPath: currentRelPath,
      now: now,
      allEntries: allEntries,
    );
    final bridgedHorizons = CadenceFiles.horizonLinksForCadence(
      activeCadence,
      now,
      workspace.enabledCadences,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top cadence selector + Templates (B-11) & Configure Cadences (B-12)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in enabledList)
                      ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          c.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: activeCadence == c,
                        onSelected: (_) {
                          setState(() => _selectedCadence = c);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => showCadenceTemplatesDialog(
                  context,
                  initialCadence: activeCadence,
                ),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Templates'),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: () => _openConfigureCadencesDialog(context),
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Cadences'),
              ),
            ],
          ),
        ),

        // Dynamic Horizon Threading Breadcrumbs (QY-04, B-12) + Start Review button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.account_tree_outlined, size: 15),
              Text(
                bridgedHorizons.isEmpty
                    ? 'Horizon Threading:'
                    : 'Horizon Threading (${bridgedHorizons.join(' ↔ ')}):',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              for (final c in enabledList.where((c) => c != CadenceKind.future))
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: c == activeCadence
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  label: Text(
                    CadenceFiles.relPathForCadence(c, now)
                        .replaceAll('.md', '')
                        .split('/')
                        .last,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () => setState(() => _selectedCadence = c),
                ),
              OutlinedButton.icon(
                onPressed: () => _openQuickAddToCadenceDialog(
                  context,
                  cadence: activeCadence,
                  targetRelPath: currentRelPath,
                  now: now,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text('Add to ${activeCadence.label}'),
              ),
              if (activeCadence != CadenceKind.future)
                FilledButton.tonalIcon(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) => _GuidedCadenceReviewModal(
                        cadence: activeCadence,
                        targetRelPath: currentRelPath,
                        allEntries: allEntries,
                        allDocs: docs,
                      ),
                    );
                  },
                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                  label: Text('Start ${activeCadence.label} Review'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Period Open Loops & Key Dates Shelf (B-02, B-03, D-19)
        if (periodEntries.isNotEmpty)
          Card(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.playlist_add_check, size: 18),
                  title: Text(
                    '${activeCadence.label} Open Loops & Key Dates (${periodEntries.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      _periodShelfExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                    ),
                    onPressed: () => setState(
                      () => _periodShelfExpanded = !_periodShelfExpanded,
                    ),
                  ),
                ),
                if (_periodShelfExpanded)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      itemCount: periodEntries.length,
                      itemBuilder: (context, index) => InPlaceTaskTile(
                        item: periodEntries[index],
                        dense: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),

        // Planning page editor (created lazily on first use — B-09, B-11, D-11)
        Expanded(
          child: existsOnDisk
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        '${activeCadence.label} Planning Surface ($currentRelPath)',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Expanded(
                      child: EmbeddedMarkdownEditor(relPath: currentRelPath),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.explore_outlined, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          '${activeCadence.label} Log ($currentRelPath)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          activeCadence.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: () async {
                                await ref
                                    .read(vaultMutationProvider)
                                    .ensureCadenceDocument(activeCadence, now);
                              },
                              icon: const Icon(Icons.add),
                              label: Text('Create $currentRelPath'),
                            ),
                            if (activeCadence != CadenceKind.future)
                              OutlinedButton.icon(
                                onPressed: () {
                                  showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (ctx) => _GuidedCadenceReviewModal(
                                      cadence: activeCadence,
                                      targetRelPath: currentRelPath,
                                      allEntries: allEntries,
                                      allDocs: docs,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.play_arrow),
                                label: Text(
                                  'Start Guided ${activeCadence.label} Review',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  void _openConfigureCadencesDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => const _ConfigureCadencesDialog(),
    );
  }
}

/// Opens the Editable / Replaceable Cadence Templates dialog (`B-11`).
Future<void> showCadenceTemplatesDialog(
  BuildContext context, {
  CadenceKind initialCadence = CadenceKind.daily,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _CadenceTemplatesDialog(initialCadence: initialCadence),
  );
}

class _CadenceTemplatesDialog extends ConsumerStatefulWidget {
  const _CadenceTemplatesDialog({required this.initialCadence});

  final CadenceKind initialCadence;

  @override
  ConsumerState<_CadenceTemplatesDialog> createState() =>
      _CadenceTemplatesDialogState();
}

class _CadenceTemplatesDialogState
    extends ConsumerState<_CadenceTemplatesDialog> {
  late CadenceKind _cadence = widget.initialCadence;
  final TextEditingController _templateCtrl = TextEditingController();
  bool _isCustom = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplate(_cadence);
  }

  @override
  void dispose() {
    _templateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate(CadenceKind cadence) async {
    setState(() {
      _cadence = cadence;
      _loading = true;
    });
    final res =
        await ref.read(vaultMutationProvider).readCadenceTemplate(cadence);
    if (!mounted) return;
    setState(() {
      _templateCtrl.text = res.text;
      _isCustom = res.isCustom;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Cadence Templates (B-11)'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customize or replace the default Markdown template for any cadence (.citrinium/templates/<id>.md). Editing a template never disables the underlying cadence or review ritual.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in CadenceKind.values)
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        c.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _cadence == c,
                      onSelected: (_) => _loadTemplate(c),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isCustom
                          ? 'Using custom template (${CadenceFiles.templateRelPath(_cadence)})'
                          : 'Using built-in functional default template',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  if (_isCustom)
                    TextButton.icon(
                      onPressed: () async {
                        await ref
                            .read(vaultMutationProvider)
                            .resetCadenceTemplate(_cadence);
                        await _loadTemplate(_cadence);
                      },
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Reset to Default'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                TextField(
                  controller: _templateCtrl,
                  minLines: 7,
                  maxLines: 11,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: '${_cadence.label} Template Markdown',
                    helperText:
                        'Placeholders: {{date}}, {{week}}, {{month}}, {{quarter}}, {{year}}, {{horizons}}',
                    border: const OutlineInputBorder(),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: _loading
              ? null
              : () async {
                  await ref
                      .read(vaultMutationProvider)
                      .saveCadenceTemplate(_cadence, _templateCtrl.text);
                  if (!context.mounted) return;
                  setState(() => _isCustom = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Saved custom ${_cadence.label} template (${CadenceFiles.templateRelPath(_cadence)}).',
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('Save Template'),
        ),
      ],
    );
  }
}

/// Dialog allowing users to configure which planning and review cadences they
/// want enabled (`B-12`).
class _ConfigureCadencesDialog extends ConsumerWidget {
  const _ConfigureCadencesDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceStateProvider);

    return AlertDialog(
      title: const Text('Configure Planning & Review Cadences (B-12)'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enable only the horizons that fit how you work. Disabling a cadence hides its tabs without deleting any Markdown files on disk, and horizon links automatically bridge across enabled cadences.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final c in CadenceKind.values)
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.label),
                  subtitle: Text(c.description),
                  value: workspace.enabledCadences.contains(c),
                  onChanged: (enabled) {
                    ref
                        .read(workspaceStateProvider.notifier)
                        .toggleCadence(c, enabled);
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Guided Multi-Step Review & End-of-Period Migration Ritual (`B-06`, `B-07`,
/// `R-01`, `R-02`, `R-03`, `Q-02`, `Y-02`):
/// 1. Celebrate What Shipped (completed tasks — ADHD positive reinforcement)
/// 2. End-of-Period Migration & Open Loop Triage (`B-06`, `B-07`, `D-19`)
/// 3. Project Health & Waiting For Check (`D-04`, `D-06`)
/// 4. Set Focus Priorities for the current period (`targetRelPath`)
class _GuidedCadenceReviewModal extends ConsumerStatefulWidget {
  const _GuidedCadenceReviewModal({
    required this.cadence,
    required this.targetRelPath,
    required this.allEntries,
    required this.allDocs,
  });

  final CadenceKind cadence;
  final String targetRelPath;
  final List<IndexedEntryWithDocument> allEntries;
  final List<Document> allDocs;

  @override
  ConsumerState<_GuidedCadenceReviewModal> createState() =>
      _GuidedCadenceReviewModalState();
}

class _GuidedCadenceReviewModalState
    extends ConsumerState<_GuidedCadenceReviewModal> {
  int _step = 0;
  final TextEditingController _focusCtrl = TextEditingController();

  @override
  void dispose() {
    _focusCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entriesAsync = ref.watch(allEntriesWithDocumentsProvider);
    final docsAsync = ref.watch(documentListProvider);
    final liveEntries = entriesAsync.value ?? widget.allEntries;
    final liveDocs = docsAsync.value ?? widget.allDocs;

    final completedTasks =
        liveEntries.where((e) => e.isCompletedTask).toList();
    final openTasks = liveEntries
        .where(
          (e) => e.isOpenTask && e.document.relPath != widget.targetRelPath,
        )
        .toList();
    final futureItems = liveEntries.where((e) {
      return e.document.relPath == CadenceFiles.futureLogRelPath &&
          e.isOpenTask;
    }).toList();
    final projects = liveDocs.where((d) {
      return d.docType == 'project' || d.relPath.startsWith('projects/');
    }).toList();
    final zombieProjects = projects.where((p) {
      return !liveEntries.any(
        (e) => e.document.id == p.id && e.isOpenTask,
      );
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Guided ${widget.cadence.label} Review (Step ${_step + 1} of 4)',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Save & Close'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (_step + 1) / 4),
              const SizedBox(height: 16),

              Expanded(
                child: switch (_step) {
                  0 => _buildStepCelebrate(theme, completedTasks),
                  1 => _buildStepOpenLoopsAndMigration(
                    theme,
                    openTasks,
                    futureItems,
                  ),
                  2 => _buildStepProjectsAndWaiting(
                    theme,
                    zombieProjects,
                    liveEntries,
                  ),
                  _ => _buildStepSetPriorities(theme),
                },
              ),

              const Divider(),
              Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (_step < 3)
                    FilledButton(
                      onPressed: () => setState(() => _step++),
                      child: const Text('Next Step →'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () async {
                        final text = _focusCtrl.text.trim();
                        final now = DateTime.now();
                        await ref
                            .read(vaultMutationProvider)
                            .ensureCadenceDocument(widget.cadence, now);
                        if (text.isNotEmpty) {
                          await ref
                              .read(vaultMutationProvider)
                              .appendLineToDocument(
                                relPath: widget.targetRelPath,
                                lineText: '- [ ] $text',
                              );
                        }
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${widget.cadence.label} Review complete! Updated ${widget.targetRelPath}.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: Text('Finish ${widget.cadence.label} Review'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCelebrate(
    ThemeData theme,
    List<IndexedEntryWithDocument> completedTasks,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '1. Celebrate What Shipped 🎉',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Before looking at open loops, take a moment to see what you\'ve already completed (${completedTasks.length} completed items in vault).',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: completedTasks.isEmpty
              ? const Center(
                  child: Text(
                    'No completed tasks recorded yet — every small step counts!',
                  ),
                )
              : ListView.builder(
                  itemCount: completedTasks.length,
                  itemBuilder: (context, index) {
                    return InPlaceTaskTile(
                      item: completedTasks[index],
                      dense: true,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStepOpenLoopsAndMigration(
    ThemeData theme,
    List<IndexedEntryWithDocument> openTasks,
    List<IndexedEntryWithDocument> futureItems,
  ) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '2. End-of-Period Migration & Open Loops (${openTasks.length} open)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Make an intentional decision for open items from earlier periods or Future Log (${futureItems.length} in Future Log): Migrate (>) into ${widget.targetRelPath}, Schedule (<) to Future Log, or Drop (-).',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: openTasks.isEmpty
              ? const Center(child: Text('Zero open tasks — all clear!'))
              : ListView.builder(
                  itemCount: openTasks.length,
                  itemBuilder: (context, index) {
                    final item = openTasks[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InPlaceTaskTile(item: item, dense: true),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.keyboard_arrow_right,
                                    size: 15,
                                  ),
                                  label: Text(
                                    'Migrate to ${widget.cadence.label} (>)',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(vaultMutationProvider)
                                        .migrateOrScheduleEntry(
                                          item,
                                          targetRelPath: widget.targetRelPath,
                                          targetInitialContent:
                                              CadenceFiles
                                                  .defaultContentForCadence(
                                                    widget.cadence,
                                                    now,
                                                  ),
                                          sourceMarker: TaskStateKind.migrated,
                                        );
                                  },
                                ),
                                if (item.document.relPath !=
                                    CadenceFiles.futureLogRelPath)
                                  ActionChip(
                                    visualDensity: VisualDensity.compact,
                                    avatar: const Icon(
                                      Icons.keyboard_arrow_left,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      'Future Log (<)',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    onPressed: () async {
                                      await ref
                                          .read(vaultMutationProvider)
                                          .migrateOrScheduleEntry(
                                            item,
                                            targetRelPath:
                                                CadenceFiles.futureLogRelPath,
                                            targetInitialContent:
                                                CadenceFiles
                                                    .defaultContentForCadence(
                                                      CadenceKind.future,
                                                      now,
                                                    ),
                                            sourceMarker:
                                                TaskStateKind.scheduled,
                                          );
                                    },
                                  ),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.close, size: 15),
                                  label: const Text(
                                    'Drop (-)',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(vaultMutationProvider)
                                        .setTaskStateInPlace(
                                          item,
                                          TaskStateKind.dropped,
                                        );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStepProjectsAndWaiting(
    ThemeData theme,
    List<Document> zombieProjects,
    List<IndexedEntryWithDocument> liveEntries,
  ) {
    final waiting = liveEntries.where((e) => e.isWaitingTask).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '3. Project Health & Waiting For Check (D-04, R-01)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (zombieProjects.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.check_circle_outline),
              title: Text('All active projects have at least one Next Action!'),
            ),
          )
        else ...[
          Text(
            '⚠️ Projects missing a Next Action (${zombieProjects.length}):',
            style: theme.textTheme.labelLarge,
          ),
          for (final z in zombieProjects)
            ListTile(
              dense: true,
              leading: const Icon(Icons.warning_amber_rounded),
              title: Text(z.title.isNotEmpty ? z.title : z.relPath),
              subtitle: Text(z.relPath),
            ),
        ],
        const SizedBox(height: 12),
        Text(
          'Waiting For items (${waiting.length}):',
          style: theme.textTheme.labelLarge,
        ),
        Expanded(
          child: waiting.isEmpty
              ? const Center(child: Text('No Waiting For items right now.'))
              : ListView.builder(
                  itemCount: waiting.length,
                  itemBuilder: (context, index) =>
                      InPlaceTaskTile(item: waiting[index], dense: true),
                ),
        ),
      ],
    );
  }

  Widget _buildStepSetPriorities(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '4. Choose Focus for ${widget.targetRelPath}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'What is the #1 outcome or theme that would make this ${widget.cadence.label.toLowerCase()} feel successful?',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _focusCtrl,
          decoration: InputDecoration(
            labelText: 'Add priority outcome to ${widget.targetRelPath}',
            hintText: 'e.g. Ship v1 prototype @computer',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
      ],
    );
  }
}
