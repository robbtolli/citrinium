import 'dart:io';

import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_services.dart';

/// The full document list, per `docs/milestones/m0.md` W4's "document list
/// stream" -- reactive over `IndexDatabase` (see `IndexService.
/// watchAllDocuments`), which is itself kept current by the vault watcher
/// wired up in `openAppServices`. Empty (not an error) while no vault is
/// chosen yet.
final documentListProvider = StreamProvider<List<Document>>((ref) async* {
  final services = await ref.watch(appServicesProvider.future);
  if (services == null) {
    yield const [];
    return;
  }
  yield* services.indexService.watchAllDocuments();
});

/// The entries indexed for one document (`docs/milestones/m0.md` W4's
/// "entries stream"), keyed by `documents.id`.
final entriesForDocumentProvider = StreamProvider.family<List<Entry>, int>((
  ref,
  documentId,
) async* {
  final services = await ref.watch(appServicesProvider.future);
  if (services == null) {
    yield const [];
    return;
  }
  yield* services.indexService.watchEntriesForDocument(documentId);
});

/// Summary counts for the settings screen.
final indexStatsProvider = StreamProvider<IndexStats?>((ref) async* {
  final services = await ref.watch(appServicesProvider.future);
  if (services == null) {
    yield null;
    return;
  }
  yield* services.indexService.watchStats();
});

/// Stream of literal file content for [relPath], yielding initial text from disk
/// and subsequent updates whenever the vault watcher detects an external change to [relPath].
final documentRawTextProvider =
    StreamProvider.autoDispose.family<String, String>((
  ref,
  relPath,
) async* {
  final services = await ref.watch(appServicesProvider.future);
  if (services == null) {
    throw StateError('No vault selected');
  }

  final absolutePath = VaultPath(relPath).toAbsolute(services.vaultPath);
  final file = File(absolutePath);

  if (await file.exists()) {
    final contents = await readVaultFile(file);
    yield contents.text;
  }

  final targetNormalized = VaultPath(relPath).value;

  await for (final event in services.watcher.events) {
    if (event.path.value == relPath || event.path.value == targetNormalized) {
      if (await file.exists()) {
        final contents = await readVaultFile(file);
        yield contents.text;
      }
    }
  }
});

/// Triggers a full index rebuild (the W4 "Rebuild index" button) and
/// returns its stats; throws if no vault is open.
Future<IndexRebuildStats> rebuildIndex(WidgetRef ref) async {
  final services = await ref.read(appServicesProvider.future);
  if (services == null) {
    throw StateError('No vault selected');
  }
  return services.indexService.fullRebuild();
}
