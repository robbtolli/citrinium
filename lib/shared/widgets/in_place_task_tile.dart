import 'dart:async';

import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/index/index_providers.dart';
import '../../core/workspace/workspace_state.dart';

/// Displays an indexed task/entry in any aggregated list (Today's Focus Shelf,
/// Inbox, Next Actions, Projects, Waiting For, Someday/Maybe, or Reviews) and
/// supports **100% in-place editing (`D-19`, `B-05`, `A-03`)** without jumping
/// away to the source document.
///
/// Clicking/tapping the row expands an inline editor right inside the list;
/// tapping the `[📄 source ↗]` badge opens a surrounding-context peek sheet
/// with an option to open the full document only when desired.
class InPlaceTaskTile extends ConsumerStatefulWidget {
  const InPlaceTaskTile({
    required this.item,
    this.showSourceBadge = true,
    this.dense = false,
    super.key,
  });

  final IndexedEntryWithDocument item;
  final bool showSourceBadge;
  final bool dense;

  @override
  ConsumerState<InPlaceTaskTile> createState() => _InPlaceTaskTileState();
}

class _InPlaceTaskTileState extends ConsumerState<InPlaceTaskTile> {
  bool _expanded = false;
  late TextEditingController _textController;
  late TextEditingController _childNoteController;
  bool _loadedChildNote = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.item.entry.textContent);
    _childNoteController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant InPlaceTaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_expanded &&
        oldWidget.item.entry.textContent != widget.item.entry.textContent) {
      _textController.text = widget.item.entry.textContent;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _childNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadChildNoteFromDisk() async {
    try {
      final raw = await ref.read(
        documentRawTextProvider(widget.item.document.relPath).future,
      );
      if (!mounted) return;
      final doc = MarkdownDocument.parse(raw);
      final idx = widget.item.entry.lineIndex;
      if (idx >= 0 && idx < doc.lines.length) {
        final childText = doc.readChildBlockText(idx);
        setState(() {
          _childNoteController.text = childText;
          _loadedChildNote = true;
        });
      }
    } catch (_) {
      // Ignore if document is still loading
    }
  }

  Future<void> _toggleCompleted() async {
    final mutations = ref.read(vaultMutationProvider);
    final isDone = widget.item.isCompletedTask;
    await mutations.setTaskStateInPlace(
      widget.item,
      isDone ? TaskStateKind.open : TaskStateKind.completed,
    );
  }

  Future<void> _saveEditedText() async {
    final newText = _textController.text.trim();
    if (newText.isEmpty) return;
    await ref.read(vaultMutationProvider).updateEntryInPlace(
      widget.item,
      newContent: newText,
      newChildNoteBody: _loadedChildNote ? _childNoteController.text : null,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated in ${widget.item.document.relPath}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _setQuickDate(DateTime? targetDate) async {
    final mutations = ref.read(vaultMutationProvider);
    if (targetDate == null) {
      await mutations.updateEntryInPlace(widget.item, clearDueDate: true);
    } else {
      await mutations.updateEntryInPlace(
        widget.item,
        dueDate: NlDateParser.formatIsoDate(targetDate),
      );
    }
    if (mounted) {
      final updated = await ref
          .read(documentRawTextProvider(widget.item.document.relPath).future);
      final doc = MarkdownDocument.parse(updated);
      if (widget.item.entry.lineIndex < doc.lines.length) {
        final line = doc.lines[widget.item.entry.lineIndex];
        final task = line.task;
        if (task != null) {
          _textController.text = doc.rawText.substring(
            task.contentSpan.start,
            task.contentSpan.end,
          );
        }
      }
    }
  }

  Future<void> _toggleContext(String ctxName) async {
    final hasCtx = widget.item.contexts.contains(ctxName);
    await ref.read(vaultMutationProvider).updateEntryInPlace(
      widget.item,
      addContext: hasCtx ? null : ctxName,
      removeContext: hasCtx ? ctxName : null,
    );
  }

  Future<void> _promptCustomContext(BuildContext context) async {
    final controller = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom @Context (D-08)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Context name (e.g. office, garage, agenda-alex)',
            prefixText: '@',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (added != null && added.trim().isNotEmpty) {
      await ref.read(vaultMutationProvider).updateEntryInPlace(
        widget.item,
        addContext: added.trim(),
      );
    }
  }

  Future<void> _migrateToToday() async {
    final now = DateTime.now();
    final todayRelPath = CadenceFiles.dailyRelPath(now);
    await ref.read(vaultMutationProvider).migrateOrScheduleEntry(
      widget.item,
      targetRelPath: todayRelPath,
      targetInitialContent: CadenceFiles.defaultContentForCadence(
        CadenceKind.daily,
        now,
      ),
      sourceMarker: TaskStateKind.migrated,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Migrated to $todayRelPath')),
      );
    }
  }

  Future<void> _moveToSomeday() async {
    await ref.read(vaultMutationProvider).migrateOrScheduleEntry(
      widget.item,
      targetRelPath: CadenceFiles.somedayRelPath,
      targetInitialContent: CadenceFiles.defaultSomedayContent(),
      sourceMarker: TaskStateKind.scheduled,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parked in Someday / Maybe for when you\'re ready.'),
        ),
      );
    }
  }

  Future<void> _dropTask() async {
    await ref.read(vaultMutationProvider).setTaskStateInPlace(
      widget.item,
      TaskStateKind.dropped,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dropped cleanly — one less thing on your plate.'),
        ),
      );
    }
  }

  void _openSourcePeekSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SourceContextPeekSheet(item: widget.item),
    );
  }

  void _openTwoMinuteFocusDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _TwoMinuteFocusDialog(item: widget.item),
    );
  }

  Widget _buildStateLeadingIcon(ColorScheme colorScheme) {
    if (widget.item.isEvent) {
      return Icon(Icons.panorama_fish_eye, size: 18, color: colorScheme.primary);
    }
    if (widget.item.isNote) {
      return Icon(Icons.horizontal_rule, size: 18, color: colorScheme.secondary);
    }
    final state = widget.item.entry.taskState;
    switch (state) {
      case 'completed':
        return Icon(Icons.check_box, size: 20, color: colorScheme.primary);
      case 'inProgress':
        return Icon(
          Icons.indeterminate_check_box_outlined,
          size: 20,
          color: colorScheme.tertiary,
        );
      case 'migrated':
        return Icon(
          Icons.keyboard_arrow_right,
          size: 20,
          color: colorScheme.secondary,
        );
      case 'scheduled':
        return Icon(
          Icons.keyboard_arrow_left,
          size: 20,
          color: colorScheme.secondary,
        );
      case 'waitingFor':
        return Icon(
          Icons.hourglass_top,
          size: 18,
          color: colorScheme.tertiary,
        );
      case 'dropped':
        return Icon(
          Icons.disabled_by_default_outlined,
          size: 20,
          color: colorScheme.outline,
        );
      default:
        return Icon(
          Icons.check_box_outline_blank,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final workspace = ref.watch(workspaceStateProvider);
    final isPinned = workspace.isPinnedToday(widget.item.uniqueKey);
    final isDone = widget.item.isCompletedTask;
    final isDropped = widget.item.entry.taskState == 'dropped';

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: widget.dense ? 0 : 8,
        vertical: 3,
      ),
      elevation: _expanded ? 2 : 0,
      color: _expanded
          ? colorScheme.surfaceContainerHigh
          : colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _expanded = !_expanded;
                if (_expanded) {
                  _textController.text = widget.item.entry.textContent;
                  _loadChildNoteFromDisk();
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: _toggleCompleted,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: _buildStateLeadingIcon(colorScheme),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.entry.textContent,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            decoration: (isDone || isDropped)
                                ? TextDecoration.lineThrough
                                : null,
                            color: (isDone || isDropped)
                                ? colorScheme.outline
                                : colorScheme.onSurface,
                          ),
                        ),
                        if (widget.item.entry.dueDate != null ||
                            widget.item.contexts.isNotEmpty ||
                            widget.item.tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (widget.item.entry.dueDate != null)
                                _MetadataPill(
                                  label:
                                      '📅 ${widget.item.entry.dueDate}${widget.item.entry.dueTime != null ? ' ${widget.item.entry.dueTime}' : ''}',
                                  color: colorScheme.primaryContainer,
                                  textColor: colorScheme.onPrimaryContainer,
                                ),
                              for (final ctx in widget.item.contexts)
                                _MetadataPill(
                                  label: '@$ctx',
                                  color: colorScheme.secondaryContainer,
                                  textColor: colorScheme.onSecondaryContainer,
                                ),
                              for (final tag in widget.item.tags)
                                _MetadataPill(
                                  label: '#$tag',
                                  color: colorScheme.tertiaryContainer,
                                  textColor: colorScheme.onTertiaryContainer,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.push_pin,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    ),
                  if (widget.showSourceBadge)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.description_outlined, size: 14),
                      label: Text(
                        widget.item.document.title.isNotEmpty
                            ? widget.item.document.title
                            : widget.item.document.relPath,
                        style: const TextStyle(fontSize: 11),
                      ),
                      tooltip: 'Peek surrounding context in ${widget.item.document.relPath}',
                      onPressed: () => _openSourcePeekSheet(context),
                    ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.edit_note,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // In-place editor panel (D-19: edit without jumping to source note!)
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: const InputDecoration(
                            labelText: 'Edit task in-place (updates source .md file)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _saveEditedText(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: _saveEditedText,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Indented Markdown note body / comment editor (D-14, D-18)
                  TextField(
                    controller: _childNoteController,
                    minLines: 1,
                    maxLines: 3,
                    onChanged: (_) => _loadedChildNote = true,
                    decoration: const InputDecoration(
                      labelText:
                          'Indented note / comment (stored beneath line in .md)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Quick Date & Context chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('📅 Today'),
                        onPressed: () => _setQuickDate(DateTime.now()),
                      ),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('📅 Tomorrow'),
                        onPressed: () => _setQuickDate(
                          DateTime.now().add(const Duration(days: 1)),
                        ),
                      ),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('📅 +1 Week'),
                        onPressed: () => _setQuickDate(
                          DateTime.now().add(const Duration(days: 7)),
                        ),
                      ),
                      if (widget.item.entry.dueDate != null)
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text('Clear 📅'),
                          onPressed: () => _setQuickDate(null),
                        ),
                      for (final ctx in <String>{
                        'computer',
                        'phone',
                        'errands',
                        'home',
                        ...widget.item.contexts,
                      })
                        FilterChip(
                          visualDensity: VisualDensity.compact,
                          label: Text('@$ctx'),
                          selected: widget.item.contexts.contains(ctx),
                          onSelected: (_) => _toggleContext(ctx),
                        ),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('+ @context'),
                        onPressed: () => _promptCustomContext(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ADHD & BuJo/GTD 1-tap actions
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _openTwoMinuteFocusDialog(context),
                        icon: const Icon(Icons.timer_outlined, size: 16),
                        label: const Text('▶ Start 2m'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await ref
                              .read(workspaceStateProvider.notifier)
                              .togglePinToday(widget.item.uniqueKey);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Today\'s Top 3 Focus Shelf already has 3 items. Unpin one first to keep focus calm!',
                                ),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                          size: 16,
                        ),
                        label: Text(isPinned ? 'Unpin Today' : 'Pin Top 3'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _migrateToToday,
                        icon: const Icon(Icons.keyboard_arrow_right, size: 16),
                        label: const Text('Migrate → Today'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _moveToSomeday,
                        icon: const Icon(Icons.spa_outlined, size: 16),
                        label: const Text('Someday'),
                      ),
                      TextButton.icon(
                        onPressed: _dropTask,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Drop'),
                      ),
                      const Tooltip(
                        message:
                            'Time-based Snooze depends on native reminders infrastructure (Milestone 8). Use 📅 Tomorrow / +1 Week to reschedule now.',
                        child: OutlinedButton(
                          onPressed: null,
                          child: Text('Snooze (M8)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MetadataPill extends StatelessWidget {
  const _MetadataPill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Peek sheet showing the surrounding lines of the source `.md` file (`D-19`),
/// with an explicit button to jump to the full document if desired.
class _SourceContextPeekSheet extends ConsumerWidget {
  const _SourceContextPeekSheet({required this.item});

  final IndexedEntryWithDocument item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawTextAsync = ref.watch(documentRawTextProvider(item.document.relPath));
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.document.title.isNotEmpty
                            ? item.document.title
                            : item.document.relPath,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        '${item.document.relPath} · line ${item.entry.lineIndex + 1}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push(
                      '/documents/${item.document.id}',
                      extra: item.document,
                    );
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open Full Note'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            rawTextAsync.when(
              data: (rawText) {
                final doc = MarkdownDocument.parse(rawText);
                final startIdx = (item.entry.lineIndex - 3).clamp(0, doc.lines.length);
                final endIdx = (item.entry.lineIndex + 5).clamp(0, doc.lines.length);
                final snippetLines = doc.lines.sublist(startIdx, endIdx);

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in snippetLines)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 4,
                          ),
                          color: line.index == item.entry.lineIndex
                              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                              : null,
                          child: Text(
                            '${(line.index + 1).toString().padLeft(2)}: ${doc.rawText.substring(line.span.start, line.span.end)}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Could not read file context: $err'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ADHD 2-Minute Initiation Timer (`E-05`, `E-06`) & Task Breakdown (`E-04`).
/// Designed with gentle, non-punitive transition cues (`P-04`).
class _TwoMinuteFocusDialog extends ConsumerStatefulWidget {
  const _TwoMinuteFocusDialog({required this.item});

  final IndexedEntryWithDocument item;

  @override
  ConsumerState<_TwoMinuteFocusDialog> createState() =>
      _TwoMinuteFocusDialogState();
}

class _TwoMinuteFocusDialogState extends ConsumerState<_TwoMinuteFocusDialog> {
  static const int _initialSeconds = 120; // 2 minutes
  int _remainingSeconds = _initialSeconds;
  int _totalSeconds = _initialSeconds;
  Timer? _timer;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _running = false;
        });
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _extendTimer(int minutes) {
    setState(() {
      final added = minutes * 60;
      _remainingSeconds += added;
      _totalSeconds = _remainingSeconds;
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mins = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final progress = _totalSeconds > 0
        ? (_remainingSeconds / _totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    return AlertDialog(
      title: const Text('🎯 2-Minute Focus Sprint'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.item.entry.textContent,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                  ),
                  Text(
                    '$mins:$secs',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _remainingSeconds == 0
                  ? '2 minutes complete! Keep rolling for 15m, mark done, or pause here — starting is a win.'
                  : 'Permission to stop after 2 minutes. Just do the smallest first physical step.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        if (_remainingSeconds == 0)
          OutlinedButton(
            onPressed: () => _extendTimer(15),
            child: const Text('+15 min'),
          )
        else
          TextButton(
            onPressed: () {
              if (_running) {
                _timer?.cancel();
                setState(() => _running = false);
              } else {
                _startTimer();
              }
            },
            child: Text(_running ? 'Pause' : 'Resume'),
          ),
        FilledButton.tonalIcon(
          onPressed: () async {
            await ref.read(vaultMutationProvider).setTaskStateInPlace(
              widget.item,
              TaskStateKind.completed,
            );
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Mark Done'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
