import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vault/vault_path_provider.dart';

const _debugModePrefsKey = 'citrine.debug.enabled';
const _dateOverridePrefsKey = 'citrine.debug.dateOverrideIso';

/// Persisted Debug Mode flag (`FR-14`), unlocked by tapping/clicking the
/// app version 7 times on the About screen.
class DebugModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_debugModePrefsKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_debugModePrefsKey, enabled);
    state = enabled;
    if (!enabled) {
      await ref.read(appClockProvider.notifier).reset();
    }
  }
}

final debugModeProvider = NotifierProvider<DebugModeNotifier, bool>(
  DebugModeNotifier.new,
);

/// Injectable application clock (`FR-14`) supporting a Debug Mode date
/// override so Today, Plan & Review, reminders, and rituals can be tested
/// against any date.
@immutable
class AppClockState {
  const AppClockState({this.overrideDate});

  /// Normalized local calendar date (`year, month, day`), or `null` when
  /// using the real system clock.
  final DateTime? overrideDate;

  bool get isOverridden => overrideDate != null;

  DateTime now() {
    final real = DateTime.now();
    final d = overrideDate;
    if (d == null) return real;
    return DateTime(
      d.year,
      d.month,
      d.day,
      real.hour,
      real.minute,
      real.second,
      real.millisecond,
      real.microsecond,
    );
  }

  DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }

  String get todayIso => NlDateParser.formatIsoDate(today());
}

class AppClockNotifier extends Notifier<AppClockState> {
  @override
  AppClockState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_dateOverridePrefsKey);
    if (raw != null && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return AppClockState(
          overrideDate: DateTime(parsed.year, parsed.month, parsed.day),
        );
      }
    }
    return const AppClockState();
  }

  Future<void> setOverrideDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      _dateOverridePrefsKey,
      NlDateParser.formatIsoDate(normalized),
    );
    state = AppClockState(overrideDate: normalized);
  }

  Future<void> stepDays(int deltaDays) async {
    final base = state.today();
    await setOverrideDate(base.add(Duration(days: deltaDays)));
  }

  Future<void> reset() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_dateOverridePrefsKey);
    state = const AppClockState();
  }
}

final appClockProvider = NotifierProvider<AppClockNotifier, AppClockState>(
  AppClockNotifier.new,
);
