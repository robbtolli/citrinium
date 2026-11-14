import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../index/app_services.dart';

/// Immutable snapshot of active background jobs (`FR-16`).
@immutable
class BackgroundWorkState {
  const BackgroundWorkState({
    this.activeJobs = 0,
    this.currentLabel,
    this.completedUnits = 0,
    this.totalUnits = 0,
  });

  final int activeJobs;
  final String? currentLabel;
  final int completedUnits;
  final int totalUnits;

  bool get isRunning => activeJobs > 0;

  double? get progress {
    if (totalUnits <= 0) return null;
    return (completedUnits / totalUnits).clamp(0.0, 1.0);
  }

  BackgroundWorkState copyWith({
    int? activeJobs,
    String? currentLabel,
    bool clearLabel = false,
    int? completedUnits,
    int? totalUnits,
  }) {
    return BackgroundWorkState(
      activeJobs: activeJobs ?? this.activeJobs,
      currentLabel: clearLabel ? null : (currentLabel ?? this.currentLabel),
      completedUnits: completedUnits ?? this.completedUnits,
      totalUnits: totalUnits ?? this.totalUnits,
    );
  }
}

/// Coordinates non-blocking background jobs (e.g. importing untagged tasks)
/// so the UI stays interactive while showing an unobtrusive loading bar and
/// guarding app close (`FR-16`).
class BackgroundWorkManager extends Notifier<BackgroundWorkState> {
  @override
  BackgroundWorkState build() => const BackgroundWorkState();

  /// Runs [work] while tracking progress in [BackgroundWorkState].
  Future<T> runTask<T>({
    required String label,
    int totalUnits = 0,
    required Future<T> Function(
      void Function(int completed, int total) reportProgress,
    )
    work,
  }) async {
    state = state.copyWith(
      activeJobs: state.activeJobs + 1,
      currentLabel: label,
      completedUnits: 0,
      totalUnits: totalUnits,
    );

    try {
      return await work((completed, total) {
        if (!ref.mounted) return;
        state = state.copyWith(
          completedUnits: completed,
          totalUnits: total,
        );
      });
    } finally {
      if (ref.mounted) {
        final remaining = (state.activeJobs - 1).clamp(0, 1 << 30);
        state = state.copyWith(
          activeJobs: remaining,
          clearLabel: remaining == 0,
          completedUnits: remaining == 0 ? 0 : state.completedUnits,
          totalUnits: remaining == 0 ? 0 : state.totalUnits,
        );
      }
    }
  }
}

final backgroundWorkManagerProvider =
    NotifierProvider<BackgroundWorkManager, BackgroundWorkState>(
      BackgroundWorkManager.new,
    );

/// Tracks Markdown files in the vault that were created or edited externally
/// and contain untagged tasks (`FR-16`).
@immutable
class ExternalUntaggedTasksState {
  const ExternalUntaggedTasksState({
    this.pendingRelPaths = const [],
    this.dismissed = false,
  });

  final List<String> pendingRelPaths;
  final bool dismissed;

  bool get shouldShowBanner => pendingRelPaths.isNotEmpty && !dismissed;
}

class ExternalUntaggedTasksNotifier
    extends Notifier<ExternalUntaggedTasksState> {
  @override
  ExternalUntaggedTasksState build() => const ExternalUntaggedTasksState();

  /// Records one or more vault-relative paths containing untagged tasks.
  void addPendingFiles(Iterable<String> relPaths) {
    final merged = <String>{...state.pendingRelPaths, ...relPaths}.toList();
    if (merged.isEmpty) return;
    state = ExternalUntaggedTasksState(
      pendingRelPaths: merged,
      dismissed: false,
    );
  }

  /// Dismisses the prompt without modifying any files (`No` / close).
  void dismiss() {
    state = const ExternalUntaggedTasksState(
      pendingRelPaths: [],
      dismissed: true,
    );
  }

  /// Imports all pending untagged tasks in the background (`Yes`).
  Future<void> acceptAndImport() async {
    final files = List<String>.from(state.pendingRelPaths);
    if (files.isEmpty) return;
    state = const ExternalUntaggedTasksState(
      pendingRelPaths: [],
      dismissed: true,
    );

    final services = await ref.read(appServicesProvider.future);
    if (services == null) return;

    await ref
        .read(backgroundWorkManagerProvider.notifier)
        .runTask<int>(
          label: 'Importing tasks from Markdown notes...',
          totalUnits: files.length,
          work: (reportProgress) async {
            return services.taskSyncService.importUntaggedTasksInFiles(
              files,
              onProgress: reportProgress,
            );
          },
        );
  }
}

final externalUntaggedTasksProvider =
    NotifierProvider<ExternalUntaggedTasksNotifier, ExternalUntaggedTasksState>(
      ExternalUntaggedTasksNotifier.new,
    );
