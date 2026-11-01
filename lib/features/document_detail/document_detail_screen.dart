import 'dart:io';

import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter/material.dart' hide Decoration;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/editor/editor_save_pipeline.dart';
import '../../core/editor/live_preview_controller.dart';
import '../../core/editor/live_preview_editor.dart';
import '../../core/index/app_services.dart';
import '../../core/index/index_providers.dart';
import '../../core/workspace/workspace_state.dart';
import '../../shared/widgets/in_place_task_tile.dart';
import '../search/search_dialog.dart';

/// Full Live Preview Editor screen for Milestone 6.
class DocumentDetailScreen extends ConsumerStatefulWidget {
  const DocumentDetailScreen({required this.document, super.key});

  final Document document;

  @override
  ConsumerState<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  LivePreviewController? _controller;
  EditorSavePipeline? _pipeline;
  String? _loadedRelPath;
  String? _lastLoadedDiskText;
  bool _showBacklinksPanel = false;

  @override
  void initState() {
    super.initState();
    // Record visit for 2-hour session continuity & Recent switcher (A-08, N-04)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(workspaceStateProvider.notifier).recordVisitedDocument(
        relPath: widget.document.relPath,
        title: widget.document.title,
        docType: widget.document.docType,
      );
      ref
          .read(workspaceStateProvider.notifier)
          .completeOnboardingStep('explore_guides');
    });
  }

  @override
  void dispose() {
    _pipeline?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _syncEditorWithDisk(String diskText, String vaultPath) {
    if (_loadedRelPath != widget.document.relPath || _controller == null) {
      _loadedRelPath = widget.document.relPath;
      _lastLoadedDiskText = diskText;
      _controller = LivePreviewController(text: diskText);
      _pipeline = EditorSavePipeline(
        filePath: widget.document.relPath,
        initialText: diskText,
        onSaveToDisk: (relPath, text) async {
          final absPath = VaultPath(relPath).toAbsolute(vaultPath);
          final file = File(absPath);

          // Suppress watcher self-write echo if services available
          final services = await ref.read(appServicesProvider.future);
          if (services != null) {
            services.watcher.suppressSelfWrite(VaultPath(relPath));
          }

          _lastLoadedDiskText = text;
          await writeVaultFileAtomic(file, VaultFileContents(text: text, hadBom: false));
          if (services != null) {
            await services.indexService.refreshFile(relPath);
          }
        },
      );

      _controller!.addListener(() {
        _pipeline?.onBufferChanged(_controller!.text);
      });
    } else {
      if (_lastLoadedDiskText == diskText) return;
      _lastLoadedDiskText = diskText;

      final pipeline = _pipeline!;
      if (diskText != pipeline.bufferText) {
        pipeline.onExternalFileChanged(diskText);
        if (!pipeline.isDirty) {
          _controller!.updateTextPreservingSelection(diskText);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawTextAsync = ref.watch(documentRawTextProvider(widget.document.relPath));
    final docsAsync = ref.watch(documentListProvider);
    final appServicesAsync = ref.watch(appServicesProvider);
    final backlinksAsync = ref.watch(backlinksForDocumentProvider(widget.document.id));
    final unlinkedMentionsAsync = ref.watch(unlinkedMentionsProvider(widget.document));
    final allEntriesAsync = ref.watch(allEntriesWithDocumentsProvider);

    final vaultPath = appServicesAsync.value?.vaultPath ?? '';
    final noteTitles = docsAsync.value?.map((d) => d.title.isNotEmpty ? d.title : d.relPath).toList() ?? [];
    final backlinks = backlinksAsync.value ?? const [];
    final unlinkedMentions = unlinkedMentionsAsync.value ?? const [];
    final docTasks = (allEntriesAsync.value ?? const [])
        .where((e) => e.document.id == widget.document.id && e.isTask)
        .toList();

    return rawTextAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (rawText) {
        _syncEditorWithDisk(rawText, vaultPath);

        final controller = _controller!;
        final pipeline = _pipeline!;

        return ListenableBuilder(
          listenable: Listenable.merge([controller, pipeline]),
          builder: (context, _) {
            final isSourceMode = controller.isSourceMode;
            final isLargeFile = pipeline.isLargeFile;
            final conflict = pipeline.conflictState;

            return Scaffold(
              appBar: AppBar(
                title: Text(widget.document.title.isEmpty
                    ? widget.document.relPath
                    : widget.document.title),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.collections_bookmark_outlined),
                    tooltip: 'Create Collection from this Note/Log (B-10)',
                    onPressed: () => _openCreateCollectionFromDocDialog(context),
                  ),
                  IconButton(
                    icon: Icon(isSourceMode ? Icons.remove_red_eye : Icons.code),
                    tooltip: isSourceMode ? 'Live Preview' : 'Source Mode',
                    onPressed: () {
                      controller.isSourceMode = !isSourceMode;
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.save),
                    tooltip: 'Save',
                    onPressed: pipeline.isDirty ? () => pipeline.saveNow() : null,
                  ),
                ],
              ),
              body: Column(
                children: [
                  // Large file warning banner
                  if (isLargeFile)
                    Container(
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.errorContainer,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.warning,
                              color: Theme.of(context).colorScheme.onErrorContainer,
                              size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Large file (>1,000 lines). Live Preview editing may be slow.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onErrorContainer,
                                fontSize: 13.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // External conflict reconciliation banner
                  if (conflict != null)
                    Container(
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'File changed on disk externally while open.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () =>
                                    pipeline.resolveConflict(ConflictResolutionChoice.keepMine),
                                child: const Text('Keep mine'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  pipeline.resolveConflict(ConflictResolutionChoice.loadFromDisk);
                                  controller.updateTextPreservingSelection(pipeline.bufferText);
                                },
                                child: const Text('Load from disk'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: LivePreviewEditor(
                      controller: controller,
                      noteTitles: noteTitles,
                      onLinkTap: (target) => _handleLinkTap(
                        context,
                        target,
                        docsAsync.value ?? const [],
                      ),
                      onTagTap: (tag) => SearchDialog.show(
                        context,
                        initialTag: tag,
                      ),
                      onSaveRequested: () => pipeline.saveNow(),
                    ),
                  ),

                  // Collapsible Backlinks & Document Tasks Footer (N-02, D-12, D-19)
                  Material(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Divider(height: 1),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.link, size: 18),
                          title: Text(
                            'Backlinks (${backlinks.length}) · Unlinked (${unlinkedMentions.length}) · Tasks (${docTasks.length})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Icon(
                            _showBacklinksPanel
                                ? Icons.expand_more
                                : Icons.expand_less,
                            size: 18,
                          ),
                          onTap: () => setState(
                            () => _showBacklinksPanel = !_showBacklinksPanel,
                          ),
                        ),
                        if (_showBacklinksPanel)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 240),
                            child: ListView(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              children: [
                                if (backlinks.isNotEmpty) ...[
                                  const Text(
                                    'LINKED MENTIONS (BACKLINKS)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  for (final b in backlinks)
                                    ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.subdirectory_arrow_right,
                                        size: 16,
                                      ),
                                      title: Text(
                                        b.sourceDocument.title.isNotEmpty
                                            ? b.sourceDocument.title
                                            : b.sourceDocument.relPath,
                                      ),
                                      subtitle: Text(b.sourceDocument.relPath),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => DocumentDetailScreen(
                                              document: b.sourceDocument,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                                if (unlinkedMentions.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'UNLINKED MENTIONS (${unlinkedMentions.length})',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  for (final u in unlinkedMentions)
                                    Card(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      child: ListTile(
                                        dense: true,
                                        title: Text(
                                          u.sourceDocument.title.isNotEmpty
                                              ? u.sourceDocument.title
                                              : u.sourceDocument.relPath,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              u.sourceDocument.relPath,
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              u.snippet,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: FilledButton.tonal(
                                          style: FilledButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          onPressed: () async {
                                            await ref
                                                .read(vaultMutationProvider)
                                                .linkMention(
                                                  sourceRelPath:
                                                      u.sourceDocument.relPath,
                                                  lineIndex: u.lineIndex,
                                                  keyword: u.matchedText,
                                                  targetTitleOrPath: widget
                                                          .document
                                                          .title
                                                          .isNotEmpty
                                                      ? widget.document.title
                                                      : widget.document.relPath,
                                                );
                                            ref.invalidate(
                                              unlinkedMentionsProvider(
                                                widget.document,
                                              ),
                                            );
                                            ref.invalidate(
                                              backlinksForDocumentProvider(
                                                widget.document.id,
                                              ),
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Linked "${u.matchedText}" in ${u.sourceDocument.relPath}!',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: const Text(
                                            'Link',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                                if (docTasks.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  const Text(
                                    'TASKS IN THIS NOTE (IN-PLACE EDITABLE)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  for (final t in docTasks)
                                    InPlaceTaskTile(
                                      item: t,
                                      showSourceBadge: false,
                                      dense: true,
                                    ),
                                ],
                                if (backlinks.isEmpty &&
                                    unlinkedMentions.isEmpty &&
                                    docTasks.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'No incoming [[wikilinks]], unlinked mentions, or tasks in this note yet.',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: Text(widget.document.relPath)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: Text(widget.document.relPath)),
        body: Center(child: Text('Error loading document: $err')),
      ),
    );
  }

  void _openCreateCollectionFromDocDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Collection (B-10, D-10)'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Collection Title',
            hintText: 'e.g. Books to Read or Trip Packing List',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
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
              final relPath = await ref
                  .read(vaultMutationProvider)
                  .createNoteOrProject(title: title, docType: 'collection');
              final linkTarget = relPath.replaceAll('.md', '');
              await ref.read(vaultMutationProvider).appendLineToDocument(
                relPath: widget.document.relPath,
                lineText: '- – [[$linkTarget|$title]]',
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Create & Link'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLinkTap(
    BuildContext context,
    String targetRaw,
    List<Document> allDocs,
  ) async {
    var cleanTarget = targetRaw.trim();
    if (cleanTarget.contains('#')) {
      cleanTarget = cleanTarget.split('#').first.trim();
    }
    if (cleanTarget.contains('^')) {
      cleanTarget = cleanTarget.split('^').first.trim();
    }
    if (cleanTarget.isEmpty) return;

    final lower = cleanTarget.toLowerCase();
    final targetDoc = allDocs.where((d) {
      if (d.relPath.toLowerCase() == lower ||
          d.relPath.toLowerCase() == '$lower.md') {
        return true;
      }
      final base = d.relPath.replaceAll('\\', '/').split('/').last;
      final baseNoExt = base.toLowerCase().endsWith('.md')
          ? base.substring(0, base.length - 3)
          : base;
      if (baseNoExt.toLowerCase() == lower) return true;
      if (d.title.toLowerCase() == lower) return true;
      return false;
    }).firstOrNull;

    if (targetDoc != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DocumentDetailScreen(document: targetDoc),
        ),
      );
      return;
    }

    // Target note does not exist yet -- prompt user to create it (N-02)
    final create = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Note?'),
        content: Text('Note "[[$cleanTarget]]" does not exist yet. Create it now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create Note'),
          ),
        ],
      ),
    );

    if (create == true && context.mounted) {
      final relPath = await ref.read(vaultMutationProvider).createNoteOrProject(
            title: cleanTarget,
            docType: 'note',
          );
      final refreshedDocs = await ref.read(documentListProvider.future);
      final createdDoc = refreshedDocs.where((d) => d.relPath == relPath).firstOrNull ??
          Document(
            id: 0,
            relPath: relPath,
            sha256: '',
            mtimeMs: DateTime.now().millisecondsSinceEpoch,
            sizeBytes: 0,
            docType: 'note',
            title: cleanTarget,
            indexedAtMs: DateTime.now().millisecondsSinceEpoch,
          );
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DocumentDetailScreen(document: createdDoc),
          ),
        );
      }
    }
  }
}
