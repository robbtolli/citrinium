import 'dart:async';

import 'package:watcher/watcher.dart' as w;

import 'ignore_rules.dart';
import 'path_normalization.dart';

/// The kind of change a [VaultChangeEvent] describes.
enum VaultChangeType { add, modify, remove }

/// A single, debounced change to a tracked file in the vault.
class VaultChangeEvent {
  const VaultChangeEvent({required this.type, required this.path});

  final VaultChangeType type;
  final VaultPath path;

  @override
  String toString() => 'VaultChangeEvent($type, $path)';

  @override
  bool operator ==(Object other) =>
      other is VaultChangeEvent && other.type == type && other.path == path;

  @override
  int get hashCode => Object.hash(type, path);
}

/// Watches a vault directory for changes to tracked (`.md`, non-ignored)
/// files.
///
/// Implementations must:
///
/// - Debounce bursts of filesystem events for the same path into a single
///   [VaultChangeEvent] (editors/OSes commonly emit several raw events per
///   logical save).
/// - Suppress events caused by *our own* writes (see [suppressSelfWrite]),
///   so saving a file from within the app doesn't trigger a pointless
///   reparse-on-external-change loop.
abstract class VaultWatcher {
  /// The stream of debounced, self-write-filtered change events.
  Stream<VaultChangeEvent> get events;

  /// Starts watching. Must be called before [events] will emit anything.
  Future<void> start();

  /// Stops watching and releases underlying resources.
  Future<void> stop();

  /// Registers that the app itself is about to write (or has just written)
  /// [path], so filesystem events for it arriving within the suppression
  /// window are treated as an echo of our own write and dropped rather than
  /// re-emitted as an external change.
  void suppressSelfWrite(VaultPath path);
}

/// [VaultWatcher] implementation backed by `package:watcher`'s
/// [w.DirectoryWatcher].
///
/// Recursive directory watching (including on Linux, where `dart:io`'s
/// native inotify wrapper doesn't recurse on its own) is handled by
/// `package:watcher`, not reimplemented here.
class WatcherVaultWatcher implements VaultWatcher {
  WatcherVaultWatcher({
    required this.vaultRootPath,
    this.debounce = const Duration(milliseconds: 300),
    this.selfWriteSuppressionWindow = const Duration(seconds: 2),
    this.ignoredDirNames = defaultIgnoredDirNames,
    w.DirectoryWatcher? directoryWatcher,
  }) : _directoryWatcher = directoryWatcher ?? w.DirectoryWatcher(vaultRootPath);

  final String vaultRootPath;
  final Duration debounce;
  final Duration selfWriteSuppressionWindow;
  final Set<String> ignoredDirNames;

  final w.DirectoryWatcher _directoryWatcher;
  final _controller = StreamController<VaultChangeEvent>.broadcast();

  final Map<String, Timer> _debounceTimers = {};
  final Map<String, VaultChangeType> _pendingType = {};
  final Map<String, DateTime> _suppressedUntil = {};

  StreamSubscription<w.WatchEvent>? _subscription;

  @override
  Stream<VaultChangeEvent> get events => _controller.stream;

  @override
  Future<void> start() async {
    // `package:watcher` only starts monitoring once something is listening
    // to `events` (see its doc comment on `ready`), so we must subscribe
    // before awaiting readiness -- awaiting first would hang forever.
    _subscription = _directoryWatcher.events.listen(_handleRawEvent);
    await _directoryWatcher.ready;
  }

  @override
  Future<void> stop() async {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _pendingType.clear();
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }

  @override
  void suppressSelfWrite(VaultPath path) {
    _suppressedUntil[path.value] = DateTime.now().add(selfWriteSuppressionWindow);
  }

  void _handleRawEvent(w.WatchEvent event) {
    final vaultPath = VaultPath.fromAbsolute(vaultRootPath, event.path);
    if (!isTrackedVaultPath(vaultPath, ignoredDirNames: ignoredDirNames)) {
      return;
    }

    if (_isSuppressed(vaultPath)) return;

    final key = vaultPath.value;
    _pendingType[key] = _mapType(event.type);
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(debounce, () {
      _debounceTimers.remove(key);
      final type = _pendingType.remove(key);
      if (type == null) return;
      if (_controller.isClosed) return;
      _controller.add(VaultChangeEvent(type: type, path: vaultPath));
    });
  }

  bool _isSuppressed(VaultPath path) {
    final expiry = _suppressedUntil[path.value];
    if (expiry == null) return false;
    if (DateTime.now().isAfter(expiry)) {
      _suppressedUntil.remove(path.value);
      return false;
    }
    return true;
  }

  static VaultChangeType _mapType(w.ChangeType type) {
    if (type == w.ChangeType.ADD) return VaultChangeType.add;
    if (type == w.ChangeType.REMOVE) return VaultChangeType.remove;
    return VaultChangeType.modify;
  }
}
