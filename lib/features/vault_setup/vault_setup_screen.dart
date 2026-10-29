import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/vault/vault_path_provider.dart';
import '../../core/vault/vault_setup.dart';
import '../../core/workspace/workspace_state.dart';

/// First-run vault selection (`docs/milestones/m0.md` W4): a real directory
/// picker on desktop, an auto-provisioned app-documents folder on mobile
/// (see `vault_setup.dart`'s doc comments for the "why" behind each). Kept
/// deliberately calm/minimal per P-07/A-07/A-06 -- one screen, one
/// decision, no setup wizard.
class VaultSetupScreen extends ConsumerStatefulWidget {
  const VaultSetupScreen({super.key});

  @override
  ConsumerState<VaultSetupScreen> createState() => _VaultSetupScreenState();
}

class _VaultSetupScreenState extends ConsumerState<VaultSetupScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _chooseDesktopVault() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final path = await pickVaultDirectory();
      if (path == null) {
        setState(() => _busy = false);
        return; // user cancelled
      }
      await ref.read(vaultPathProvider.notifier).setVaultPath(path);
    } catch (e) {
      setState(() => _error = 'Could not open that folder: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueOnMobile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final path = await provisionMobileVaultDirectory();
      await ref.read(vaultPathProvider.notifier).setVaultPath(path);
    } catch (e) {
      setState(() => _error = 'Could not set up your vault: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopVaultPlatform;
    final workspace = ref.watch(workspaceStateProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome to Citrinium',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  desktop
                      ? 'Choose a new or existing folder (including an Obsidian vault) on disk. '
                          'Citrinium reads and writes clean Markdown files there, and all operational data is 100% exportable.'
                      : 'Citrinium keeps your notes and logs as plain Markdown files. '
                          "We'll set up a folder for your vault on this device.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Planning & Review Cadences (B-12 — change anytime)',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final c in CadenceKind.values)
                              FilterChip(
                                visualDensity: VisualDensity.compact,
                                label: Text(c.label),
                                selected: workspace.enabledCadences.contains(c),
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
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _busy
                      ? null
                      : (desktop ? _chooseDesktopVault : _continueOnMobile),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(desktop ? 'Choose vault folder' : 'Get started'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
