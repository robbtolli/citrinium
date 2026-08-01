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

/// The literal file content for [relPath], read fresh each time this
/// provider is (re-)watched -- the read-only raw-file-view screen (W4)
/// intentionally has no caching/edit-buffer layer of its own (that's M1's
/// Live Preview editor); it just displays exactly what's on disk right
/// now.
final documentRawTextProvider = FutureProvider.family<String, String>((
  ref,
  relPath,
) async {
  final services = await ref.watch(appServicesProvider.future);
  if (services == null) {
    throw StateError('No vault selected');
  }
  final absolutePath = VaultPath(relPath).toAbsolute(services.vaultPath);
  final contents = await readVaultFile(File(absolutePath));
  return contents.text;
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
