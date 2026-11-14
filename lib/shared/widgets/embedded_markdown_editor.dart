import 'dart:io';

import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart' hide Decoration;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock/app_clock.dart';
import '../../core/editor/editor_save_pipeline.dart';
import '../../core/editor/live_preview_controller.dart';
import '../../core/editor/live_preview_editor.dart';
import '../../core/index/app_services.dart';
import '../../core/index/index_providers.dart';
import 'citrine_data_view_card.dart';

/// Mounts M6's [`LivePreviewEditor`](../../core/editor/live_preview_editor.dart)
/// bound to [relPath] on disk, with debounced atomic saves, external-file
/// change reconciliation, and inline ```` ```citrine ```` data view rendering.
class EmbeddedMarkdownEditor extends ConsumerStatefulWidget {
  const EmbeddedMarkdownEditor({
    required this.relPath,
    this.padding = const EdgeInsets.all(16.0),
    this.referenceDate,
    this.shrinkWrap = false,
    this.showDataViewToolbar = true,
    super.key,
  });

  final String relPath;
  final EdgeInsets padding;
  final DateTime? referenceDate;
  final bool shrinkWrap;
  final bool showDataViewToolbar;

  @override
  ConsumerState<EmbeddedMarkdownEditor> createState() =>
      _EmbeddedMarkdownEditorState();
}

class _EmbeddedMarkdownEditorState
    extends ConsumerState<EmbeddedMarkdownEditor> {
  LivePreviewController? _controller;
  EditorSavePipeline? _pipeline;
  String? _loadedRelPath;
  String? _lastLoadedDiskText;

  @override
  void dispose() {
    _pipeline?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _syncEditorWithDisk(String diskText, String vaultPath) {
    if (_loadedRelPath != widget.relPath || _controller == null) {
      _pipeline?.dispose();
      _controller?.dispose();

      _loadedRelPath = widget.relPath;
      _lastLoadedDiskText = diskText;
      _controller = LivePreviewController(text: diskText);
      _pipeline = EditorSavePipeline(
        filePath: widget.relPath,
        initialText: diskText,
        onSaveToDisk: (relPath, text) async {
          final absPath = VaultPath(relPath).toAbsolute(vaultPath);
          final file = File(absPath);

          final services = await ref.read(appServicesProvider.future);
          if (services != null) {
            services.watcher.suppressSelfWrite(VaultPath(relPath));
          }

          _lastLoadedDiskText = text;
          await writeVaultFileAtomic(
            file,
            VaultFileContents(text: text, hadBom: false),
          );
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
    final rawTextAsync = ref.watch(documentRawTextProvider(widget.relPath));
    final docsAsync = ref.watch(documentListProvider);
    final entriesAsync = ref.watch(allEntriesWithDocumentsProvider);
    final appServicesAsync = ref.watch(appServicesProvider);

    final vaultPath = appServicesAsync.value?.vaultPath ?? '';
    final noteTitles =
        docsAsync.value
            ?.map((d) => d.title.isNotEmpty ? d.title : d.relPath)
            .toList() ??
        const [];

    final allEntries = entriesAsync.value ?? const [];
    final tagNames = <String>{
      'habit',
      'someday',
      'waiting-for',
      for (final e in allEntries) ...e.tags,
    }.toList();
    final contextNames = <String>{
      'computer',
      'phone',
      'errands',
      'home',
      for (final e in allEntries) ...e.contexts,
    }.toList();

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
            final conflict = pipeline.conflictState;
            final refDate =
                widget.referenceDate ?? ref.watch(appClockProvider).today();
            final dataViewBlocks = findCitrineDataViewBlocks(controller.text);

            final editorWidget = LivePreviewEditor(
              controller: controller,
              noteTitles: noteTitles,
              tagNames: tagNames,
              contextNames: contextNames,
              padding: widget.padding,
              onSaveRequested: () => pipeline.saveNow(),
            );

            return Column(
              mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (conflict != null)
                  Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'File changed on disk externally while open.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).colorScheme.onTertiaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => pipeline.resolveConflict(
                                ConflictResolutionChoice.keepMine,
                              ),
                              child: const Text('Keep mine'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {
                                pipeline.resolveConflict(
                                  ConflictResolutionChoice.loadFromDisk,
                                );
                                controller.updateTextPreservingSelection(
                                  pipeline.bufferText,
                                );
                              },
                              child: const Text('Load from disk'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (widget.showDataViewToolbar || pipeline.isDirty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        if (widget.showDataViewToolbar)
                          TextButton.icon(
                            key: const Key('editor-insert-data-view'),
                            onPressed: () async {
                              final query =
                                  await showCitrineDataViewPickerDialog(
                                    context,
                                  );
                              if (query == null) return;
                              final fence = query.toMarkdownFence();
                              final text = controller.text;
                              final sel = controller.selection;
                              final insertAt = sel.isValid
                                  ? sel.baseOffset.clamp(0, text.length)
                                  : text.length;
                              final prefix =
                                  (insertAt > 0 && text[insertAt - 1] != '\n')
                                  ? '\n\n'
                                  : '';
                              final suffix = '\n\n';
                              final updated = text.replaceRange(
                                insertAt,
                                insertAt,
                                '$prefix$fence$suffix',
                              );
                              controller.value = TextEditingValue(
                                text: updated,
                                selection: TextSelection.collapsed(
                                  offset:
                                      insertAt +
                                      prefix.length +
                                      fence.length +
                                      suffix.length,
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.view_agenda_outlined,
                              size: 16,
                            ),
                            label: const Text('Insert Data View'),
                          ),
                        const Spacer(),
                        if (pipeline.isDirty)
                          TextButton.icon(
                            onPressed: () => pipeline.saveNow(),
                            icon: const Icon(Icons.save_outlined, size: 16),
                            label: const Text('Save now'),
                          ),
                      ],
                    ),
                  ),
                if (dataViewBlocks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        for (final block in dataViewBlocks)
                          CitrineDataViewCard(
                            query: block.query,
                            referenceDate: refDate,
                            onEditBlock: () async {
                              final updatedQuery =
                                  await showCitrineDataViewPickerDialog(
                                    context,
                                    initialQuery: block.query,
                                  );
                              if (updatedQuery == null) return;
                              final updatedFence = updatedQuery
                                  .toMarkdownFence();
                              final text = controller.text;
                              if (block.endOffset <= text.length) {
                                final newText = text.replaceRange(
                                  block.startOffset,
                                  block.endOffset,
                                  updatedFence,
                                );
                                controller.updateTextPreservingSelection(
                                  newText,
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                if (widget.shrinkWrap)
                  editorWidget
                else
                  Expanded(child: editorWidget),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading ${widget.relPath}: $err')),
    );
  }
}
