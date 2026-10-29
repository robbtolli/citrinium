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
            services.watcher.suppressSelfWrite(VaultPath(absPath));
          }

          await writeVaultFileAtomic(file, VaultFileContents(text: text, hadBom: false));
          ref.invalidate(documentRawTextProvider(widget.document.relPath));
        },
      );

      _controller!.addListener(() {
        _pipeline?.onBufferChanged(_controller!.text);
      });
    } else {
      final pipeline = _pipeline!;
      if (diskText != pipeline.bufferText) {
        pipeline.onExternalFileChanged(diskText);
        if (!pipeline.isDirty) {
          _controller!.text = diskText;
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
    final allEntriesAsync = ref.watch(allEntriesWithDocumentsProvider);

    final vaultPath = appServicesAsync.value?.vaultPath ?? '';
    final noteTitles = docsAsync.value?.map((d) => d.title.isNotEmpty ? d.title : d.relPath).toList() ?? [];
    final backlinks = backlinksAsync.value ?? const [];
    final docTasks = (allEntriesAsync.value ?? const [])
        .where((e) => e.document.id == widget.document.id && e.isTask)
        .toList();

    return rawTextAsync.when(
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
                                  controller.text = pipeline.bufferText;
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
                            'Backlinks (${backlinks.length}) · Tasks in note (${docTasks.length})',
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
                            constraints: const BoxConstraints(maxHeight: 220),
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
                                if (backlinks.isEmpty && docTasks.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'No incoming [[wikilinks]] or tasks in this note yet.',
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
}
