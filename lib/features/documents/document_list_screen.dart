import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/index/index_providers.dart';

/// Document list, read from the index (`docs/milestones/m0.md` W4) --
/// reactive: an external edit that adds/removes a file updates this list
/// without the user doing anything (exit criterion #5).
class DocumentListScreen extends ConsumerWidget {
  const DocumentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentListProvider);

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
      body: documentsAsync.when(
        data: (documents) {
          if (documents.isEmpty) {
            return const Center(child: Text('No notes in this vault yet.'));
          }
          return ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final document = documents[index];
              return ListTile(
                title: Text(document.title.isEmpty ? document.relPath : document.title),
                subtitle: Text('${document.relPath} · ${document.docType}'),
                onTap: () => context.push('/documents/${document.id}', extra: document),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Could not load documents: $error')),
      ),
    );
  }
}
