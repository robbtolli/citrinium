import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/index/index_providers.dart';

enum IndexFilterKind {
  all('All'),
  notes('Notes'),
  reference('Reference'),
  projects('Projects'),
  collections('Collections'),
  logs('Logs');

  const IndexFilterKind(this.label);
  final String label;
}

/// Pillar 4 of the Hybrid Dual-Track UX (`design.md` §6.2):
/// Auto-generated BuJo Index (`B-04`), Collections (`B-10`, `D-10`),
/// Reference Notes (`N-01`, `D-07`), and Search (`N-03`).
class DocumentListScreen extends ConsumerStatefulWidget {
  const DocumentListScreen({
    this.embeddedInShell = false,
    super.key,
  });

  final bool embeddedInShell;

  @override
  ConsumerState<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends ConsumerState<DocumentListScreen> {
  IndexFilterKind _filter = IndexFilterKind.all;
  String _searchQuery = '';

  bool _matchesFilter(Document doc) {
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      final matchesTitle = doc.title.toLowerCase().contains(q);
      final matchesPath = doc.relPath.toLowerCase().contains(q);
      if (!matchesTitle && !matchesPath) return false;
    }
    switch (_filter) {
      case IndexFilterKind.all:
        return true;
      case IndexFilterKind.notes:
        return doc.docType == 'note';
      case IndexFilterKind.reference:
        return doc.docType == 'reference' ||
            doc.relPath == CadenceFiles.referenceRelPath ||
            doc.relPath.startsWith('reference/');
      case IndexFilterKind.projects:
        return doc.docType == 'project' || doc.relPath.startsWith('projects/');
      case IndexFilterKind.collections:
        return doc.docType == 'collection' ||
            doc.relPath.startsWith('collections/');
      case IndexFilterKind.logs:
        return doc.docType.endsWith('Log') ||
            doc.relPath.startsWith('daily/') ||
            doc.relPath.startsWith('weekly/') ||
            doc.relPath.startsWith('monthly/') ||
            doc.relPath.startsWith('quarterly/') ||
            doc.relPath.startsWith('yearly/') ||
            doc.relPath == 'future.md';
    }
  }

  void _openCreateNoteOrCollectionDialog(
    BuildContext context, {
    String initialType = 'note',
  }) {
    final titleCtrl = TextEditingController();
    var selectedType = initialType;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Note or Collection (N-01, B-10)'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'note', label: Text('Note')),
                    ButtonSegment(
                      value: 'collection',
                      label: Text('Collection'),
                    ),
                    ButtonSegment(value: 'project', label: Text('Project')),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (s) =>
                      setDialogState(() => selectedType = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Architecture Ideas or Reading List',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                await ref.read(vaultMutationProvider).createNoteOrProject(
                  title: title,
                  docType: selectedType,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(documentListProvider);
    final allDocs = documentsAsync.value ?? const [];
    final collectionCount = allDocs
        .where(
          (d) =>
              d.docType == 'collection' || d.relPath.startsWith('collections/'),
        )
        .length;
    final projectCount = allDocs
        .where((d) => d.docType == 'project' || d.relPath.startsWith('projects/'))
        .length;
    final logCount = allDocs
        .where(
          (d) =>
              d.docType.endsWith('Log') ||
              d.relPath.startsWith('daily/') ||
              d.relPath.startsWith('weekly/') ||
              d.relPath.startsWith('monthly/') ||
              d.relPath.startsWith('quarterly/') ||
              d.relPath.startsWith('yearly/') ||
              d.relPath == 'future.md',
        )
        .length;

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'Search notes, collections, projects, or logs...',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _openCreateNoteOrCollectionDialog(
                  context,
                  initialType: 'collection',
                ),
                icon: const Icon(Icons.collections_bookmark_outlined, size: 16),
                label: const Text('+ Collection'),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: () => _openCreateNoteOrCollectionDialog(context),
                icon: const Icon(Icons.note_add_outlined, size: 16),
                label: const Text('New Note'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              const Icon(Icons.menu_book_outlined, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Auto-Index (B-04): ${allDocs.length} total · $collectionCount collections · $projectCount projects · $logCount logs',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              for (final f in IndexFilterKind.values) ...[
                FilterChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(f.label),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: documentsAsync.when(
            data: (documents) {
              if (documents.isEmpty) {
                return const Center(child: Text('No notes in this vault yet.'));
              }
              final filtered = documents.where(_matchesFilter).toList();
              if (filtered.isEmpty) {
                return const Center(child: Text('No matching documents.'));
              }
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final document = filtered[index];
                  return ListTile(
                    title: Text(
                      document.title.isEmpty
                          ? document.relPath
                          : document.title,
                    ),
                    subtitle: Text('${document.relPath} · ${document.docType}'),
                    onTap: () => context.push(
                      '/documents/${document.id}',
                      extra: document,
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: Text('Could not load documents: $error')),
          ),
        ),
      ],
    );

    if (widget.embeddedInShell) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Citrinium'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: content,
    );
  }
}
