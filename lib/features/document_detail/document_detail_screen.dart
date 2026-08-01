import 'dart:io';

import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter/material.dart' hide Decoration;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/editor/editor_save_pipeline.dart';
import '../../core/editor/live_preview_controller.dart';
import '../../core/editor/live_preview_editor.dart';
import '../../core/index/app_services.dart';
import '../../core/index/index_providers.dart';

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

    final vaultPath = appServicesAsync.value?.vaultPath ?? '';
    final noteTitles = docsAsync.value?.map((d) => d.title.isNotEmpty ? d.title : d.relPath).toList() ?? [];

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
