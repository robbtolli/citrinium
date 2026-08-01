import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/vault/vault_path_provider.dart';
import '../../core/vault/vault_setup.dart';

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
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Welcome to Citrinium', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(
                  desktop
                      ? 'Choose a folder on disk to use as your vault. '
                          'Citrinium reads and writes plain Markdown files there -- '
                          'nothing is stored anywhere else.'
                      : 'Citrinium keeps your notes as plain Markdown files. '
                          "We'll set up a private folder for your vault on this device.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _busy ? null : (desktop ? _chooseDesktopVault : _continueOnMobile),
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
