import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/index/index_providers.dart';
import '../../core/vault/vault_path_provider.dart';
import '../../core/workspace/workspace_state.dart';
import '../../shared/widgets/citrine_help_sheet.dart';
import '../../shared/widgets/planning_review_ritual_sheet.dart';
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

  String _dayName(int day) => switch (day) {
        1 => 'Monday',
        2 => 'Tuesday',
        3 => 'Wednesday',
        4 => 'Thursday',
        5 => 'Friday',
        6 => 'Saturday',
        _ => 'Sunday',
      };

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
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showCadenceTemplatesDialog(context),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Customize Cadence Templates (B-11)'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => showProcessCustomizerDialog(context),
                  icon: const Icon(Icons.auto_fix_high_outlined),
                  label: const Text('Planning & Review Process Studio'),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Progressive Planning & Review Guidance'),
            subtitle: Text(
              workspace.guidanceEnabled
                  ? 'Active (${workspace.learningStage.title}) — introduces rituals progressively and auto-collapses coach tips after 3 uses.'
                  : 'Guidance disabled — Citrine stays out of the way so you can run your own planning & review process.',
            ),
            value: workspace.guidanceEnabled,
            onChanged: (enabled) async {
              ref
                  .read(workspaceStateProvider.notifier)
                  .setGuidanceEnabled(enabled);
              await ref
                  .read(vaultMutationProvider)
                  .syncPortableProcessConfigToVault();
            },
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

          // Help & Starter Guides (A-06)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Field Guide & Learning (A-06)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Citrine Field Guide & Cheat Sheet'),
            subtitle: const Text(
              'Browse 4 Pillars, workflow recipes, and syntax guides',
            ),
            onTap: () => showCitrineHelpSheet(context),
          ),
          SwitchListTile(
            title: const Text('Show Getting Started Checklist on Today'),
            subtitle: const Text(
              'Displays a learning checklist card at the top of Today',
            ),
            value: !workspace.onboardingChecklistDismissed,
            onChanged: (visible) {
              ref
                  .read(workspaceStateProvider.notifier)
                  .dismissOnboardingChecklist(dismissed: !visible);
            },
          ),
          const Divider(height: 32),

          // Weekly Review Reminder (R-05)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Weekly Review Reminder (R-05)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SwitchListTile(
            title: const Text('Weekly Review Reminder'),
            subtitle: const Text(
              'Gentle reminder to start your review. Missing it does not punish you or break any streaks (R-05, P-04).',
            ),
            value: workspace.weeklyReviewReminderEnabled,
            onChanged: (enabled) {
              ref
                  .read(workspaceStateProvider.notifier)
                  .configureWeeklyReviewReminder(enabled: enabled);
            },
          ),
          if (workspace.weeklyReviewReminderEnabled) ...[
            ListTile(
              title: const Text('Reminder Schedule'),
              subtitle: Text(
                'Every ${_dayName(workspace.weeklyReviewReminderDay)} at ${workspace.weeklyReviewReminderTime}',
              ),
              trailing: PopupMenuButton<int>(
                icon: const Icon(Icons.schedule),
                onSelected: (day) {
                  ref
                      .read(workspaceStateProvider.notifier)
                      .configureWeeklyReviewReminder(
                        enabled: true,
                        day: day,
                      );
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 7, child: Text('Sunday at 17:00')),
                  const PopupMenuItem(value: 5, child: Text('Friday at 16:00')),
                  const PopupMenuItem(value: 1, child: Text('Monday at 09:00')),
                ],
              ),
            ),
          ],
          const Divider(height: 32),

          // Plugins & Extensions (PL-01, PL-04, PL-08)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Plugins & Extensions (PL-01)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.extension_outlined),
            title: const Text('Plugin Manager (QuickJS Sandbox)'),
            subtitle: const Text(
              'Manage core workflows and sandboxed community plugins (PL-01–PL-08)',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/plugins'),
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
