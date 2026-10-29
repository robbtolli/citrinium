import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/index/index_providers.dart';
import '../core/workspace/workspace_state.dart';
import '../features/actions/actions_inbox_screen.dart';
import '../features/documents/document_list_screen.dart';
import '../features/horizons/horizons_review_screen.dart';
import '../features/today/today_combined_screen.dart';
import '../shared/widgets/quick_capture_bar.dart';

enum AppPillar {
  today(
    label: 'Today',
    icon: Icons.wb_sunny_outlined,
    selectedIcon: Icons.wb_sunny,
  ),
  actions(
    label: 'Actions & Inbox',
    icon: Icons.check_circle_outline,
    selectedIcon: Icons.check_circle,
  ),
  horizons(
    label: 'Horizons & Review',
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
  ),
  notes(
    label: 'Notes & Index',
    icon: Icons.library_books_outlined,
    selectedIcon: Icons.library_books,
  );

  const AppPillar({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The Hybrid Dual-Track application shell (`design.md` §6.2):
/// - 4 Primary Pillars: Today, Actions & Inbox, Horizons & Review, Notes & Index
/// - Responsive layout (NavigationRail on wide desktop, NavigationBar on narrow/mobile)
/// - `🕒 Recent` Views & Documents switcher (`N-04`, `A-08`)
/// - `🔍 Quick Switcher` (`N-04`, `N-03`)
/// - Persistent bottom `QuickCaptureBar` with sticky `[ Inbox | Today ]` toggle (`C-01`)
class AppShellScaffold extends ConsumerStatefulWidget {
  const AppShellScaffold({
    this.initialPillar = AppPillar.today,
    super.key,
  });

  final AppPillar initialPillar;

  @override
  ConsumerState<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends ConsumerState<AppShellScaffold> {
  late AppPillar _pillar;
  bool _checkedTwoHourRestore = false;

  @override
  void initState() {
    super.initState();
    _pillar = widget.initialPillar;
  }

  void _checkTwoHourSessionRestore(
    WorkspaceState workspace,
    List<Document> docs,
  ) {
    if (_checkedTwoHourRestore) return;
    _checkedTwoHourRestore = true;

    final now = DateTime.now();
    final recent = workspace.mostRecentItem;
    if (recent != null && workspace.isWithinTwoHourWindow(now)) {
      final doc = docs.where((d) => d.relPath == recent.relPath).firstOrNull;
      if (doc != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Session active (<2h ago): ${recent.displayLabel}',
              ),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () {
                  context.push('/documents/${doc.id}', extra: doc);
                },
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        });
      }
    }
  }

  void _openRecentSwitcher(BuildContext context, List<Document> allDocs) {
    final workspace = ref.read(workspaceStateProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Views & Documents (Pick up where you left off)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (workspace.recentItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No recently opened documents yet.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: workspace.recentItems.length,
                    itemBuilder: (context, index) {
                      final r = workspace.recentItems[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.description_outlined),
                        title: Text(r.displayLabel),
                        subtitle: Text('${r.relPath} · ${r.docType}'),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          final target = allDocs
                              .where((d) => d.relPath == r.relPath)
                              .firstOrNull;
                          if (target != null) {
                            context.push(
                              '/documents/${target.id}',
                              extra: target,
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openQuickSwitcherDialog(BuildContext context, List<Document> allDocs) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _QuickSwitcherDialog(allDocs: allDocs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceStateProvider);
    final docsAsync = ref.watch(documentListProvider);
    final allDocs = docsAsync.value ?? const [];

    if (docsAsync.hasValue) {
      _checkTwoHourSessionRestore(workspace, allDocs);
    }

    final isWide = MediaQuery.of(context).size.width >= 760;

    final bodyContent = switch (_pillar) {
      AppPillar.today => const TodayCombinedScreen(),
      AppPillar.actions => const ActionsInboxScreen(),
      AppPillar.horizons => const HorizonsReviewScreen(),
      AppPillar.notes => const DocumentListScreen(embeddedInShell: true),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Citrinium'),
        actions: [
          // Recent Views / Documents switcher (N-04, A-08)
          TextButton.icon(
            onPressed: () => _openRecentSwitcher(context, allDocs),
            icon: const Icon(Icons.history, size: 18),
            label: Text(
              workspace.recentItems.isEmpty
                  ? 'Recent'
                  : 'Recent (${workspace.recentItems.length})',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Quick Switcher & Search (N-04)',
            onPressed: () => _openQuickSwitcherDialog(context, allDocs),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isWide
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _pillar.index,
                        labelType: NavigationRailLabelType.all,
                        onDestinationSelected: (idx) {
                          setState(() => _pillar = AppPillar.values[idx]);
                        },
                        destinations: [
                          for (final p in AppPillar.values)
                            NavigationRailDestination(
                              icon: Icon(p.icon),
                              selectedIcon: Icon(p.selectedIcon),
                              label: Text(p.label),
                            ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: bodyContent),
                    ],
                  )
                : bodyContent,
          ),
          const QuickCaptureBar(),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _pillar.index,
              onDestinationSelected: (idx) {
                setState(() => _pillar = AppPillar.values[idx]);
              },
              destinations: [
                for (final p in AppPillar.values)
                  NavigationDestination(
                    icon: Icon(p.icon),
                    selectedIcon: Icon(p.selectedIcon),
                    label: p.label,
                  ),
              ],
            ),
    );
  }
}

class _QuickSwitcherDialog extends ConsumerStatefulWidget {
  const _QuickSwitcherDialog({required this.allDocs});

  final List<Document> allDocs;

  @override
  ConsumerState<_QuickSwitcherDialog> createState() =>
      _QuickSwitcherDialogState();
}

class _QuickSwitcherDialogState extends ConsumerState<_QuickSwitcherDialog> {
  String _query = '';
  List<Document>? _ftsResults;

  Future<void> _onQueryChanged(String q) async {
    setState(() => _query = q);
    final services = await ref.read(
      documentListProvider.future,
    );
    if (services.isEmpty) return;
    final lower = q.trim().toLowerCase();
    if (lower.isEmpty) {
      setState(() => _ftsResults = null);
      return;
    }
    final filtered = widget.allDocs.where((d) {
      return d.title.toLowerCase().contains(lower) ||
          d.relPath.toLowerCase().contains(lower);
    }).toList();
    setState(() => _ftsResults = filtered);
  }

  @override
  Widget build(BuildContext context) {
    final results = _ftsResults ?? widget.allDocs;

    return AlertDialog(
      title: const Text('Quick Switcher & Search'),
      content: SizedBox(
        width: 440,
        height: 340,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Jump to note, project, or log...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        _query.isEmpty
                            ? 'No documents in vault yet.'
                            : 'No match for "$_query".',
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final doc = results[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            doc.title.isEmpty ? doc.relPath : doc.title,
                          ),
                          subtitle: Text('${doc.relPath} · ${doc.docType}'),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.push('/documents/${doc.id}', extra: doc);
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
}
