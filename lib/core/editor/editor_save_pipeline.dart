import 'dart:async';
import 'package:flutter/foundation.dart';

enum ConflictResolutionChoice { keepMine, loadFromDisk, viewDifference }

/// State for external change conflict reconciliation (W8).
class ConflictState {
  const ConflictState({
    required this.diskText,
    required this.bufferText,
  });

  final String diskText;
  final String bufferText;
}

/// Controller for debounced save and external change reconciliation (W8).
class EditorSavePipeline extends ChangeNotifier {
  EditorSavePipeline({
    required this.filePath,
    required this.initialText,
    required this.onSaveToDisk,
    this.debounceMs = 800,
    this.largeFileLineThreshold = 1000,
  }) : _bufferText = initialText,
       _lastSavedText = initialText;

  final String filePath;
  final String initialText;
  final Future<void> Function(String path, String text) onSaveToDisk;
  final int debounceMs;
  final int largeFileLineThreshold;

  String _bufferText;
  String _lastSavedText;
  Timer? _debounceTimer;

  bool _isSaving = false;
  ConflictState? _conflictState;

  String get bufferText => _bufferText;
  bool get isDirty => _bufferText != _lastSavedText;
  bool get isSaving => _isSaving;
  ConflictState? get conflictState => _conflictState;

  bool get isLargeFile {
    final lineCount = '\n'.allMatches(_bufferText).length + 1;
    return lineCount >= largeFileLineThreshold;
  }

  void onBufferChanged(String newText) {
    if (_bufferText != newText) {
      _bufferText = newText;
      notifyListeners();
      _scheduleDebouncedSave();
    }
  }

  void _scheduleDebouncedSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: debounceMs), () {
      saveNow();
    });
  }

  Future<void> saveNow() async {
    if (!isDirty || _isSaving) return;
    _debounceTimer?.cancel();

    _isSaving = true;
    notifyListeners();

    try {
      final textToSave = _bufferText;
      await onSaveToDisk(filePath, textToSave);
      _lastSavedText = textToSave;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Called when an external file-change event is detected by VaultWatcher.
  void onExternalFileChanged(String diskText) {
    if (diskText == _lastSavedText) return; // Self-write echo or identical content

    if (!isDirty) {
      // Buffer clean -> reload silently
      _bufferText = diskText;
      _lastSavedText = diskText;
      notifyListeners();
    } else {
      // Buffer dirty -> present explicit conflict choices
      _conflictState = ConflictState(
        diskText: diskText,
        bufferText: _bufferText,
      );
      notifyListeners();
    }
  }

  void resolveConflict(ConflictResolutionChoice choice) {
    if (_conflictState == null) return;

    switch (choice) {
      case ConflictResolutionChoice.keepMine:
        _conflictState = null;
        saveNow(); // Force overwrite disk
        break;
      case ConflictResolutionChoice.loadFromDisk:
        _bufferText = _conflictState!.diskText;
        _lastSavedText = _conflictState!.diskText;
        _conflictState = null;
        notifyListeners();
        break;
      case ConflictResolutionChoice.viewDifference:
        // Modal shown by UI
        break;
    }
  }

  void clearConflict() {
    _conflictState = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (isDirty) {
      saveNow();
    }
    super.dispose();
  }
}
