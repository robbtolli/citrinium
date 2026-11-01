import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';

/// All-or-nothing plugin install consent dialog (PL-02, PL-03).
class PluginConsentDialog extends StatelessWidget {
  const PluginConsentDialog({
    super.key,
    required this.manifest,
  });

  final PluginManifest manifest;

  static Future<bool?> show(BuildContext context, PluginManifest manifest) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PluginConsentDialog(manifest: manifest),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasNetwork =
        manifest.permissions.contains(PluginPermission.networkFetch);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.extension_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Install ${manifest.name}?',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ID: ${manifest.id}  •  v${manifest.version}${manifest.author.isNotEmpty ? "  •  by ${manifest.author}" : ""}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (manifest.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  manifest.description,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const Divider(height: 24),
              Text(
                'Requested Permissions (PL-02, PL-03):',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Install is all-or-nothing. Citrine isolates community plugins inside a sandboxed QuickJS runtime with no direct filesystem access; only the granted capabilities below are exposed.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (manifest.permissions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text('No special permissions requested (isolated sandbox only).'),
                    ],
                  ),
                )
              else
                for (final perm in manifest.permissions)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        perm == PluginPermission.networkFetch
                            ? Icons.public
                            : perm == PluginPermission.filesCreateDelete
                                ? Icons.folder_delete_outlined
                                : perm == PluginPermission.tasksWrite
                                    ? Icons.edit_calendar
                                    : perm == PluginPermission.notesWrite
                                        ? Icons.edit_note
                                        : Icons.visibility_outlined,
                        color: perm == PluginPermission.networkFetch ||
                                perm == PluginPermission.filesCreateDelete
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                      title: Text(
                        perm.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(perm.description),
                      trailing: Text(
                        perm.id,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              if (hasNetwork) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.error),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: theme.colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Security Notice: This plugin requests external network access and can communicate with outside servers.',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onErrorContainer,
                          ),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Grant All & Install (PL-03)'),
        ),
      ],
    );
  }
}
