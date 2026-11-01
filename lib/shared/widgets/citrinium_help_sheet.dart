import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/vault/starter_vault_seeder.dart';
import '../../core/vault/vault_path_provider.dart';
import '../../core/workspace/workspace_state.dart';

/// Opens the Citrinium Field Guide & Cheat Sheet bottom sheet (`A-06`, `P-07`).
Future<void> showCitriniumHelpSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _CitriniumHelpSheet(),
  );
}

class _CitriniumHelpSheet extends ConsumerStatefulWidget {
  const _CitriniumHelpSheet();

  @override
  ConsumerState<_CitriniumHelpSheet> createState() =>
      _CitriniumHelpSheetState();
}

class _CitriniumHelpSheetState extends ConsumerState<_CitriniumHelpSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _addingGuides = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addGuidesToVault() async {
    final vaultPath = ref.read(vaultPathProvider);
    if (vaultPath == null) return;

    setState(() => _addingGuides = true);
    try {
      await StarterVaultSeeder.seedGuidesOnly(vaultPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Added Citrinium starter guides to your vault in guides/ and reference.md!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add guides: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _addingGuides = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workspace = ref.watch(workspaceStateProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                children: [
                  const Icon(Icons.help_outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Citrinium Field Guide & Help',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Getting Started'),
                  Tab(text: '4 Pillars & Recipes'),
                  Tab(text: 'Syntax Cheat Sheet'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Getting Started Checklist & Guide Adder
                    ListView(
                      children: [
                        Text(
                          'Hands-On Learning Checklist',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try these 5 core interactions to get the hang of Citrinium:',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        _buildChecklistTile(
                          id: 'quick_capture',
                          title: 'Capture a thought with Quick Capture',
                          subtitle:
                              'Type in the bottom bar with a date like "tomorrow at 10am @computer"',
                          workspace: workspace,
                        ),
                        _buildChecklistTile(
                          id: 'focus_shelf_pin',
                          title: 'Pin a task to Today\'s Top 3',
                          subtitle:
                              'Tap the pin icon on any task to keep your daily focus clear without overwhelm',
                          workspace: workspace,
                        ),
                        _buildChecklistTile(
                          id: 'in_place_edit',
                          title: 'Edit in-place & try a 2m Sprint',
                          subtitle:
                              'Click any task in a list to expand inline controls or defeat initiation friction',
                          workspace: workspace,
                        ),
                        _buildChecklistTile(
                          id: 'clarify_inbox',
                          title: 'Clarify an item from your Inbox',
                          subtitle:
                              'Go to Actions & Inbox and route items one decision at a time',
                          workspace: workspace,
                        ),
                        _buildChecklistTile(
                          id: 'explore_guides',
                          title: 'Explore notes, collections, & wiki links',
                          subtitle:
                              'Open Notes & Index to browse reference notes and collections',
                          workspace: workspace,
                        ),
                        const Divider(height: 24),
                        SwitchListTile(
                          dense: true,
                          title: const Text('Show Getting Started card on Today'),
                          subtitle: const Text(
                            'Displays a progress checklist banner at the top of Today\'s Combined View',
                          ),
                          value: !workspace.onboardingChecklistDismissed,
                          onChanged: (visible) {
                            ref
                                .read(workspaceStateProvider.notifier)
                                .dismissOnboardingChecklist(dismissed: !visible);
                          },
                        ),
                        const Divider(height: 24),
                        Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.library_books_outlined,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Add Citrinium Guides to Vault',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Writes "guides/getting-started.md", "guides/bujo-and-gtd-guide.md", '
                                  '"guides/markdown-cheatsheet.md", and "reference.md" directly into your active vault. '
                                  'Won\'t overwrite any existing notes.',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                FilledButton.tonalIcon(
                                  onPressed:
                                      _addingGuides ? null : _addGuidesToVault,
                                  icon: _addingGuides
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.file_download_outlined,
                                          size: 18,
                                        ),
                                  label: const Text('Add Guides to Vault'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Tab 2: 4 Pillars & Workflow Recipes
                    ListView(
                      children: [
                        _buildSectionHeader('1. ☀️ Today'),
                        _buildRecipeCard(
                          title: 'Morning Calibration (2 mins)',
                          steps: [
                            'Open Today: scan hard-landscape events (meetings/appointments).',
                            'Pin up to 3 priority tasks to the Top-3 Focus Shelf.',
                            'Check in on recurring daily habits (stretching, water) using non-punitive rhythm dots.',
                          ],
                        ),
                        _buildRecipeCard(
                          title: 'Overcome Initiation Paralysis',
                          steps: [
                            'Tap any task to expand its in-place editor.',
                            'Click the "⏱️ 2m Sprint" button to commit to just 120 seconds of work.',
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildSectionHeader('2. ✅ Actions & Inbox'),
                        _buildRecipeCard(
                          title: 'Capture Freely, Clarify Later',
                          steps: [
                            'Use the Quick Capture bar anytime. Use the sticky [ Inbox | Today ] toggle to choose destination.',
                            'When ready, open Actions & Inbox and tap "Clarify". Decide in 1 click: Done Now, Next Action, Project, Waiting For, or Someday.',
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildSectionHeader('3. 🧭 Horizons & Review'),
                        _buildRecipeCard(
                          title: 'Forgiving Migration (Daily & Weekly)',
                          steps: [
                            'At day\'s end, tap "Daily Migration" to triage open tasks into Today, Scheduled, or Dropped without guilt.',
                            'Configure cadences (Daily, Weekly, Monthly, Future Log) to match your natural planning rhythm.',
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildSectionHeader('4. 📓 Notes & Index'),
                        _buildRecipeCard(
                          title: 'Collections & Plain Markdown',
                          steps: [
                            'Create on-demand Collections from any note using [[collections/topic]].',
                            'Everything lives in clean plain text compatible with Obsidian and standard Markdown editors.',
                          ],
                        ),
                      ],
                    ),

                    // Tab 3: Markdown & Rapid-Logging Cheat Sheet
                    ListView(
                      children: [
                        _buildSectionHeader('Rapid-Logging Bullet States'),
                        _buildCodeSnippet(
                          '- [ ] Open Task\n'
                          '- [/] In-Progress Task (half-filled checkbox)\n'
                          '- [x] Completed Task\n'
                          '- [-] Cancelled Task (strikethrough & greyed checkbox)\n'
                          '- [?] Waiting For / Blocked Task\n'
                          '- ○ Hard-Landscape Calendar Event (exact time/date commitment)\n'
                          '- – Note or observation',
                        ),
                        const SizedBox(height: 12),
                        _buildSectionHeader('Metadata Tokens'),
                        _buildCodeSnippet(
                          '📅 YYYY-MM-DD  Due date\n'
                          '⏰ HH:MM       Due time / reminder time\n'
                          '🔁 <rule>     Recurrence (daily, every weekday, every week, every month)\n'
                          '#habit        Tags a task for non-punitive streak & rhythm tracking\n'
                          '@context      GTD Action context (@computer, @home, @errands, @phone)\n'
                          '#tag          Categorical tag\n'
                          '[[wikilink]]  Inter-note link (supports [[note|display name]])',
                        ),
                        const SizedBox(height: 12),
                        _buildSectionHeader('In-Place Editing Everywhere (D-19)'),
                        const Text(
                          'You never need to open raw source files just to change a due date, tag, recurrence rule, or note. '
                          'Simply tap any task anywhere in Citrinium to edit it in-place.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistTile({
    required String id,
    required String title,
    required String subtitle,
    required WorkspaceState workspace,
  }) {
    final completed = workspace.completedOnboardingSteps.contains(id);
    return CheckboxListTile(
      dense: true,
      value: completed,
      title: Text(
        title,
        style: TextStyle(
          decoration: completed ? TextDecoration.lineThrough : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle),
      onChanged: (val) {
        if (val != null) {
          ref
              .read(workspaceStateProvider.notifier)
              .toggleOnboardingStep(id, val);
        }
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildRecipeCard({
    required String title,
    required List<String> steps,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(steps[i])),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeSnippet(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}
