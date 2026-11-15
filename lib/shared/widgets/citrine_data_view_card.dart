import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/index/index_providers.dart';
import '../../core/workspace/workspace_state.dart';
import 'in_place_task_tile.dart';
import 'snapshot_export_dialog.dart';

/// Interactive card rendering a ```` ```citrine ```` data view block (`B-01`).
class CitrineDataViewCard extends ConsumerWidget {
  const CitrineDataViewCard({
    required this.query,
    required this.referenceDate,
    this.onEditBlock,
    this.onToggleSourceMode,
    this.dragHandle,
    super.key,
  });

  final CitrineDataViewQuery query;
  final DateTime referenceDate;
  final VoidCallback? onEditBlock;
  final VoidCallback? onToggleSourceMode;
  final Widget? dragHandle;

  IconData _iconForView(CitrineDataViewPreset view) {
    return switch (view) {
      CitrineDataViewPreset.topFocus => Icons.star_outline_rounded,
      CitrineDataViewPreset.dueToday => Icons.today_outlined,
      CitrineDataViewPreset.createdToday => Icons.add_task_outlined,
      CitrineDataViewPreset.dueThisWeek => Icons.date_range_outlined,
      CitrineDataViewPreset.overdue => Icons.history_outlined,
      CitrineDataViewPreset.schedule ||
      CitrineDataViewPreset.events => Icons.event_outlined,
      CitrineDataViewPreset.projects => Icons.folder_open_outlined,
      CitrineDataViewPreset.habits => Icons.repeat_rounded,
      CitrineDataViewPreset.tasks => Icons.checklist_rounded,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(allEntriesWithDocumentsProvider);
    final workspace = ref.watch(workspaceStateProvider);
    final allEntries = entriesAsync.value ?? const [];
    final pinnedKeys = workspace.topThreePinnedKeys.toSet();

    final items = evaluateCitrineDataView(
      query: query,
      allEntries: allEntries,
      referenceDate: referenceDate,
      pinnedFocusKeys: pinnedKeys,
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ?dragHandle,
                Icon(
                  _iconForView(query.view),
                  size: 18,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    query.resolvedTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined, size: 16),
                  tooltip: 'Export Static Snapshot (.md)',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showSnapshotExportDialog(
                    context,
                    ref,
                    title: query.resolvedTitle,
                    entries: items,
                  ),
                ),
                if (onEditBlock != null)
                  IconButton(
                    icon: const Icon(Icons.tune, size: 16),
                    tooltip: 'Edit Data View Query',
                    visualDensity: VisualDensity.compact,
                    onPressed: onEditBlock,
                  ),
                if (onToggleSourceMode != null)
                  IconButton(
                    icon: const Icon(Icons.code, size: 16),
                    tooltip: 'Source Mode',
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggleSourceMode,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'No items match this view for ${NlDateParser.formatIsoDate(referenceDate)}.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final item in items) InPlaceTaskTile(item: item, dense: true),
          ],
        ),
      ),
    );
  }
}

/// Dialog for inserting or editing a ```` ```citrine ```` data view block (`B-01`).
Future<CitrineDataViewQuery?> showCitrineDataViewPickerDialog(
  BuildContext context, {
  CitrineDataViewQuery? initialQuery,
}) {
  var selectedPreset = initialQuery?.view ?? CitrineDataViewPreset.dueToday;
  var includeOverdue = initialQuery?.includeOverdue ?? true;
  final titleCtrl = TextEditingController(text: initialQuery?.title ?? '');
  final tagCtrl = TextEditingController(text: initialQuery?.tag ?? '');
  final contextCtrl = TextEditingController(text: initialQuery?.context ?? '');

  return showDialog<CitrineDataViewQuery>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Insert Citrine Data View'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a preset view or filter to embed directly in your note:',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CitrineDataViewPreset>(
                initialValue: selectedPreset,
                decoration: const InputDecoration(
                  labelText: 'Data View Type',
                  isDense: true,
                ),
                items: [
                  for (final preset in CitrineDataViewPreset.values)
                    DropdownMenuItem(
                      value: preset,
                      child: Text(preset.defaultTitle),
                    ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedPreset = val);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Custom Title (optional)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tagCtrl,
                decoration: const InputDecoration(
                  labelText: 'Filter by #tag (optional)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contextCtrl,
                decoration: const InputDecoration(
                  labelText: 'Filter by @context (optional)',
                  isDense: true,
                ),
              ),
              if (selectedPreset == CitrineDataViewPreset.dueToday)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include earlier overdue tasks'),
                  value: includeOverdue,
                  onChanged: (val) =>
                      setDialogState(() => includeOverdue = val),
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
            onPressed: () {
              final q = CitrineDataViewQuery(
                view: selectedPreset == CitrineDataViewPreset.dueToday ||
                        selectedPreset == CitrineDataViewPreset.createdToday ||
                        selectedPreset == CitrineDataViewPreset.dueThisWeek ||
                        selectedPreset == CitrineDataViewPreset.overdue
                    ? CitrineDataViewPreset.tasks
                    : selectedPreset,
                filter: selectedPreset == CitrineDataViewPreset.dueToday ||
                        selectedPreset == CitrineDataViewPreset.createdToday ||
                        selectedPreset == CitrineDataViewPreset.dueThisWeek ||
                        selectedPreset == CitrineDataViewPreset.overdue
                    ? selectedPreset.id
                    : null,
                title: titleCtrl.text.trim().isEmpty
                    ? null
                    : titleCtrl.text.trim(),
                tag: tagCtrl.text.trim().isEmpty ? null : tagCtrl.text.trim(),
                context: contextCtrl.text.trim().isEmpty
                    ? null
                    : contextCtrl.text.trim(),
                includeOverdue:
                    selectedPreset == CitrineDataViewPreset.dueToday &&
                    includeOverdue,
              );
              Navigator.of(ctx).pop(q);
            },
            child: const Text('Insert Data View'),
          ),
        ],
      ),
    ),
  );
}
