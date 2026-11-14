import 'dart:io';

import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock/app_clock.dart';
import '../../core/index/app_services.dart';

/// Shows a dialog to export [result] to a static Markdown file inside the
/// vault, clearly stating that exported files are static snapshots (`T-02`).
Future<void> showSnapshotExportDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required List<IndexedEntryWithDocument> entries,
}) async {
  final now = ref.read(appClockProvider).now();
  final dateIso = NlDateParser.formatIsoDate(now);
  final slug = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final defaultRelPath =
      'exports/${slug.isEmpty ? 'snapshot' : slug}-$dateIso.md';

  final controller = TextEditingController(text: defaultRelPath);
  try {
    final confirmedPath = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Data View Snapshot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Static snapshot: exported Markdown files are static '
                'snapshots of the current data and will not auto-update '
                'when Citrine data changes.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Vault relative path (.md)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Export Snapshot'),
          ),
        ],
      ),
    );

    if (confirmedPath == null || confirmedPath.isEmpty) return;

    final services = await ref.read(appServicesProvider.future);
    if (services == null || !context.mounted) return;

    final absPath = VaultPath(confirmedPath).toAbsolute(services.vaultPath);
    final file = File(absPath);
    await file.parent.create(recursive: true);

    final markdown = renderDataViewSnapshotMarkdown(
      title: title,
      entries: entries,
      generatedAt: now,
    );
    services.watcher.suppressSelfWrite(VaultPath(confirmedPath));
    await writeVaultFileAtomic(
      file,
      VaultFileContents(text: markdown, hadBom: false),
    );
    await services.indexService.refreshFile(confirmedPath);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Snapshot exported to $confirmedPath')),
      );
    }
  } finally {
    controller.dispose();
  }
}
