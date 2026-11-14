import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/vault/starter_vault_seeder.dart';
import '../../core/vault/vault_path_provider.dart';
import '../../core/vault/vault_setup.dart';
import '../../core/workspace/workspace_state.dart';

/// First-run intro screen (`A-06`, `P-07`, `P-11`).
///
/// Introduces Citrine's 4 main areas:
/// 1. "Today"
/// 2. "Actions & Inbox"
/// 3. "Horizons & Review"
/// 4. "Notes & Index"
///
/// Provides 3 primary entry actions:
/// - "Get Started": provisions a Starter Vault with useful, non-filler learning
///   tasks, projects, collections, and guides at the platform default location.
/// - "Open an existing Vault": selects an existing directory or Obsidian vault.
/// - "Create a blank vault": prompts for a vault name, lets the user select
///   a parent folder, and creates `<chosen-location>/<vault-name>`.
class VaultSetupScreen extends ConsumerStatefulWidget {
  const VaultSetupScreen({super.key});

  @override
  ConsumerState<VaultSetupScreen> createState() => _VaultSetupScreenState();
}

class _VaultSetupScreenState extends ConsumerState<VaultSetupScreen> {
  bool _busy = false;
  String? _busyMessage;
  String? _error;

  Future<void> _onGetStarted() async {
    setState(() {
      _busy = true;
      _busyMessage = 'Creating your Starter Vault...';
      _error = null;
    });

    try {
      final vaultPath = await provisionStarterVaultDirectory();
      final primaryTaskKey = await StarterVaultSeeder.seedStarterVault(
        vaultPath,
      );

      if (primaryTaskKey != null) {
        await ref
            .read(workspaceStateProvider.notifier)
            .setTopThreePinnedKeys([primaryTaskKey]);
      }

      await ref.read(vaultPathProvider.notifier).setVaultPath(vaultPath);
    } catch (e) {
      setState(() => _error = 'Could not set up Starter Vault: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onOpenExistingVault() async {
    setState(() {
      _busy = true;
      _busyMessage = 'Opening vault...';
      _error = null;
    });

    try {
      if (isDesktopVaultPlatform) {
        final path = await pickVaultDirectory();
        if (path == null) {
          setState(() => _busy = false);
          return;
        }
        await ref.read(vaultPathProvider.notifier).setVaultPath(path);
      } else {
        final path = await provisionMobileVaultDirectory();
        await ref.read(vaultPathProvider.notifier).setVaultPath(path);
      }
    } catch (e) {
      setState(() => _error = 'Could not open that folder: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onCreateBlankVault() async {
    final vaultName = await showDialog<String>(
      context: context,
      builder: (ctx) => const _VaultNamePromptDialog(),
    );

    if (vaultName == null || vaultName.trim().isEmpty) return;

    setState(() {
      _busy = true;
      _busyMessage = 'Creating blank vault "$vaultName"...';
      _error = null;
    });

    try {
      String parentPath;
      if (isDesktopVaultPlatform) {
        final chosen = await pickVaultDirectory();
        if (chosen == null) {
          setState(() => _busy = false);
          return; // user cancelled folder picker
        }
        parentPath = chosen;
      } else {
        final appDocs = await getApplicationDocumentsDirectory();
        parentPath = appDocs.path;
      }

      final newVaultPath = await createNamedVaultInDirectory(
        parentDirectoryPath: parentPath,
        vaultName: vaultName,
      );

      await ref.read(vaultPathProvider.notifier).setVaultPath(newVaultPath);
    } catch (e) {
      setState(() => _error = 'Could not create blank vault: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workspace = ref.watch(workspaceStateProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App Icon & Header
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.spa_outlined,
                      size: 36,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to Citrine',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A calm, local-first workspace combining Bullet Journal timelines and '
                    'Getting Things Done clarity over your own plain Markdown files.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // The 4 Main Pillars
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final useTwoColumns = constraints.maxWidth >= 600;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildPillarCard(
                            theme: theme,
                            width: useTwoColumns
                                ? (constraints.maxWidth - 16) / 2
                                : constraints.maxWidth,
                            icon: Icons.wb_sunny_outlined,
                            iconColor: Colors.amber.shade700,
                            title: 'Today',
                            subtitle:
                                'Your daily workspace: scheduled events, '
                                'top priorities, gentle habits, and today\'s notes.',
                          ),
                          _buildPillarCard(
                            theme: theme,
                            width: useTwoColumns
                                ? (constraints.maxWidth - 16) / 2
                                : constraints.maxWidth,
                            icon: Icons.check_circle_outline,
                            iconColor: Colors.teal.shade600,
                            title: 'Actions & Inbox',
                            subtitle:
                                'Capture thoughts fast without filing, clarify your inbox one card at a time, '
                                'and filter Next Actions by @context or Project.',
                          ),
                          _buildPillarCard(
                            theme: theme,
                            width: useTwoColumns
                                ? (constraints.maxWidth - 16) / 2
                                : constraints.maxWidth,
                            icon: Icons.explore_outlined,
                            iconColor: Colors.indigo.shade600,
                            title: 'Plan & Review',
                            subtitle:
                                'Plan across configurable cadences (Daily, Weekly, Monthly, Future) '
                                'with calm daily and weekly review rituals.',
                          ),
                          _buildPillarCard(
                            theme: theme,
                            width: useTwoColumns
                                ? (constraints.maxWidth - 16) / 2
                                : constraints.maxWidth,
                            icon: Icons.menu_book_outlined,
                            iconColor: Colors.deepPurple.shade600,
                            title: 'Notes & Index',
                            subtitle:
                                'Plain-text Markdown notes, on-demand Collections, syntax cheatsheets, '
                                'and [[wikilinks]] that remain 100% owned and readable by you.',
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Optional Cadence Configuration
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Planning & Review Cadences (change anytime in Settings)',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final c in CadenceKind.values)
                                FilterChip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(c.label),
                                  selected: workspace.enabledCadences.contains(
                                    c,
                                  ),
                                  onSelected: (enabled) {
                                    ref
                                        .read(workspaceStateProvider.notifier)
                                        .toggleCadence(c, enabled);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_busy) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(_busyMessage ?? 'Setting up...'),
                      ],
                    ),
                  ] else ...[
                    // Primary Actions
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: _onGetStarted,
                            icon: const Icon(Icons.rocket_launch_outlined),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _onOpenExistingVault,
                            icon: const Icon(Icons.folder_open_outlined),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Open an existing Vault'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _onCreateBlankVault,
                            icon: const Icon(Icons.create_new_folder_outlined),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Create a blank vault'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillarCard({
    required ThemeData theme,
    required double width,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
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
}

class _VaultNamePromptDialog extends StatefulWidget {
  const _VaultNamePromptDialog();

  @override
  State<_VaultNamePromptDialog> createState() => _VaultNamePromptDialogState();
}

class _VaultNamePromptDialogState extends State<_VaultNamePromptDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: 'citrine-vault');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please enter a vault name.');
      return;
    }
    if (text == '.' ||
        text == '..' ||
        text.contains('/') ||
        text.contains(r'\')) {
      setState(() => _error = 'Vault name contains invalid characters.');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create a Blank Vault'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a name for your new vault. A folder with this name will be created inside the location you choose.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Vault folder name',
                hintText: 'e.g. personal-vault',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Choose Location & Create'),
        ),
      ],
    );
  }
}
