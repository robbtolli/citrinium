import 'dart:async';

import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/index/index_providers.dart';
import '../../core/notifications/notification_service.dart';
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
    final nextIso = await mutations.completeOrAdvanceTask(widget.item);
    if (nextIso != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Completed occurrence! Next scheduled for 📅 $nextIso (🔁 ${widget.item.entry.recurrenceRaw}).',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
      setState(() {
        _expanded = false;
      });
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

  Future<void> _setQuickRecurrence(String? ruleText) async {
    await ref.read(vaultMutationProvider).updateEntryInPlace(
      widget.item,
      recurrence: ruleText,
      clearRecurrence: ruleText == null,
    );
  }

  Future<void> _toggleHabitTag() async {
    final isHabit = widget.item.tags.contains('habit');
    await ref.read(vaultMutationProvider).updateEntryInPlace(
      widget.item,
      addTag: isHabit ? null : 'habit',
      removeTag: isHabit ? 'habit' : null,
      recurrence:
          (!isHabit && widget.item.entry.recurrenceRaw == null)
              ? 'every day'
              : null,
    );
  }

  Future<void> _promptCustomRecurrence(BuildContext context) async {
    final controller = TextEditingController(
      text: widget.item.entry.recurrenceRaw ?? '',
    );
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Recurrence Rule (D-16)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'e.g. every weekday, every 1st Monday, every 2 weeks',
            prefixText: '🔁 ',
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
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (chosen != null && chosen.trim().isNotEmpty) {
      await _setQuickRecurrence(chosen.trim());
    }
  }

  Future<void> _openReminderAndSnoozeDialog(BuildContext context) async {
    final permitted = await ensureContextualNotificationPermission(
      context,
      ref,
    );
    if (!permitted || !context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => _ReminderAndSnoozeDialog(item: widget.item),
    );
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
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parked in Someday / Maybe for when you\'re ready.'),
        ),
      );
    }
  }

  Future<void> _scheduleToFutureLog() async {
    final now = DateTime.now();
    await ref.read(vaultMutationProvider).migrateOrScheduleEntry(
      widget.item,
      targetRelPath: CadenceFiles.futureLogRelPath,
      targetInitialContent: CadenceFiles.defaultContentForCadence(
        CadenceKind.future,
        now,
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheduled to Future Log (future.md).'),
        ),
      );
    }
  }

  Future<void> _promoteToCollection(BuildContext context) async {
    final titleCtrl =
        TextEditingController(text: widget.item.entry.textContent);
    final chosenTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Collection from Item (B-10, D-10)'),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Collection Title',
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
            onPressed: () => Navigator.of(ctx).pop(titleCtrl.text),
            child: const Text('Create Collection'),
          ),
        ],
      ),
    );
    titleCtrl.dispose();
    if (chosenTitle != null && chosenTitle.trim().isNotEmpty) {
      final relPath = await ref
          .read(vaultMutationProvider)
          .createNoteOrProject(
            title: chosenTitle.trim(),
            docType: 'collection',
            promoteFromEntry: widget.item,
          );
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('Created Collection $relPath')),
        );
      }
    }
  }

  Future<void> _cancelTask() async {
    await ref.read(vaultMutationProvider).setTaskStateInPlace(
      widget.item,
      TaskStateKind.cancelled,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancelled task cleanly — one less thing on your plate.'),
        ),
      );
    }
  }

  Future<void> _setTaskState(TaskStateKind state) async {
    await ref.read(vaultMutationProvider).setTaskStateInPlace(
      widget.item,
      state,
    );
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
      case 'in-progress':
      case 'inProgress':
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: colorScheme.primary, width: 1.5),
          ),
          child: CustomPaint(
            painter: _TileHalfFilledPainter(color: colorScheme.primary),
          ),
        );
      case 'waitingFor':
        return Icon(
          Icons.hourglass_top,
          size: 18,
          color: colorScheme.tertiary,
        );
      case 'cancelled':
      case 'dropped':
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.5),
              width: 1.5,
            ),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          ),
          child: Center(
            child: Container(
              width: 9,
              height: 1.5,
              color: colorScheme.outline,
            ),
          ),
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
    final isCancelled = widget.item.isCancelledTask ||
        widget.item.entry.taskState == 'cancelled' ||
        widget.item.entry.taskState == 'dropped';

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
                  ref
                      .read(workspaceStateProvider.notifier)
                      .completeOnboardingStep('in_place_edit');
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
                            decoration: (isDone || isCancelled)
                                ? TextDecoration.lineThrough
                                : null,
                            color: (isDone || isCancelled)
                                ? colorScheme.outline
                                : colorScheme.onSurface,
                          ),
                        ),
                        if (widget.item.entry.dueDate != null ||
                            widget.item.entry.dueTime != null ||
                            widget.item.entry.recurrenceRaw != null ||
                            workspace.snoozedUntil(widget.item.uniqueKey) !=
                                null ||
                            widget.item.contexts.isNotEmpty ||
                            widget.item.tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (widget.item.entry.dueDate != null ||
                                  widget.item.entry.dueTime != null)
                                _MetadataPill(
                                  label:
                                      '📅 ${widget.item.entry.dueDate ?? 'today'}${widget.item.entry.dueTime != null ? ' ⏰ ${widget.item.entry.dueTime}' : ''}',
                                  color: colorScheme.primaryContainer,
                                  textColor: colorScheme.onPrimaryContainer,
                                ),
                              if (widget.item.entry.recurrenceRaw != null)
                                _MetadataPill(
                                  label: '🔁 ${widget.item.entry.recurrenceRaw}',
                                  color: colorScheme.tertiaryContainer,
                                  textColor: colorScheme.onTertiaryContainer,
                                ),
                              if (workspace.snoozedUntil(
                                    widget.item.uniqueKey,
                                  ) !=
                                  null)
                                _MetadataPill(
                                  label: '🔔 Snoozed',
                                  color: colorScheme.secondaryContainer,
                                  textColor: colorScheme.onSecondaryContainer,
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
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          widget.item.document.title.isNotEmpty
                              ? widget.item.document.title
                              : widget.item.document.relPath,
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      tooltip:
                          'Peek surrounding context in ${widget.item.document.relPath}',
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
                        label: const Text('[ ] Open'),
                        onPressed: () => _setTaskState(TaskStateKind.open),
                      ),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('[/] In-Progress'),
                        onPressed: () => _setTaskState(TaskStateKind.inProgress),
                      ),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('[x] Done'),
                        onPressed: () => _setTaskState(TaskStateKind.completed),
                      ),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('[-] Cancel'),
                        onPressed: () => _setTaskState(TaskStateKind.cancelled),
                      ),
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
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('🔁 Daily'),
                        onPressed: () => _setQuickRecurrence('every day'),
                      ),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('🔁 Weekday'),
                        onPressed: () => _setQuickRecurrence('every weekday'),
                      ),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('🔁 Weekly'),
                        onPressed: () => _setQuickRecurrence('every week'),
                      ),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('+ 🔁 Rule'),
                        onPressed: () => _promptCustomRecurrence(context),
                      ),
                      if (widget.item.entry.recurrenceRaw != null)
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text('Clear 🔁'),
                          onPressed: () => _setQuickRecurrence(null),
                        ),
                      FilterChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('#habit'),
                        selected: widget.item.tags.contains('habit'),
                        onSelected: (_) => _toggleHabitTag(),
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
                        onPressed: () => _openReminderAndSnoozeDialog(context),
                        icon: const Icon(
                          Icons.notifications_active_outlined,
                          size: 16,
                        ),
                        label: const Text('⏰ Snooze / Remind'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _migrateToToday,
                        icon: const Icon(Icons.keyboard_arrow_right, size: 16),
                        label: const Text('Migrate → Today'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _scheduleToFutureLog,
                        icon: const Icon(Icons.keyboard_arrow_left, size: 16),
                        label: const Text('Future Log (<)'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _moveToSomeday,
                        icon: const Icon(Icons.spa_outlined, size: 16),
                        label: const Text('Someday'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _promoteToCollection(context),
                        icon: const Icon(
                          Icons.collections_bookmark_outlined,
                          size: 16,
                        ),
                        label: const Text('Collection'),
                      ),
                      TextButton.icon(
                        onPressed: _cancelTask,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Cancel Task'),
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

class _TileHalfFilledPainter extends CustomPainter {
  const _TileHalfFilledPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(1.5, 1.5, (size.width - 3.0) / 2, size.height - 3.0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TileHalfFilledPainter oldDelegate) =>
      oldDelegate.color != color;
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

/// Reminder Lead-Time & Snooze Dialog (`E-08`, `E-10`, `E-12`, `A-03`).
class _ReminderAndSnoozeDialog extends ConsumerStatefulWidget {
  const _ReminderAndSnoozeDialog({required this.item});

  final IndexedEntryWithDocument item;

  @override
  ConsumerState<_ReminderAndSnoozeDialog> createState() =>
      _ReminderAndSnoozeDialogState();
}

class _ReminderAndSnoozeDialogState
    extends ConsumerState<_ReminderAndSnoozeDialog> {
  late TextEditingController _timeCtrl;
  late int _selectedLeadMinutes;

  @override
  void initState() {
    super.initState();
    _timeCtrl = TextEditingController(
      text: widget.item.entry.dueTime ?? '09:00',
    );
    final workspace = ref.read(workspaceStateProvider);
    _selectedLeadMinutes =
        workspace.reminderLeadMinutesByTaskKey[widget.item.uniqueKey] ??
        workspace.defaultReminderLeadMinutes;
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    super.dispose();
  }

  void _applySnooze(Duration offset) {
    final until = DateTime.now().add(offset);
    unawaited(
      ref
          .read(workspaceStateProvider.notifier)
          .snoozeTask(widget.item.uniqueKey, until),
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Snoozed "${widget.item.entry.textContent}" until ${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceStateProvider);
    final snoozedUntil = workspace.snoozedUntil(widget.item.uniqueKey);
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Reminder & Snooze (E-08, E-10, E-12)'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.entry.textContent,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Quick Snooze (E-12, A-03)',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: const Text('Snooze +15m'),
                    onPressed: () =>
                        _applySnooze(const Duration(minutes: 15)),
                  ),
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: const Text('Snooze +1h'),
                    onPressed: () => _applySnooze(const Duration(hours: 1)),
                  ),
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: const Text('Snooze +3h'),
                    onPressed: () => _applySnooze(const Duration(hours: 3)),
                  ),
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: const Text('Tomorrow (+24h)'),
                    onPressed: () => _applySnooze(const Duration(hours: 24)),
                  ),
                  if (snoozedUntil != null)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: const Text('Clear Snooze'),
                      onPressed: () async {
                        await ref
                            .read(workspaceStateProvider.notifier)
                            .clearSnooze(widget.item.uniqueKey);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
              const Divider(height: 24),
              Text(
                'Reminder Time & Lead Offset (E-10)',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _timeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reminder Time (⏰ HH:MM)',
                  hintText: '09:00',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final preset in ReminderLeadTime.presets)
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        preset.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _selectedLeadMinutes == preset.minutesBefore,
                      onSelected: (_) {
                        setState(
                          () => _selectedLeadMinutes = preset.minutesBefore,
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () async {
            final cleanTime = _timeCtrl.text.trim();
            final effectiveDate = widget.item.entry.dueDate ??
                NlDateParser.formatIsoDate(DateTime.now());
            await ref.read(vaultMutationProvider).updateEntryInPlace(
              widget.item,
              dueDate: effectiveDate,
              dueTime: cleanTime.isEmpty ? null : cleanTime,
            );
            await ref
                .read(workspaceStateProvider.notifier)
                .setTaskReminderLeadMinutes(
                  widget.item.uniqueKey,
                  _selectedLeadMinutes,
                );
            if (!context.mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Reminder set for 📅 $effectiveDate ⏰ $cleanTime (${ReminderLeadTime.fromStoredMinutes(_selectedLeadMinutes).label}).',
                ),
              ),
            );
          },
          icon: const Icon(Icons.notifications_active_outlined, size: 16),
          label: const Text('Save Reminder'),
        ),
      ],
    );
  }
}
