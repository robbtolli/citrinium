import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock/app_clock.dart';
import '../../shared/widgets/citrine_emblem.dart';

const String citrineAppVersion = '1.0.0+1';

/// About Citrine screen (`FR-14`), displaying the Citrine Crystal & Fountain
/// Pen emblem (`FR-15`) and the app version. Tapping or clicking the version
/// 7 times enables Debug Mode.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  int _versionTapCount = 0;
  DateTime? _lastTapAt;

  Future<void> _handleVersionTap() async {
    final alreadyEnabled = ref.read(debugModeProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (alreadyEnabled) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Debug Mode is already enabled.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final now = DateTime.now();
    if (_lastTapAt != null && now.difference(_lastTapAt!).inSeconds > 4) {
      _versionTapCount = 0;
    }
    _lastTapAt = now;
    _versionTapCount += 1;

    final remaining = 7 - _versionTapCount;
    if (remaining <= 0) {
      _versionTapCount = 0;
      await ref.read(debugModeProvider.notifier).setEnabled(true);
      if (!mounted) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Debug Mode enabled! Open the hamburger menu to access Debug tools.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } else if (_versionTapCount >= 4) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$remaining ${remaining == 1 ? 'tap' : 'taps'} away from Debug Mode...',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final debugEnabled = ref.watch(debugModeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About Citrine')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/icons/citrine_icon.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const CitrineEmblem(size: 96),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Citrine',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Calm planning, rapid capture, and notes where you own your data.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('about-version-tile'),
                  leading: const Icon(Icons.info_outline),
                  title: const Text('App Version'),
                  subtitle: const Text(citrineAppVersion),
                  trailing: debugEnabled
                      ? Chip(
                          label: const Text('Debug Active'),
                          avatar: const Icon(Icons.bug_report, size: 16),
                        )
                      : null,
                  onTap: _handleVersionTap,
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.storage_outlined),
                  title: Text('Storage Model'),
                  subtitle: Text(
                    'Local-first Markdown vault + documented SQLite database',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
