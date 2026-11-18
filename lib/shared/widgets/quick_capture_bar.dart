import 'package:citrine_core/citrine_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/index/index_providers.dart';
import '../../core/workspace/workspace_state.dart';

enum RapidCaptureKind {
  task('- [ ] ', 'Task', Icons.check_box_outline_blank),
  event('- ○ ', 'Event', Icons.panorama_fish_eye),
  note('- – ', 'Note', Icons.notes);

  const RapidCaptureKind(this.prefix, this.label, this.icon);
  final String prefix;
  final String label;
  final IconData icon;
}

/// Persistent Quick Capture bar (`P-01`, `P-02`, `C-01`, `C-03`, `C-04`) with:
/// - Minimal type switching (`Task` / `Event` / `Note`)
/// - Sticky `[ Inbox | Today ]` destination toggle (`C-01`)
/// - Live natural-language date/time detection (`NlDateParser`, `C-04`) with
///   explicit user confirmation before rewriting the matched span.
class QuickCaptureBar extends ConsumerStatefulWidget {
  const QuickCaptureBar({
    this.hideWhenExternalKeyboardOpen = false,
    super.key,
  });

  final bool hideWhenExternalKeyboardOpen;

  @override
  ConsumerState<QuickCaptureBar> createState() => _QuickCaptureBarState();
}

class _QuickCaptureBarState extends ConsumerState<QuickCaptureBar> {
  final TextEditingController _controller = TextEditingController();
  RapidCaptureKind _kind = RapidCaptureKind.task;
  NlDateMatch? _detectedMatch;
  bool _applyNlDate = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    final match = NlDateParser.detect(text);
    if (match?.matchedText != _detectedMatch?.matchedText ||
        match?.dueDate != _detectedMatch?.dueDate ||
        match?.dueTime != _detectedMatch?.dueTime) {
      setState(() {
        _detectedMatch = match;
        if (match != null) {
          _applyNlDate = true;
        }
      });
    }
  }

  Future<void> _submitCapture() async {
    final originalText = _controller.text;
    var raw = originalText.trim();
    if (raw.isEmpty) return;

    final match = _detectedMatch;
    if (match != null && _applyNlDate) {
      // Strip the matched phrase from originalText and splice canonical 📅/⏰ tokens
      final transformed = match.applyToLineText(
        originalText,
        defaultPrefix: _kind.prefix,
      );
      raw = transformed.trim();
    }

    final dest = ref.read(workspaceStateProvider).captureDestination;
    final toToday = dest == CaptureDestination.today;

    _controller.clear();
    setState(() {
      _detectedMatch = null;
      _isEditing = false;
    });

    final relPath = await ref.read(vaultMutationProvider).captureLine(
      rawInput: raw,
      toTodayLog: toToday,
      defaultPrefix: _kind.prefix,
    );

    ref
        .read(workspaceStateProvider.notifier)
        .completeOnboardingStep('quick_capture');

    if (mounted && relPath.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Captured to $relPath'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (widget.hideWhenExternalKeyboardOpen && keyboardOpen && !_isEditing) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final workspace = ref.watch(workspaceStateProvider);
    final dest = workspace.captureDestination;
    final screenSize = MediaQuery.sizeOf(context);
    final isNarrow = screenSize.width < 480;
    final isShortKeyboard = keyboardOpen && screenSize.height < 550;

    final typeButton = PopupMenuButton<RapidCaptureKind>(
      tooltip: 'Entry type (${_kind.label})',
      initialValue: _kind,
      onSelected: (k) => setState(() => _kind = k),
      itemBuilder: (context) => [
        for (final k in RapidCaptureKind.values)
          PopupMenuItem(
            value: k,
            child: Row(
              children: [
                Icon(k.icon, size: 18),
                const SizedBox(width: 8),
                Text('${k.label} (${k.prefix.trim()})'),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _kind.icon,
              size: 16,
              color: colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              _kind.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );

    final destToggle = SegmentedButton<CaptureDestination>(
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: CaptureDestination.inbox,
          label: Text('Inbox', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment(
          value: CaptureDestination.today,
          label: Text('Today', style: TextStyle(fontSize: 12)),
        ),
      ],
      selected: {dest},
      onSelectionChanged: (selection) {
        ref
            .read(workspaceStateProvider.notifier)
            .setCaptureDestination(selection.first);
      },
    );

    final inputWidget = _isEditing
        ? TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText:
                  'Quick capture ${_kind.label.toLowerCase()} to ${dest.label} (e.g. "tomorrow 5pm @phone")...',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: isShortKeyboard ? 8 : 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onSubmitted: (_) => _submitCapture(),
          )
        : InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _isEditing = true),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isNarrow
                    ? 'Capture to ${dest.label}...'
                    : 'Quick capture ${_kind.label.toLowerCase()} to ${dest.label}...',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );

    final sendButton = IconButton.filled(
      tooltip: 'Add to ${dest.label}',
      icon: const Icon(Icons.send, size: 18),
      onPressed: _submitCapture,
    );

    return Material(
      elevation: 3,
      color: colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: isShortKeyboard ? 4 : 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Natural-language date/time confirmation chip (C-04)
              if (_detectedMatch != null)
                Padding(
                  padding: EdgeInsets.only(bottom: isShortKeyboard ? 4 : 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: FilterChip(
                      visualDensity: VisualDensity.compact,
                      selected: _applyNlDate,
                      avatar: const Icon(Icons.auto_awesome, size: 14),
                      label: Text(
                        'Recognized "${_detectedMatch!.matchedText}" → ${_detectedMatch!.summaryLabel}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onSelected: (v) => setState(() => _applyNlDate = v),
                    ),
                  ),
                ),
              if (isNarrow && _isEditing) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    typeButton,
                    destToggle,
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => setState(() => _isEditing = false),
                      child: const Text('Done'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: inputWidget),
                    const SizedBox(width: 6),
                    sendButton,
                  ],
                ),
              ] else
                Row(
                  children: [
                    if (!isNarrow) ...[
                      typeButton,
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: inputWidget),
                    const SizedBox(width: 8),
                    destToggle,
                    if (!isNarrow || _isEditing) ...[
                      const SizedBox(width: 6),
                      sendButton,
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
