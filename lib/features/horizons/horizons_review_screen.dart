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
/// Includes dynamic horizon threading (`QY-04`) across enabled cadences and
/// a guided review ritual for each cadence.
class HorizonsReviewScreen extends ConsumerStatefulWidget {
  const HorizonsReviewScreen({super.key});

  @override
  ConsumerState<HorizonsReviewScreen> createState() =>
      _HorizonsReviewScreenState();
}

class _HorizonsReviewScreenState extends ConsumerState<HorizonsReviewScreen> {
  CadenceKind _selectedCadence = CadenceKind.weekly;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top cadence selector + Configure Cadences button (B-12)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<CadenceKind>(
                    showSelectedIcon: false,
                    segments: [
                      for (final c in enabledList)
                        ButtonSegment(
                          value: c,
                          label: Text(c.label),
                        ),
                    ],
                    selected: {activeCadence},
                    onSelectionChanged: (sel) {
                      setState(() => _selectedCadence = sel.first);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _openConfigureCadencesDialog(context),
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Cadences'),
              ),
            ],
          ),
        ),

        // Dynamic Horizon Threading Breadcrumbs (QY-04) + Start Review button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.account_tree_outlined, size: 15),
              Text(
                'Horizon Threading:',
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
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
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
                'Enable only the horizons that fit how you work. Disabling a cadence hides its tabs without deleting any Markdown files on disk.',
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

/// Guided Multi-Step Review Ritual (`R-01`, `R-02`, `R-03`, `Q-02`, `Y-02`):
/// 1. Celebrate What Shipped (completed tasks — ADHD positive reinforcement)
/// 2. Open Loop / Future Log Triage (with in-place editing `D-19`)
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
    final completedTasks =
        widget.allEntries.where((e) => e.isCompletedTask).toList();
    final openTasks = widget.allEntries.where((e) => e.isOpenTask).toList();
    final futureItems = widget.allEntries.where((e) {
      return e.document.relPath == CadenceFiles.futureLogRelPath &&
          e.isOpenTask;
    }).toList();
    final projects = widget.allDocs.where((d) {
      return d.docType == 'project' || d.relPath.startsWith('projects/');
    }).toList();
    final zombieProjects = projects.where((p) {
      return !widget.allEntries.any(
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
                  Text(
                    'Guided ${widget.cadence.label} Review (Step ${_step + 1} of 4)',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
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
                  1 => _buildStepOpenLoops(theme, openTasks, futureItems),
                  2 => _buildStepProjectsAndWaiting(theme, zombieProjects),
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

  Widget _buildStepOpenLoops(
    ThemeData theme,
    List<IndexedEntryWithDocument> openTasks,
    List<IndexedEntryWithDocument> futureItems,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '2. Review Open Loops & Future Log (${openTasks.length} open)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Click any task below to edit it in-place, migrate it to Today, park it in Someday/Maybe, or drop it cleanly.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: openTasks.isEmpty
              ? const Center(child: Text('Zero open tasks — all clear!'))
              : ListView.builder(
                  itemCount: openTasks.length,
                  itemBuilder: (context, index) {
                    return InPlaceTaskTile(item: openTasks[index], dense: true);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStepProjectsAndWaiting(
    ThemeData theme,
    List<Document> zombieProjects,
  ) {
    final waiting =
        widget.allEntries.where((e) => e.isWaitingTask).toList();
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
