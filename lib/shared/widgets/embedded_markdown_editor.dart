import 'dart:io';

import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter/material.dart' hide Decoration;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/editor/editor_save_pipeline.dart';
import '../../core/editor/live_preview_controller.dart';
import '../../core/editor/live_preview_editor.dart';
import '../../core/index/app_services.dart';
import '../../core/index/index_providers.dart';

/// Mounts M6's [`LivePreviewEditor`](../../core/editor/live_preview_editor.dart)
/// bound to [relPath] on disk, with debounced atomic saves and external-file
/// change reconciliation.
///
/// Used by Today's Combined View (`daily/YYYY-MM-DD.md`), Inbox (`inbox.md`),
/// and all enabled Horizons (`weekly/`, `monthly/`, `quarterly/`, `yearly/`,
/// `future.md`).
class EmbeddedMarkdownEditor extends ConsumerStatefulWidget {
  const EmbeddedMarkdownEditor({
    required this.relPath,
    this.padding = const EdgeInsets.all(16.0),
    super.key,
  });

  final String relPath;
  final EdgeInsets padding;

  @override
  ConsumerState<EmbeddedMarkdownEditor> createState() =>
      _EmbeddedMarkdownEditorState();
}

class _EmbeddedMarkdownEditorState
    extends ConsumerState<EmbeddedMarkdownEditor> {
  LivePreviewController? _controller;
  EditorSavePipeline? _pipeline;
  String? _loadedRelPath;

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
      _controller = LivePreviewController(text: diskText);
      _pipeline = EditorSavePipeline(
        filePath: widget.relPath,
        initialText: diskText,
        onSaveToDisk: (relPath, text) async {
          final absPath = VaultPath(relPath).toAbsolute(vaultPath);
          final file = File(absPath);

          final services = await ref.read(appServicesProvider.future);
          if (services != null) {
            services.watcher.suppressSelfWrite(VaultPath(absPath));
          }

          await writeVaultFileAtomic(
            file,
            VaultFileContents(text: text, hadBom: false),
          );
          if (services != null) {
            await services.indexService.refreshFile(relPath);
          }
          ref.invalidate(documentRawTextProvider(widget.relPath));
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
      data: (rawText) {
        _syncEditorWithDisk(rawText, vaultPath);
        final controller = _controller!;
        final pipeline = _pipeline!;

        return ListenableBuilder(
          listenable: Listenable.merge([controller, pipeline]),
          builder: (context, _) {
            return Column(
              children: [
                if (pipeline.isDirty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, top: 4),
                      child: TextButton.icon(
                        onPressed: () => pipeline.saveNow(),
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: const Text('Save now'),
                      ),
                    ),
                  ),
                Expanded(
                  child: LivePreviewEditor(
                    controller: controller,
                    noteTitles: noteTitles,
                    tagNames: tagNames,
                    contextNames: contextNames,
                    padding: widget.padding,
                    onSaveRequested: () => pipeline.saveNow(),
                  ),
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
}
