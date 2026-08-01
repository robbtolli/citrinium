import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main.dart` with a `SharedPreferences` instance obtained
/// via `SharedPreferences.getInstance()` *before* `runApp`, so every other
/// provider can read it synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main() with a real '
    'SharedPreferences instance.',
  );
});

const _vaultPathPrefsKey = 'vaultPath';

/// The user's chosen vault directory (an absolute, OS-native path),
/// persisted in `shared_preferences` per `docs/milestones/m0.md` W4's
/// "path persisted in shared_preferences" -- `null` means first-run/no
/// vault chosen yet, which `app/router.dart` uses to redirect to the vault
/// setup screen.
class VaultPathNotifier extends Notifier<String?> {
  @override
  String? build() {
    return ref.watch(sharedPreferencesProvider).getString(_vaultPathPrefsKey);
  }

  Future<void> setVaultPath(String path) async {
    await ref.read(sharedPreferencesProvider).setString(_vaultPathPrefsKey, path);
    state = path;
  }

  /// Forgets the chosen vault (routes back to first-run setup). Does not
  /// touch the vault's files themselves -- per P-11, this app is a
  /// view/editor over the files, so "un-choosing" a vault is purely a
  /// local-app-state operation.
  Future<void> clear() async {
    await ref.read(sharedPreferencesProvider).remove(_vaultPathPrefsKey);
    state = null;
  }
}

final vaultPathProvider = NotifierProvider<VaultPathNotifier, String?>(
  VaultPathNotifier.new,
);
