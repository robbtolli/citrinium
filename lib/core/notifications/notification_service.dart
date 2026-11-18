import 'dart:async';
import 'dart:io';

import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/metadata_badge.dart';
import '../clock/app_clock.dart';
import '../index/index_providers.dart';
import '../workspace/workspace_state.dart';

/// Delivery mode after a contextual notification permission check (`E-11`, `design.md` §8).
enum NotificationDeliveryMode {
  /// Exact local alarms/notifications permitted.
  exact,

  /// Android 13+ graceful degradation when exact-alarm permission is not granted
  /// (`design.md` §8, `P-04`).
  inexactGraceful,

  /// Permission not yet granted or declined.
  ungranted,
}

/// Actions available directly on a reminder notification (`E-12`, `A-03`).
enum NotificationActionKind {
  snooze15m('Snooze +15m'),
  snooze1h('Snooze +1h'),
  rescheduleTomorrow('Tomorrow'),
  markDone('Done');

  const NotificationActionKind(this.label);
  final String label;
}

/// Platform bridge for scheduling rolling-window native notifications across
/// Android, iOS, macOS, Windows, and Linux (`FR-05`, `E-08`–`E-12`, `design.md` §8).
class PlatformNotificationBridge {
  static const MethodChannel _channel = MethodChannel(
    'citrine/native_notifications',
  );

  List<ScheduledReminder> _lastScheduledWindow = const [];
  NotificationDeliveryMode _deliveryMode = NotificationDeliveryMode.exact;

  /// Current rolling window of scheduled notifications (capped at 64 per `design.md` §8).
  List<ScheduledReminder> get scheduledWindow =>
      List.unmodifiable(_lastScheduledWindow);

  NotificationDeliveryMode get deliveryMode => _deliveryMode;

  /// Requests native OS notification permission contextually (`E-11`).
  /// Degrades gracefully to [NotificationDeliveryMode.inexactGraceful] on
  /// Android 13+ if exact-alarm permission is unavailable (`design.md` §8).
  Future<NotificationDeliveryMode> requestContextualPermission() async {
    try {
      final result = await _channel.invokeMethod<String>('requestPermission');
      if (result == 'inexact') {
        _deliveryMode = NotificationDeliveryMode.inexactGraceful;
        return _deliveryMode;
      }
      if (result == 'denied') {
        _deliveryMode = NotificationDeliveryMode.ungranted;
        return _deliveryMode;
      }
    } on MissingPluginException {
      // Desktop / test environment without custom platform channel handler:
      // default to native desktop notification center / in-memory bridge.
      _deliveryMode = NotificationDeliveryMode.exact;
    } on PlatformException {
      _deliveryMode = NotificationDeliveryMode.inexactGraceful;
    }
    return _deliveryMode;
  }

  /// Synchronizes the rolling window of derived reminders (max 64) with the
  /// platform notification scheduler (`design.md` §8, `FR-05`).
  Future<void> syncRollingWindowSchedule(List<ScheduledReminder> window) async {
    _lastScheduledWindow = List<ScheduledReminder>.from(window);
    try {
      await _channel.invokeMethod<void>('syncRollingWindow', {
        'deliveryMode': _deliveryMode.name,
        'reminders': [
          for (final r in window)
            {
              'id': r.notificationId,
              'entryUniqueKey': r.entryUniqueKey,
              'title': r.title,
              'scheduledAtMs': r.scheduledAt.millisecondsSinceEpoch,
              'dueDateIso': r.dueDateIso,
              'dueTime': r.dueTime,
              'leadTimeLabel': r.leadTime.label,
              'isRecurring': r.isRecurring,
              'isSnoozed': r.isSnoozed,
              'actions': [
                for (final a in NotificationActionKind.values) a.name,
              ],
            },
        ],
      });
    } on MissingPluginException {
      // No-op when running in unit/widget tests or desktop fallback.
    } on PlatformException {
      // Degrade gracefully without crashing user flow (P-04).
    }
  }

  /// Fires an immediate desktop/local alert (e.g. via `notify-send` on Linux
  /// when available, or method channel on mobile/macOS/Windows) for testing or
  /// due-now alerts (`FR-05`, `E-11`).
  Future<void> dispatchImmediateNativeAlert({
    required String title,
    required String body,
  }) async {
    try {
      await _channel.invokeMethod<void>('showImmediate', {
        'title': title,
        'body': body,
      });
    } on Object {
      if (Platform.isLinux) {
        try {
          await Process.run('notify-send', [title, body]);
        } on Object {
          // Ignore if notify-send is not installed in headless environment.
        }
      }
    }
  }
}

final platformNotificationBridgeProvider = Provider<PlatformNotificationBridge>(
  (ref) => PlatformNotificationBridge(),
);

/// Reactive provider that re-derives the 64-item rolling window of upcoming
/// reminders from vault entries (`📅`, `⏰`, `🔁`) and operational snooze/lead
/// state on every vault or workspace change (`E-08`, `E-10`, `E-12`, `design.md` §8).
final rollingReminderWindowProvider = Provider<List<ScheduledReminder>>((ref) {
  final entriesAsync = ref.watch(allEntriesWithDocumentsProvider);
  final workspace = ref.watch(workspaceStateProvider);
  final bridge = ref.watch(platformNotificationBridgeProvider);

  final entries = entriesAsync.value ?? const [];
  final clock = ref.watch(appClockProvider);
  final window = ReminderDerivationEngine.deriveRollingWindow(
    entries: entries,
    now: clock.now(),
    snoozedUntilMsByTaskKey: workspace.snoozedUntilMsByTaskKey,
    reminderLeadMinutesByTaskKey: workspace.reminderLeadMinutesByTaskKey,
    defaultLeadMinutes: workspace.defaultReminderLeadMinutes,
  );

  // Push updated rolling window to the platform notification bridge
  bridge.syncRollingWindowSchedule(window);
  return window;
});

