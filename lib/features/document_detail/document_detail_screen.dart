import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/index/index_providers.dart';

/// Read-only raw file view (`docs/milestones/m0.md` W4): plain
/// `SelectableText` over the literal file content, deliberately **not** an
/// editor -- the Live Preview editing surface is explicitly out of scope
/// for M0 (§7 in `design.md`, scoped into M1/M6).
class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({required this.document, super.key});

  final Document document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawTextAsync = ref.watch(documentRawTextProvider(document.relPath));
    final entriesAsync = ref.watch(entriesForDocumentProvider(document.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(document.title.isEmpty ? document.relPath : document.title),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: entriesAsync.when(
              data: (entries) => Text(
                '${document.relPath} · ${entries.length} indexed ${entries.length == 1 ? 'entry' : 'entries'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              loading: () => Text(document.relPath, style: Theme.of(context).textTheme.bodySmall),
              error: (_, _) => Text(document.relPath, style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          const Divider(height: 24),
          Expanded(
            child: rawTextAsync.when(
              data: (rawText) => SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(rawText, style: const TextStyle(fontFamily: 'monospace')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(child: Text('Could not read file: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
