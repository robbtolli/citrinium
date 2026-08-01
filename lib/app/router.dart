import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/vault/vault_path_provider.dart';
import '../features/document_detail/document_detail_screen.dart';
import '../features/documents/document_list_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/vault_setup/vault_setup_screen.dart';

/// Bridges Riverpod's `vaultPathProvider` to go_router's `Listenable`-based
/// refresh mechanism, so the redirect logic in [goRouterProvider] re-runs
/// the moment a vault is chosen (or un-chosen) -- without this, go_router
/// has no way to know that state outside its own widget tree changed.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<String?>(vaultPathProvider, (previous, next) {
      if (previous != next) notifyListeners();
    });
  }
}

/// The four walking-skeleton screens (`docs/milestones/m0.md` W4) plus the
/// first-run redirect: no vault chosen yet -> `/vault-setup`; otherwise ->
/// `/documents`.
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final hasVault = ref.read(vaultPathProvider) != null;
      final atSetup = state.matchedLocation == '/vault-setup';

      if (!hasVault && !atSetup) return '/vault-setup';
      if (hasVault && atSetup) return '/documents';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/documents'),
      GoRoute(
        path: '/vault-setup',
        builder: (context, state) => const VaultSetupScreen(),
      ),
      GoRoute(
        path: '/documents',
        builder: (context, state) => const DocumentListScreen(),
      ),
      GoRoute(
        path: '/documents/:id',
        builder: (context, state) {
          final document = state.extra! as Document;
          return DocumentDetailScreen(document: document);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
