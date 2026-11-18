import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/index/app_services.dart';
import '../../core/index/index_providers.dart';
import '../../shared/widgets/metadata_badge.dart';
import '../document_detail/document_detail_screen.dart';

/// Full-Text Search and Quick Switcher Dialog with facet filters (`N-03`, `N-04`, `N-05`, `FR-06`).
class SearchDialog extends ConsumerStatefulWidget {
  const SearchDialog({
    this.initialQuery = '',
    this.initialTag,
    this.initialContext,
    this.initialDocTypeFilter = 'all',
    super.key,
  });

  final String initialQuery;
  final String? initialTag;
  final String? initialContext;
  final String initialDocTypeFilter;

  static Future<void> show(
    BuildContext context, {
    String initialQuery = '',
    String? initialTag,
    String? initialContext,
    String initialDocTypeFilter = 'all',
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => SearchDialog(
        initialQuery: initialQuery,
        initialTag: initialTag,
        initialContext: initialContext,
        initialDocTypeFilter: initialDocTypeFilter,
      ),
    );
  }

  @override
  ConsumerState<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends ConsumerState<SearchDialog> {
  late final TextEditingController _queryCtrl;
  late String _selectedFacet;
  String? _selectedTag;
  String? _selectedContext;
  bool _tasksOnly = false;

  List<SearchResultItem>? _results;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController(text: widget.initialQuery);
    _selectedFacet = widget.initialDocTypeFilter;
    _selectedTag = widget.initialTag;
    _selectedContext = widget.initialContext;
    _executeSearch();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _executeSearch() async {
    setState(() => _isLoading = true);
    final services = await ref.read(appServicesProvider.future);
    if (services == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final query = _queryCtrl.text.trim();
    final results = await services.indexService.searchVault(
      query: query,
      docTypeFilter: _selectedFacet == 'all' ? null : _selectedFacet,
      tagFilter: _selectedTag,
      contextFilter: _selectedContext,
      tasksOnly: _tasksOnly,
    );

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _onFacetSelected(String facet) {
    setState(() {
      _selectedFacet = facet;
      if (facet == 'task') {
        _tasksOnly = true;
      } else {
        _tasksOnly = false;
      }
    });
    _executeSearch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allEntriesAsync = ref.watch(allEntriesWithDocumentsProvider);
    final allEntries = allEntriesAsync.value ?? const [];

    // Extract unique tags and contexts for quick filter chips
    final popularTags = allEntries
        .expand((e) => e.tags)
        .toSet()
        .take(6)
        .toList();
    final popularContexts = allEntries
        .expand((e) => e.contexts)
        .toSet()
        .take(6)
        .toList();

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Row(
        children: [
          const Icon(Icons.search, size: 22),
          const SizedBox(width: 8),
          const Text('Search & Quick Switcher'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Field
            TextField(
              controller: _queryCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Type to search notes, tasks, or logs...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _queryCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _queryCtrl.clear();
                          _executeSearch();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _executeSearch(),
            ),
            const SizedBox(height: 8),

            // Facet Filter Chips (N-05)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Notes', 'note'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Projects', 'project'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Collections', 'collection'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Logs', 'log'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Reference', 'reference'),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Tasks Only'),
                    selected: _tasksOnly,
                    onSelected: (selected) {
                      setState(() => _tasksOnly = selected);
                      _executeSearch();
                    },
                  ),
                ],
              ),
            ),

            // Dynamic Tag & Context Chips
            if (popularTags.isNotEmpty || popularContexts.isNotEmpty) ...[
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tag in popularTags) ...[
                      FilterChip(
                        label: Text('#$tag'),
                        selected: _selectedTag == tag,
                        visualDensity: VisualDensity.compact,
                        onSelected: (sel) {
                          setState(() => _selectedTag = sel ? tag : null);
                          _executeSearch();
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                    for (final ctx in popularContexts) ...[
                      FilterChip(
                        label: Text('@$ctx'),
                        selected: _selectedContext == ctx,
                        visualDensity: VisualDensity.compact,
                        onSelected: (sel) {
                          setState(() => _selectedContext = sel ? ctx : null);
                          _executeSearch();
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                  ],
                ),
              ),
            ],
            const Divider(height: 16),

            // Results List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (_results == null || _results!.isEmpty)
                  ? Center(
                      child: Text(
                        _queryCtrl.text.isEmpty &&
                                _selectedTag == null &&
                                _selectedContext == null
                            ? 'No documents or tasks matching current filter.'
                            : 'No results found.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results!.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _results![index];
                        final icon = switch (item.matchType) {
                          'task' => Icons.check_box_outlined,
                          'title' => Icons.title,
                          'entry' => Icons.short_text,
                          _ => _iconForDocType(item.document.docType),
                        };

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            icon,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(
                            item.document.title.isNotEmpty
                                ? item.document.title
                                : item.document.relPath,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.document.relPath,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              if (item.snippet != item.document.title)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    item.snippet,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: MetadataBadge(
                            label: item.matchType == 'task'
                                ? 'task'
                                : item.document.docType,
                            fontSize: 10,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => DocumentDetailScreen(
                                  document: item.document,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String facet) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFacet == facet,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => _onFacetSelected(facet),
    );
  }

  IconData _iconForDocType(String docType) {
    return switch (docType) {
      'project' => Icons.folder_outlined,
      'collection' => Icons.collections_bookmark_outlined,
      'dailyLog' => Icons.today,
      'weeklyLog' => Icons.calendar_view_week,
      'monthlyLog' => Icons.calendar_month,
      'quarterlyLog' => Icons.date_range,
      'yearlyLog' => Icons.event_note,
      'reference' => Icons.menu_book,
      _ => Icons.article_outlined,
    };
  }
}
