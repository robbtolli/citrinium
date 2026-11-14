import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock/app_clock.dart';

/// Opens the Debug Mode "Override Current Date" dialog (`FR-14`), allowing
/// the user to pick any calendar date, step `-1 Day` / `+1 Day`, or reset
/// back to the real system clock.
Future<void> showDebugDateOverrideDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final clock = ref.read(appClockProvider);
  final initialDate = clock.today();

  await showDialog<void>(
    context: context,
    builder: (ctx) => _DebugDateOverrideDialog(initialDate: initialDate),
  );
}

class _DebugDateOverrideDialog extends ConsumerWidget {
  const _DebugDateOverrideDialog({required this.initialDate});

  final DateTime initialDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = ref.watch(appClockProvider);
    final activeDate = clock.today();
    final activeIso = NlDateParser.formatIsoDate(activeDate);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.science_outlined),
          SizedBox(width: 8),
          Text('Override Current Date'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clock.isOverridden
                ? 'Active override: $activeIso'
                : 'Using real system date: $activeIso',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('debug-date-prev-day'),
                onPressed: () => ref.read(appClockProvider.notifier).stepDays(-1),
                icon: const Icon(Icons.chevron_left),
                label: const Text('-1 Day'),
              ),
              OutlinedButton.icon(
                key: const Key('debug-date-next-day'),
                onPressed: () => ref.read(appClockProvider.notifier).stepDays(1),
                icon: const Icon(Icons.chevron_right),
                label: const Text('+1 Day'),
              ),
              FilledButton.tonalIcon(
                key: const Key('debug-date-pick'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: activeDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    await ref
                        .read(appClockProvider.notifier)
                        .setOverrideDate(picked);
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: const Text('Pick Date…'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (clock.isOverridden)
          TextButton(
            key: const Key('debug-date-reset'),
            onPressed: () async {
              await ref.read(appClockProvider.notifier).reset();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Reset to Real Time'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
