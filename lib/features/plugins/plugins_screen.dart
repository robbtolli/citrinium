import 'dart:convert';
import 'dart:io';

import 'package:citrine_core/citrine_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/plugins/plugin_models.dart';
import '../../core/plugins/plugin_providers.dart';
import '../../core/workspace/workspace_state.dart';
import '../../shared/widgets/metadata_badge.dart';
import 'plugin_consent_dialog.dart';

/// Central management and revocation surface for plugins (PL-01, PL-04, PL-08).
class PluginsScreen extends ConsumerStatefulWidget {
  const PluginsScreen({super.key});

  @override
  ConsumerState<PluginsScreen> createState() => _PluginsScreenState();
}

class _PluginsScreenState extends ConsumerState<PluginsScreen> {
  bool _running = false;

  Future<void> _runPlugin(PluginInfo plugin) async {
    final service = await ref.read(pluginServiceProvider.future);
    if (service == null) return;

    setState(() => _running = true);
    try {
      final result = await service.executePlugin(plugin);
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${plugin.name} ran successfully! ${result.output.isNotEmpty ? "Output: ${result.output}" : ""}',
              ),
              backgroundColor: Colors.green.shade800,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${plugin.name} error: ${result.errorMessage ?? "Unknown failure"}',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _installCommunityPlugin(PluginInfo plugin) async {
    final consent = await PluginConsentDialog.show(context, plugin.manifest);
    if (consent == true) {
      final service = await ref.read(pluginServiceProvider.future);
      if (service == null) return;
      await service.installPluginFromDirectory(
        sourceDir: Directory(plugin.dirPath),
        grantedPermissions: plugin.manifest.permissions,
      );
      ref.invalidate(installedPluginsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${plugin.name} installed with granted permissions!'),
          ),
        );
      }
    }
  }

  Future<void> _revokePlugin(PluginInfo plugin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revoke ${plugin.name}?'),
        content: Text(
          'This will completely uninstall "${plugin.name}" and revoke all its permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke & Uninstall'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final service = await ref.read(pluginServiceProvider.future);
      if (service == null) return;
      await service.revokePlugin(plugin.id);
      ref.invalidate(installedPluginsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revoked and uninstalled ${plugin.name}.')),
        );
      }
    }
  }

  Future<void> _pickAndInstallFolder() async {
    final selectedDir = await getDirectoryPath();
    if (selectedDir == null || !mounted) return;

    final dir = Directory(selectedDir);
    final manifestFile = File('${dir.path}/plugin.json');
    if (!manifestFile.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected folder does not contain a plugin.json file.'),
        ),
      );
      return;
    }

    try {
      final json = File('${dir.path}/plugin.json').readAsStringSync();
      final manifest = PluginManifest.fromJson(
        // ignore: avoid_dynamic_calls
        Map<String, dynamic>.from(jsonDecode(json) as Map),
      );

      final consent = await PluginConsentDialog.show(context, manifest);
      if (consent == true && mounted) {
        final service = await ref.read(pluginServiceProvider.future);
        if (service == null) return;
        await service.installPluginFromDirectory(
          sourceDir: dir,
          grantedPermissions: manifest.permissions,
        );
        ref.invalidate(installedPluginsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Installed ${manifest.name}!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to read plugin: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final corePlugins = ref.watch(corePluginsProvider);
    final communityPluginsAsync = ref.watch(installedPluginsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugins & Extensions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Install Plugin from Folder',
            onPressed: _pickAndInstallFolder,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header info banner
          Card(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.security,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QuickJS Sandboxed Architecture',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Community plugins execute in pure-bytecode QuickJS engines without filesystem or OS access. Only capabilities you explicitly grant are exposed via the Citrine host bridge.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 1. Built-In Core Plugins (PL-08)
          Text(
            'Core Built-In Plugins',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Built-in system workflows that run in-process without sandboxing overhead.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final core in corePlugins)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: SwitchListTile(
                secondary: const Icon(Icons.settings_suggest_outlined),
                title: Text(
                  core.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(core.description),
                value: core.isEnabled,
                onChanged: (enabled) {
                  ref
                      .read(workspaceStateProvider.notifier)
                      .toggleCorePlugin(core.id, enabled);
                },
              ),
            ),
          const Divider(height: 32),

          // 2. Community Sandboxed Plugins (PL-01, PL-04)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Community Plugins',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sandboxed JavaScript plugins in .citrine/plugins/',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickAndInstallFolder,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Install from Folder'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          communityPluginsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) =>
                Center(child: Text('Error loading plugins: $err')),
            data: (plugins) {
              if (plugins.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.extension_off_outlined,
                            size: 40,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          const Text('No community plugins discovered.'),
                          const SizedBox(height: 4),
                          Text(
                            'Click "Install from Folder" to import a plugin package.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (final plugin in plugins)
                    Card(
                      key: ValueKey('plugin_card_${plugin.id}'),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: const Icon(Icons.extension, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        plugin.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        '${plugin.id} • v${plugin.version}${plugin.author.isNotEmpty ? " • by ${plugin.author}" : ""}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: plugin.isEnabled,
                                  onChanged: plugin.installedAtMs > 0
                                      ? (val) async {
                                          await ref
                                              .read(
                                                workspaceStateProvider.notifier,
                                              )
                                              .togglePlugin(plugin.id, val);
                                          ref.invalidate(
                                            installedPluginsProvider,
                                          );
                                        }
                                      : null,
                                ),
                              ],
                            ),
                            if (plugin.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                plugin.description,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Permissions:',
                                  style: theme.textTheme.labelSmall,
                                ),
                                if (plugin.manifest.permissions.isEmpty)
                                  const MetadataBadge(label: 'None')
                                else
                                  for (final perm
                                      in plugin.manifest.permissions)
                                    MetadataBadge(
                                      icon: plugin.hasPermission(perm)
                                          ? Icons.check
                                          : Icons.lock_outline,
                                      iconColor: plugin.hasPermission(perm)
                                          ? Colors.green
                                          : Colors.grey,
                                      label: perm.id,
                                    ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (plugin.installedAtMs == 0) ...[
                                  FilledButton.tonalIcon(
                                    key: ValueKey('install_btn_${plugin.id}'),
                                    onPressed: () =>
                                        _installCommunityPlugin(plugin),
                                    icon: const Icon(Icons.download, size: 16),
                                    label: const Text('Review & Install'),
                                  ),
                                ] else ...[
                                  OutlinedButton.icon(
                                    key: ValueKey('run_btn_${plugin.id}'),
                                    onPressed: _running || !plugin.isEnabled
                                        ? null
                                        : () => _runPlugin(plugin),
                                    icon: const Icon(
                                      Icons.play_arrow,
                                      size: 16,
                                    ),
                                    label: const Text('Run'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    key: ValueKey('revoke_btn_${plugin.id}'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: theme.colorScheme.error,
                                    ),
                                    onPressed: () => _revokePlugin(plugin),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                    ),
                                    label: const Text('Revoke & Uninstall'),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
