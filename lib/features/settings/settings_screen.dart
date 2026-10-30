import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/index/index_providers.dart';
import '../../core/vault/vault_path_provider.dart';
import '../../core/workspace/workspace_state.dart';
import '../horizons/horizons_review_screen.dart';

/// Settings screen (`docs/milestones/m0.md` W4): vault path, index stats,
/// and the "Rebuild index" button -- the manual escape hatch that proves
/// exit criterion #4 (deleting/rebuilding the index reconstructs identical
/// state from the files alone) is something a user can actually invoke,
/// not just something covered by a test.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _rebuilding = false;

  Future<void> _rebuildIndex() async {
    setState(() => _rebuilding = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final stats = await rebuildIndex(ref);
      messenger.showSnackBar(
        SnackBar(content: Text('Rebuilt index: ${stats.documentCount} documents')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Rebuild failed: $e')));
    } finally {
      if (mounted) setState(() => _rebuilding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaultPath = ref.watch(vaultPathProvider);
    final statsAsync = ref.watch(indexStatsProvider);
    final workspace = ref.watch(workspaceStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Vault location'),
            subtitle: Text(vaultPath ?? '(none)'),
          ),
          const Divider(),
          statsAsync.when(
            data: (stats) {
              if (stats == null) {
                return const ListTile(title: Text('Index'), subtitle: Text('Not yet built'));
              }
              final lastIndexed = stats.lastIndexedAtMs == null
                  ? 'never'
                  : DateTime.fromMillisecondsSinceEpoch(
                      stats.lastIndexedAtMs!,
                    ).toLocal().toString();
              return Column(
                children: [
                  ListTile(
                    title: const Text('Documents indexed'),
                    trailing: Text('${stats.documentCount}'),
                  ),
                  ListTile(
                    title: const Text('Entries indexed'),
                    trailing: Text('${stats.entryCount}'),
                  ),
                  ListTile(
                    title: const Text('Last indexed'),
                    trailing: Text(lastIndexed),
                  ),
                  ListTile(
                    title: const Text('Parser version'),
                    trailing: Text(stats.parserVersion ?? '(unknown)'),
                  ),
                ],
              );
            },
            loading: () => const ListTile(
              title: Text('Index'),
              trailing: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, stackTrace) =>
                ListTile(title: const Text('Index'), subtitle: Text('Error: $error')),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _rebuilding ? null : _rebuildIndex,
              icon: _rebuilding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Rebuild index'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: () => ref.read(vaultPathProvider.notifier).clear(),
              child: const Text('Choose a different vault'),
            ),
          ),
          const Divider(height: 32),

          // Configurable Planning & Review Cadences (B-12)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Planning & Review Cadences (B-12)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final cadence in CadenceKind.values)
            SwitchListTile(
              title: Text(cadence.label),
              subtitle: Text(cadence.description),
              value: workspace.enabledCadences.contains(cadence),
              onChanged: (enabled) {
                ref
                    .read(workspaceStateProvider.notifier)
                    .toggleCadence(cadence, enabled);
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OutlinedButton.icon(
              onPressed: () => showCadenceTemplatesDialog(context),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Customize Cadence Templates (B-11)'),
            ),
          ),
          const Divider(height: 32),

          // Historical Task Filter Safeguard (A-06)
          SwitchListTile(
            title: const Text('14-Day Historical Task Filter (A-06)'),
            subtitle: const Text(
              'Only surface undated open tasks from the last 14 days in Next Actions so older notes don\'t flood your active lists.',
            ),
            value: workspace.filterOlderUndatedTasks,
            onChanged: (val) {
              ref
                  .read(workspaceStateProvider.notifier)
                  .setHistoricalTaskFilter(filterOlderUndatedTasks: val);
            },
          ),
          const Divider(height: 32),

          // Portable Data Export (P-11, D-15, T-02)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: OutlinedButton.icon(
              onPressed: () => _showOperationalExportDialog(context, workspace),
              icon: const Icon(Icons.download_outlined),
              label: const Text(
                'Export Operational Data (Markdown / JSON — T-02)',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOperationalExportDialog(
    BuildContext context,
    WorkspaceState workspace,
  ) {
    final md = workspace.exportToMarkdown();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Portable Operational Data Export (P-11, T-02)'),
        content: SizedBox(
          width: 480,
          height: 320,
          child: SingleChildScrollView(
            child: SelectableText(
              md,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
