/// Permission-scoped capability model and manifest parser for Citrinium plugins.
///
/// Implements PL-02, PL-03, and design.md §5.3.
library;

/// Capabilities declared by plugins in `plugin.json` and reviewed by users at install time (PL-02, PL-03).
enum PluginPermission {
  tasksRead(
    id: 'tasks:read',
    label: 'View tasks',
    description: 'Query and list tasks across notes, logs, and projects.',
  ),
  tasksWrite(
    id: 'tasks:write',
    label: 'Modify tasks',
    description: 'Update task states (done/dropped), advance recurrence, and add new tasks.',
  ),
  notesRead(
    id: 'notes:read',
    label: 'View notes',
    description: 'Read the contents and frontmatter metadata of notes and logs.',
  ),
  notesWrite(
    id: 'notes:write',
    label: 'Modify notes',
    description: 'Edit and update existing Markdown notes and cadence logs.',
  ),
  filesCreateDelete(
    id: 'files:create_delete',
    label: 'Create & delete files',
    description: 'Create new notes/collections or permanently delete files in your vault.',
  ),
  networkFetch(
    id: 'network:fetch',
    label: 'Network access',
    description: 'Send outgoing HTTP/HTTPS requests to external web services.',
  );

  const PluginPermission({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  /// Parses a permission ID string (e.g. `'tasks:read'`). Returns `null` if unrecognized.
  static PluginPermission? tryParse(String value) {
    for (final perm in PluginPermission.values) {
      if (perm.id == value.trim().toLowerCase()) return perm;
    }
    return null;
  }
}

/// Metadata and permissions declaration parsed from `plugin.json` (PL-02, PL-03).
class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    this.author = '',
    this.permissions = const {},
    this.entry = 'main.js',
  });

  /// Unique alphanumeric/dot/dash plugin identifier (e.g. `com.example.weather-context`).
  final String id;

  /// Human-readable plugin name.
  final String name;

  /// Semantic version string (e.g. `1.0.0`).
  final String version;

  /// Brief description of the plugin's purpose.
  final String description;

  /// Author or organization name.
  final String author;

  /// Required capability permissions (PL-02).
  final Set<PluginPermission> permissions;

  /// Main JS entrypoint file relative to the plugin folder (default: `main.js`).
  final String entry;

  /// Parses and validates a `plugin.json` document. Throws [FormatException] if invalid.
  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] as String?;
    if (rawId == null || rawId.trim().isEmpty) {
      throw const FormatException('Plugin manifest missing or empty "id" field');
    }

    final id = rawId.trim();
    final idRegex = RegExp(r'^[a-zA-Z0-9_\-\.]+$');
    if (!idRegex.hasMatch(id)) {
      throw FormatException(
        'Plugin id "$id" contains invalid characters (use alphanumeric, dot, dash, underscore)',
      );
    }

    final name = (json['name'] as String?)?.trim() ?? id;
    final version = (json['version'] as String?)?.trim() ?? '0.1.0';
    final description = (json['description'] as String?)?.trim() ?? '';
    final author = (json['author'] as String?)?.trim() ?? '';
    final entry = (json['entry'] as String?)?.trim().isNotEmpty == true
        ? (json['entry'] as String).trim()
        : 'main.js';

    final permissions = <PluginPermission>{};
    final rawPermissions = json['permissions'];
    if (rawPermissions is List) {
      for (final p in rawPermissions) {
        if (p is String) {
          final perm = PluginPermission.tryParse(p);
          if (perm != null) {
            permissions.add(perm);
          } else {
            // Note: unknown permissions are gracefully ignored or can be stored for future extensibility
          }
        }
      }
    }

    return PluginManifest(
      id: id,
      name: name,
      version: version,
      description: description,
      author: author,
      permissions: permissions,
      entry: entry,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'description': description,
    'author': author,
    'permissions': permissions.map((p) => p.id).toList(),
    'entry': entry,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginManifest &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          version == other.version;

  @override
  int get hashCode => Object.hash(id, version);

  @override
  String toString() => 'PluginManifest($id@$version, name: $name)';
}