/// Executes a direct notification action (`Snooze +15m`, `Snooze +1h`,
/// `Reschedule Tomorrow`, or `Mark Done`, `E-12`, `A-03`) for [reminder].
Future<void> executeReminderNotificationAction({
  required WidgetRef ref,
  required ScheduledReminder reminder,
  required NotificationActionKind action,
  DateTime? now,
}) async {
  final currentNow = now ?? ref.read(appClockProvider).now();
  final workspaceNotifier = ref.read(workspaceStateProvider.notifier);
  final entries = ref.read(allEntriesWithDocumentsProvider).value ?? const [];
  final item = entries
      .where((e) => e.uniqueKey == reminder.entryUniqueKey)
      .firstOrNull;

  switch (action) {
    case NotificationActionKind.snooze15m:
      await workspaceNotifier.snoozeTask(
        reminder.entryUniqueKey,
        currentNow.add(const Duration(minutes: 15)),
      );
    case NotificationActionKind.snooze1h:
      await workspaceNotifier.snoozeTask(
        reminder.entryUniqueKey,
        currentNow.add(const Duration(hours: 1)),
      );
    case NotificationActionKind.rescheduleTomorrow:
      await workspaceNotifier.clearSnooze(reminder.entryUniqueKey);
      if (item != null) {
        final tomorrowIso = NlDateParser.formatIsoDate(
          currentNow.add(const Duration(days: 1)),
        );
        await ref
            .read(vaultMutationProvider)
            .updateEntryInPlace(item, dueDate: tomorrowIso);
      }
    case NotificationActionKind.markDone:
      await workspaceNotifier.clearSnooze(reminder.entryUniqueKey);
      if (item != null) {
        await ref
            .read(vaultMutationProvider)
            .completeOrAdvanceTask(item, now: currentNow);
      }
  }
}

/// Requests notification permission contextually the first time the user sets
/// a reminder or snooze on a device (`E-11`).
Future<bool> ensureContextualNotificationPermission(
  BuildContext context,
  WidgetRef ref,
) async {
  final workspace = ref.read(workspaceStateProvider);
  if (workspace.notificationPermissionGranted) return true;

  final bridge = ref.read(platformNotificationBridgeProvider);
  final workspaceNotifier = ref.read(workspaceStateProvider.notifier);

  final consented = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Enable Gentle Reminders?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: const Text(
          'Citrine uses your device\'s native notification center to deliver reminders and snoozes at the times you choose.\n\n'
          'Reminders are calm and non-punitive — you can snooze or reschedule directly from any notification.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(ctx).pop(true),
          icon: const Icon(Icons.notifications_active_outlined, size: 16),
          label: const Text('Enable Notifications'),
        ),
      ],
    ),
  );

  if (consented == true) {
    unawaited(workspaceNotifier.setNotificationPermissionGranted(true));
    unawaited(bridge.requestContextualPermission());
    return true;
  }
  return false;
}

/// Opens the Rolling-Window Reminders & Snooze Center bottom sheet (`E-08`,
/// `E-10`, `E-12`).
Future<void> showRemindersCenterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _RemindersCenterSheet(),
  );
}

class _RemindersCenterSheet extends ConsumerWidget {
  const _RemindersCenterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(rollingReminderWindowProvider);
    final bridge = ref.watch(platformNotificationBridgeProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upcoming Reminders (${reminders.length}/64 rolling window)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Re-derived from your vault\'s 📅, ⏰, and 🔁 metadata (${bridge.deliveryMode == NotificationDeliveryMode.inexactGraceful ? 'Inexact alarm fallback active' : 'Native OS scheduling active'}). Snooze or reschedule any item directly:',
                style: theme.textTheme.bodySmall,
              ),
              const Divider(height: 16),
              Expanded(
                child: reminders.isEmpty
                    ? const Center(
                        child: Text(
                          'No upcoming reminders in the next 14 days.\nAdd 📅 / ⏰ or tap "⏰ Snooze / Remind" on any task to schedule one.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: reminders.length,
                        itemBuilder: (context, index) {
                          final r = reminders[index];
                          final hh = r.scheduledAt.hour.toString().padLeft(
                            2,
                            '0',
                          );
                          final mm = r.scheduledAt.minute.toString().padLeft(
                            2,
                            '0',
                          );
                          final dateStr = NlDateParser.formatIsoDate(
                            r.scheduledAt,
                          );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r.title,
                                          style: theme.textTheme.titleSmall,
                                        ),
                                      ),
                                      if (r.isSnoozed)
                                        const MetadataBadge(
                                          label: 'Snoozed',
                                          fontSize: 10,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '🔔 $dateStr at $hh:$mm · ${r.leadTime.label}${r.isRecurring ? ' · 🔁 ${r.recurrenceText}' : ''} · ${r.relPath}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      for (final act
                                          in NotificationActionKind.values)
                                        ActionChip(
                                          visualDensity: VisualDensity.compact,
                                          label: Text(
                                            act.label,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                          onPressed: () async {
                                            await executeReminderNotificationAction(
                                              ref: ref,
                                              reminder: r,
                                              action: act,
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
