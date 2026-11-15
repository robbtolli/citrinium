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
  int? _previousCursorLine;
  bool _isTaggingLine = false;
  final Set<int> _sourceModeBlockIndices = <int>{};
  AppServices? _cachedServices;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _pipeline?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  int _lineIndexAtOffset(String text, int offset) {
    final clamped = offset.clamp(0, text.length);
    var line = 0;
    for (var i = 0; i < clamped; i++) {
      if (text.codeUnitAt(i) == 0x0A) {
        line++;
      }
    }
    return line;
  }

  Future<void> _onLeftLine(int prevLine) async {
    if (_isTaggingLine) return;
    final controller = _controller;
    final pipeline = _pipeline;
    if (controller == null || pipeline == null) return;

    final doc = MarkdownDocument.parse(controller.text);
    if (prevLine < 0 || prevLine >= doc.lines.length) return;
    final line = doc.lines[prevLine];
    if (line.kind != LineKind.task) return;
    final taskText = stripCitrineTaskComment(
      line.task!.contentSpan.of(doc.rawText),
    ).trim();
    if (taskText.isEmpty) return;

    _isTaggingLine = true;
    try {
      await pipeline.saveNow();
      final services = await ref.read(appServicesProvider.future);
      if (services == null || !mounted) return;
      final beforeText = controller.text;
      final record = await services.taskSyncService.tagAndSaveMarkdownTask(
        relPath: widget.relPath,
        lineIndex: prevLine,
      );
      if (record == null || !mounted) return;

      final absPath = VaultPath(widget.relPath).toAbsolute(services.vaultPath);
      final updatedText = await readVaultFile(File(absPath));
      if (!mounted) return;
      if (updatedText.text != beforeText) {
        final delta = updatedText.text.length - beforeText.length;
        final oldSel = controller.selection;
        controller.updateTextPreservingSelection(updatedText.text);
        if (oldSel.isValid && delta > 0) {
          final prevLineEnd = line.span.end;
          if (oldSel.baseOffset > prevLineEnd) {
            final nextOffset = (oldSel.baseOffset + delta).clamp(
              0,
              updatedText.text.length,
            );
            controller.selection = TextSelection.collapsed(offset: nextOffset);
          }
        }
        pipeline.onExternalFileChanged(updatedText.text);
      }
    } finally {
      _isTaggingLine = false;
    }
  }

  void _syncEditorWithDisk(String diskText, String vaultPath) {
    if (_loadedRelPath != widget.relPath || _controller == null) {
      _pipeline?.dispose();
      _controller?.dispose();

      _loadedRelPath = widget.relPath;
      _lastLoadedDiskText = diskText;
      _sourceModeBlockIndices.clear();
      _controller = LivePreviewController(text: diskText);
      _pipeline = EditorSavePipeline(
        filePath: widget.relPath,
        initialText: diskText,
        onSaveToDisk: (relPath, text) async {
          final absPath = VaultPath(relPath).toAbsolute(vaultPath);
          final file = File(absPath);

          final services =
              _cachedServices ??
              ((!_isDisposed && mounted)
                  ? await ref.read(appServicesProvider.future)
                  : null);
          if (services != null) {
            services.watcher.suppressSelfWrite(VaultPath(relPath));
          }

          // Do not overwrite _lastLoadedDiskText here: self-write suppression
          // keeps documentRawTextProvider at its previous emission until an
          // external change arrives, so updating _lastLoadedDiskText early would
          // make the next rebuild treat that stale emission as an external edit.
          await writeVaultFileAtomic(
            file,
            VaultFileContents(text: text, hadBom: false),
          );
          if (services != null) {
            await services.indexService.refreshFile(relPath);
          }
        },
      );

      _previousCursorLine = null;
      _controller!.addListener(() {
        final ctrl = _controller;
        if (ctrl == null) return;
        _pipeline?.onBufferChanged(ctrl.text);
        if (ctrl.selection.isValid) {
          final currentLine = _lineIndexAtOffset(
            ctrl.text,
            ctrl.selection.baseOffset,
          );
          final prevLine = _previousCursorLine;
          _previousCursorLine = currentLine;
          if (prevLine != null && prevLine != currentLine) {
            _onLeftLine(prevLine);
          }
        }
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
    _cachedServices = appServicesAsync.value ?? _cachedServices;

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
                if (dataViewBlocks.isEmpty)
                  if (widget.shrinkWrap)
                    editorWidget
                  else
                    Expanded(child: editorWidget)
                else
                  _buildInterleavedBody(
                    context: context,
                    controller: controller,
                    pipeline: pipeline,
                    dataViewBlocks: dataViewBlocks,
                    refDate: refDate,
                    noteTitles: noteTitles,
                    tagNames: tagNames,
                    contextNames: contextNames,
                  ),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading ${widget.relPath}: $err')),
    );
  }

  Widget _buildInterleavedBody({
    required BuildContext context,
    required LivePreviewController controller,
    required EditorSavePipeline pipeline,
    required List<CitrineDataViewBlock> dataViewBlocks,
    required DateTime refDate,
    required List<String> noteTitles,
    required List<String> tagNames,
    required List<String> contextNames,
  }) {
    final text = controller.text;
    final items = <_InterleavedItem>[];
    var cursor = 0;

    for (var i = 0; i < dataViewBlocks.length; i++) {
      final block = dataViewBlocks[i];
      if (block.startOffset > cursor) {
        final segText = text.substring(cursor, block.startOffset);
        if (segText.trim().isNotEmpty) {
          items.add(
            _MarkdownSliceItem(
              startOffset: cursor,
              endOffset: block.startOffset,
              text: segText,
            ),
          );
        }
      }
      items.add(_DataViewBlockItem(blockIndex: i, block: block));
      cursor = block.endOffset;
    }

    if (cursor < text.length) {
      items.add(
        _MarkdownSliceItem(
          startOffset: cursor,
          endOffset: text.length,
          text: text.substring(cursor),
          isTail: true,
        ),
      );
    }

    final listWidget = ReorderableListView.builder(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorderItem: (oldIndex, newIndex) =>
          _handleReorder(items, oldIndex, newIndex, controller),
      itemBuilder: (context, index) => _buildInterleavedItem(
        context: context,
        item: items[index],
        itemIndex: index,
        controller: controller,
        pipeline: pipeline,
        refDate: refDate,
        noteTitles: noteTitles,
        tagNames: tagNames,
        contextNames: contextNames,
      ),
    );

    if (widget.shrinkWrap) return listWidget;
    return Expanded(child: listWidget);
  }

  Widget _buildInterleavedItem({
    required BuildContext context,
    required _InterleavedItem item,
    required int itemIndex,
    required LivePreviewController controller,
    required EditorSavePipeline pipeline,
    required DateTime refDate,
    required List<String> noteTitles,
    required List<String> tagNames,
    required List<String> contextNames,
  }) {
    switch (item) {
      case _MarkdownSliceItem():
        final keyLabel = item.isTail
            ? 'seg_${widget.relPath}_tail_${item.startOffset}'
            : 'seg_${widget.relPath}_${item.startOffset}';
        return _MarkdownSegmentEditor(
          key: ValueKey(keyLabel),
          masterController: controller,
          startOffset: item.startOffset,
          endOffset: item.endOffset,
          noteTitles: noteTitles,
          tagNames: tagNames,
          contextNames: contextNames,
          padding: widget.padding,
          onSaveRequested: () => pipeline.saveNow(),
          onLeftGlobalLine: _onLeftLine,
        );
      case _DataViewBlockItem():
        final block = item.block;
        final isSourceMode = _sourceModeBlockIndices.contains(item.blockIndex);
        final dragHandle = ReorderableDragStartListener(
          index: itemIndex,
          child: const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Tooltip(
              message: 'Drag to reorder',
              child: Icon(Icons.drag_indicator, size: 18),
            ),
          ),
        );
        return Padding(
          key: ValueKey('dv_${widget.relPath}_${item.blockIndex}'),
          padding: EdgeInsets.symmetric(
            horizontal: widget.padding.horizontal / 2,
          ),
          child: isSourceMode
              ? _buildSourceModeDataViewCard(
                  context: context,
                  blockIndex: item.blockIndex,
                  block: block,
                  dragHandle: dragHandle,
                  controller: controller,
                  pipeline: pipeline,
                  noteTitles: noteTitles,
                  tagNames: tagNames,
                  contextNames: contextNames,
                )
              : CitrineDataViewCard(
                  query: block.query,
                  referenceDate: refDate,
                  dragHandle: dragHandle,
                  onToggleSourceMode: () => setState(
                    () => _sourceModeBlockIndices.add(item.blockIndex),
                  ),
                  onEditBlock: () async {
                    final updatedQuery = await showCitrineDataViewPickerDialog(
                      context,
                      initialQuery: block.query,
                    );
                    if (updatedQuery == null) return;
                    final updatedFence = updatedQuery.toMarkdownFence();
                    final current = controller.text;
                    if (block.endOffset <= current.length) {
                      final newText = current.replaceRange(
                        block.startOffset,
                        block.endOffset,
                        updatedFence,
                      );
                      controller.updateTextPreservingSelection(newText);
                    }
                  },
                ),
        );
    }
  }

  Widget _buildSourceModeDataViewCard({
    required BuildContext context,
    required int blockIndex,
    required CitrineDataViewBlock block,
    required Widget dragHandle,
    required LivePreviewController controller,
    required EditorSavePipeline pipeline,
    required List<String> noteTitles,
    required List<String> tagNames,
    required List<String> contextNames,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                dragHandle,
                Icon(Icons.code, size: 18, color: colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Citrine Data View (Source)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  tooltip: 'Preview Data View',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(
                    () => _sourceModeBlockIndices.remove(blockIndex),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _MarkdownSegmentEditor(
                key: ValueKey('dv_src_${widget.relPath}_$blockIndex'),
                masterController: controller,
                startOffset: block.startOffset,
                endOffset: block.endOffset,
                noteTitles: noteTitles,
                tagNames: tagNames,
                contextNames: contextNames,
                padding: const EdgeInsets.all(8),
                isSourceMode: true,
                onSaveRequested: () => pipeline.saveNow(),
                onLeftGlobalLine: _onLeftLine,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReorder(
    List<_InterleavedItem> items,
    int oldIndex,
    int newIndex,
    LivePreviewController controller,
  ) {
    if (oldIndex == newIndex) return;

    final reordered = List<_InterleavedItem>.from(items);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    final sourceBlocks = <CitrineDataViewBlock>{
      for (final it in items)
        if (it is _DataViewBlockItem &&
            _sourceModeBlockIndices.contains(it.blockIndex))
          it.block,
    };
    final nextSourceIndices = <int>{};
    var dvIdx = 0;
    for (final it in reordered) {
      if (it is _DataViewBlockItem) {
        if (sourceBlocks.contains(it.block)) {
          nextSourceIndices.add(dvIdx);
        }
        dvIdx++;
      }
    }

    final pieces = <String>[];
    for (final it in reordered) {
      final raw = switch (it) {
        _MarkdownSliceItem() => it.text,
        _DataViewBlockItem() => controller.text.substring(
          it.block.startOffset,
          it.block.endOffset,
        ),
      };
      final trimmed = raw.replaceAll(RegExp(r'^\n+|\n+$'), '');
      if (trimmed.isNotEmpty) {
        pieces.add(trimmed);
      }
    }
    final hadTrailingNewline = controller.text.endsWith('\n');
    final rebuilt =
        pieces.join('\n\n') +
        (hadTrailingNewline && pieces.isNotEmpty ? '\n' : '');

    setState(() {
      _sourceModeBlockIndices
        ..clear()
        ..addAll(nextSourceIndices);
    });
    controller.updateTextPreservingSelection(rebuilt);
  }
}

sealed class _InterleavedItem {
  const _InterleavedItem();
}

class _MarkdownSliceItem extends _InterleavedItem {
  const _MarkdownSliceItem({
    required this.startOffset,
    required this.endOffset,
    required this.text,
    this.isTail = false,
  });

  final int startOffset;
  final int endOffset;
  final String text;
  final bool isTail;
}

class _DataViewBlockItem extends _InterleavedItem {
  const _DataViewBlockItem({
    required this.blockIndex,
    required this.block,
  });

  final int blockIndex;
  final CitrineDataViewBlock block;
}

/// Edits a single contiguous Markdown slice `[startOffset, endOffset)` of
/// [masterController] while keeping [masterController.text] as the literal
/// single source of truth on disk.
class _MarkdownSegmentEditor extends StatefulWidget {
  const _MarkdownSegmentEditor({
    required this.masterController,
    required this.startOffset,
    required this.endOffset,
    required this.noteTitles,
    required this.tagNames,
    required this.contextNames,
    required this.padding,
    required this.onSaveRequested,
    required this.onLeftGlobalLine,
    this.isSourceMode = false,
    super.key,
  });

  final LivePreviewController masterController;
  final int startOffset;
  final int endOffset;
  final List<String> noteTitles;
  final List<String> tagNames;
  final List<String> contextNames;
  final EdgeInsets padding;
  final VoidCallback onSaveRequested;
  final Future<void> Function(int globalLine) onLeftGlobalLine;
  final bool isSourceMode;

  @override
  State<_MarkdownSegmentEditor> createState() => _MarkdownSegmentEditorState();
}

class _MarkdownSegmentEditorState extends State<_MarkdownSegmentEditor> {
  late final LivePreviewController _segmentController;
  late int _startOffset;
  late int _endOffset;
  bool _syncing = false;
  int? _prevLocalLine;

  @override
  void initState() {
    super.initState();
    _startOffset = widget.startOffset;
    _endOffset = widget.endOffset;
    _segmentController = LivePreviewController(
      text: _sliceFromMaster(),
      isSourceMode: widget.isSourceMode,
    );
    _segmentController.addListener(_onSegmentChanged);
    widget.masterController.addListener(_onMasterChanged);
  }

  @override
  void didUpdateWidget(covariant _MarkdownSegmentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.masterController != widget.masterController) {
      oldWidget.masterController.removeListener(_onMasterChanged);
      widget.masterController.addListener(_onMasterChanged);
    }
    if (widget.startOffset != _startOffset || widget.endOffset != _endOffset) {
      _startOffset = widget.startOffset;
      _endOffset = widget.endOffset;
      _syncFromMaster();
    }
  }

  @override
  void dispose() {
    widget.masterController.removeListener(_onMasterChanged);
    _segmentController.removeListener(_onSegmentChanged);
    _segmentController.dispose();
    super.dispose();
  }

  String _sliceFromMaster() {
    final full = widget.masterController.text;
    final s = _startOffset.clamp(0, full.length);
    final e = _endOffset.clamp(s, full.length);
    return full.substring(s, e);
  }

  void _onMasterChanged() {
    if (_syncing) return;
    _syncFromMaster();
  }

  void _syncFromMaster() {
    final masterSlice = _sliceFromMaster();
    if (_segmentController.text == masterSlice) return;
    _syncing = true;
    try {
      _segmentController.updateTextPreservingSelection(masterSlice);
    } finally {
      _syncing = false;
    }
  }

  int _lineAtOffset(String text, int offset) {
    final clamped = offset.clamp(0, text.length);
    var line = 0;
    for (var i = 0; i < clamped; i++) {
      if (text.codeUnitAt(i) == 0x0A) line++;
    }
    return line;
  }

  void _onSegmentChanged() {
    if (_syncing) return;
    final newSegText = _segmentController.text;
    final full = widget.masterController.text;
    final s = _startOffset.clamp(0, full.length);
    final e = _endOffset.clamp(s, full.length);
    final oldSegText = full.substring(s, e);

    if (newSegText != oldSegText) {
      _syncing = true;
      try {
        final updatedFull = full.replaceRange(s, e, newSegText);
        _endOffset = s + newSegText.length;
        widget.masterController.value = TextEditingValue(
          text: updatedFull,
          selection: TextSelection.collapsed(
            offset: (s + _segmentController.selection.baseOffset)
                .clamp(0, updatedFull.length),
          ),
        );
      } finally {
        _syncing = false;
      }
    }

    if (_segmentController.selection.isValid) {
      final localLine = _lineAtOffset(
        newSegText,
        _segmentController.selection.baseOffset,
      );
      final prev = _prevLocalLine;
      _prevLocalLine = localLine;
      if (prev != null && prev != localLine) {
        final baseGlobalLine = _lineAtOffset(
          widget.masterController.text,
          _startOffset,
        );
        widget.onLeftGlobalLine(baseGlobalLine + prev);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LivePreviewEditor(
      controller: _segmentController,
      noteTitles: widget.noteTitles,
      tagNames: widget.tagNames,
      contextNames: widget.contextNames,
      padding: widget.padding,
      onSaveRequested: widget.onSaveRequested,
    );
  }
}
