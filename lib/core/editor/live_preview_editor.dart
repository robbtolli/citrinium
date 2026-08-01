import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter/material.dart' hide Decoration;
import 'package:flutter/services.dart';

import 'editor_backdrop.dart';
import 'live_preview_controller.dart';

/// The full Live Preview Editor widget for design.md §7 (M6).
class LivePreviewEditor extends StatefulWidget {
  const LivePreviewEditor({
    super.key,
    required this.controller,
    this.focusNode,
    this.onLinkTap,
    this.onSaveRequested,
    this.noteTitles = const [],
    this.tagNames = const [],
    this.contextNames = const [],
    this.padding = const EdgeInsets.all(16.0),
  });

  final LivePreviewController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onLinkTap;
  final VoidCallback? onSaveRequested;

  final List<String> noteTitles;
  final List<String> tagNames;
  final List<String> contextNames;

  final EdgeInsets padding;

  @override
  State<LivePreviewEditor> createState() => _LivePreviewEditorState();
}

class _LivePreviewEditorState extends State<LivePreviewEditor> {
  late FocusNode _effectiveFocusNode;
  final FocusNode _editableFocusNode = FocusNode();
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  String _autocompleteQuery = '';
  String _autocompleteType = ''; // '[[', '#', '@'
  List<String> _autocompleteResults = [];

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.onTaskCheckboxLongPressed = (offset, markerChar) {
      _openTaskContextMenu(context, offset, markerChar);
    };
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _editableFocusNode.dispose();
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    _checkAutocompleteTrigger();
    setState(() {});
  }

  void _checkAutocompleteTrigger() {
    final sel = widget.controller.selection;
    if (!sel.isValid || !sel.isCollapsed) {
      _hideAutocomplete();
      return;
    }

    final pos = sel.start;
    final text = widget.controller.text;

    if (pos == 0) {
      _hideAutocomplete();
      return;
    }

    // Check last typed characters up to 30 chars back
    final searchStart = (pos - 30).clamp(0, text.length);
    final prefixText = text.substring(searchStart, pos);

    final wikilinkIdx = prefixText.lastIndexOf('[[');
    final tagIdx = prefixText.lastIndexOf('#');
    final contextIdx = prefixText.lastIndexOf('@');

    int maxIdx = -1;
    String type = '';

    if (wikilinkIdx != -1 && wikilinkIdx > maxIdx) {
      maxIdx = wikilinkIdx;
      type = '[[';
    }
    if (tagIdx != -1 && tagIdx > maxIdx) {
      maxIdx = tagIdx;
      type = '#';
    }
    if (contextIdx != -1 && contextIdx > maxIdx) {
      maxIdx = contextIdx;
      type = '@';
    }

    if (maxIdx != -1) {
      final queryStart = searchStart + maxIdx + type.length;
      if (queryStart <= pos) {
        final query = text.substring(queryStart, pos);
        if (!query.contains(' ') && !query.contains('\n') && !query.contains(']')) {
          _autocompleteType = type;
          _autocompleteQuery = query.toLowerCase();
          _updateAutocompleteResults();
          if (_autocompleteResults.isNotEmpty) {
            _overlayController.show();
            return;
          }
        }
      }
    }

    _hideAutocomplete();
  }

  void _updateAutocompleteResults() {
    List<String> pool;
    if (_autocompleteType == '[[') {
      pool = widget.noteTitles;
    } else if (_autocompleteType == '#') {
      pool = widget.tagNames;
    } else {
      pool = widget.contextNames;
    }

    _autocompleteResults = pool
        .where((item) => item.toLowerCase().contains(_autocompleteQuery))
        .take(8)
        .toList();
  }

  void _hideAutocomplete() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
  }

  void _insertAutocompleteCompletion(String selected) {
    final sel = widget.controller.selection;
    if (!sel.isValid) return;

    final pos = sel.start;
    final text = widget.controller.text;

    final searchStart = (pos - 30).clamp(0, text.length);
    final prefixText = text.substring(searchStart, pos);
    final triggerIdx = prefixText.lastIndexOf(_autocompleteType);

    if (triggerIdx != -1) {
      final replaceStart = searchStart + triggerIdx + _autocompleteType.length;
      final suffix = _autocompleteType == '[[' ? ']]' : '';

      final newText = text.replaceRange(replaceStart, pos, '$selected$suffix');
      final newCaret = replaceStart + selected.length + suffix.length;

      widget.controller.value = widget.controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newCaret),
      );
    }
    _hideAutocomplete();
  }

  // Key handling for shortcuts (Cmd+B/I/K, Enter, Tab, Shift-Tab, Cmd+Enter)
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isMetaOrControl = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    // Autocomplete navigation
    if (_overlayController.isShowing && _autocompleteResults.isNotEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _hideAutocomplete();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _insertAutocompleteCompletion(_autocompleteResults.first);
        return KeyEventResult.handled;
      }
    }

    // Cmd/Ctrl + B -> Bold
    if (isMetaOrControl && event.logicalKey == LogicalKeyboardKey.keyB) {
      _toggleDelimiter('**');
      return KeyEventResult.handled;
    }

    // Cmd/Ctrl + I -> Italic
    if (isMetaOrControl && event.logicalKey == LogicalKeyboardKey.keyI) {
      _toggleDelimiter('*');
      return KeyEventResult.handled;
    }

    // Cmd/Ctrl + K -> Link
    if (isMetaOrControl && event.logicalKey == LogicalKeyboardKey.keyK) {
      _insertLink();
      return KeyEventResult.handled;
    }

    // Cmd/Ctrl + Enter -> Toggle task state
    if (isMetaOrControl && event.logicalKey == LogicalKeyboardKey.enter) {
      widget.controller.toggleCurrentTaskState();
      return KeyEventResult.handled;
    }

    // Enter -> List continuation or marker removal
    if (!isMetaOrControl && event.logicalKey == LogicalKeyboardKey.enter) {
      if (_handleEnterListContinuation()) {
        return KeyEventResult.handled;
      }
    }

    // Tab / Shift-Tab -> Indent / Outdent list
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (isShift) {
        _handleOutdent();
      } else {
        _handleIndent();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  static int _getLineStart(String text, int pos) {
    if (pos <= 0) return 0;
    final clamped = pos.clamp(0, text.length);
    final idx = text.lastIndexOf('\n', clamped - 1);
    return idx == -1 ? 0 : idx + 1;
  }

  bool _handleEnterListContinuation() {
    final sel = widget.controller.selection;
    if (!sel.isValid || !sel.isCollapsed) return false;

    final pos = sel.start;
    final text = widget.controller.text;

    final lineStart = _getLineStart(text, pos);

    final lineText = text.substring(lineStart, pos);

    // Regexes for list markers
    final taskReg = RegExp(r'^([ \t]*)([-*+])[ \t]+\[.\][ \t]*(.*)$');
    final bujoReg = RegExp(r'^([ \t]*)([-*+])[ \t]+[○–][ \t]*(.*)$');
    final listReg = RegExp(r'^([ \t]*)([-*+]|\d+\.)[ \t]+(.*)$');

    Match? match;
    var isTask = false;
    var isBujo = false;

    match = taskReg.firstMatch(lineText);
    if (match != null) {
      isTask = true;
    } else {
      match = bujoReg.firstMatch(lineText);
      if (match != null) {
        isBujo = true;
      } else {
        match = listReg.firstMatch(lineText);
      }
    }

    if (match != null) {
      final indent = match.group(1)!;
      final bullet = match.group(2)!;
      final content = match.group(3)!;

      // Empty item -> remove marker
      if (content.trim().isEmpty) {
        final newText = text.replaceRange(lineStart, pos, '');
        widget.controller.value = widget.controller.value.copyWith(
          text: newText,
          selection: TextSelection.collapsed(offset: lineStart),
        );
        return true;
      }

      // Continue list
      String nextMarker;
      if (isTask) {
        nextMarker = '\n$indent$bullet [ ] ';
      } else if (isBujo) {
        nextMarker = '\n$indent$bullet ○ ';
      } else if (RegExp(r'^\d+\.$').hasMatch(bullet)) {
        final num = int.tryParse(bullet.replaceAll('.', '')) ?? 1;
        nextMarker = '\n$indent${num + 1}. ';
      } else {
        nextMarker = '\n$indent$bullet ';
      }

      final newText = text.replaceRange(pos, pos, nextMarker);
      widget.controller.value = widget.controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + nextMarker.length),
      );
      return true;
    }

    return false;
  }

  void _handleIndent() {
    final sel = widget.controller.selection;
    if (!sel.isValid) return;

    final text = widget.controller.text;
    final lineStart = _getLineStart(text, sel.start);

    final newText = text.replaceRange(lineStart, lineStart, '  ');
    widget.controller.value = widget.controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + 2),
    );
  }

  void _handleOutdent() {
    final sel = widget.controller.selection;
    if (!sel.isValid) return;

    final text = widget.controller.text;
    final lineStart = _getLineStart(text, sel.start);

    if (lineStart + 2 <= text.length && text.substring(lineStart, lineStart + 2) == '  ') {
      final newText = text.replaceRange(lineStart, lineStart + 2, '');
      final newOffset = (sel.start - 2).clamp(lineStart, newText.length);
      widget.controller.value = widget.controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newOffset),
      );
    }
  }

  void _toggleDelimiter(String delim) {
    final sel = widget.controller.selection;
    if (!sel.isValid) return;

    final text = widget.controller.text;

    if (sel.isCollapsed) {
      final newText = text.replaceRange(sel.start, sel.start, '$delim$delim');
      widget.controller.value = widget.controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + delim.length),
      );
    } else {
      final selectedText = text.substring(sel.start, sel.end);
      final newText =
          text.replaceRange(sel.start, sel.end, '$delim$selectedText$delim');
      widget.controller.value = widget.controller.value.copyWith(
        text: newText,
        selection: TextSelection(
          baseOffset: sel.start + delim.length,
          extentOffset: sel.end + delim.length,
        ),
      );
    }
  }

  void _insertLink() {
    final sel = widget.controller.selection;
    if (!sel.isValid) return;

    final text = widget.controller.text;
    if (sel.isCollapsed) {
      const template = '[link](url)';
      final newText = text.replaceRange(sel.start, sel.start, template);
      widget.controller.value = widget.controller.value.copyWith(
        text: newText,
        selection: TextSelection(
          baseOffset: sel.start + 1,
          extentOffset: sel.start + 5,
        ),
      );
    } else {
      final selectedText = text.substring(sel.start, sel.end);
      final template = '[$selectedText](url)';
      final newText = text.replaceRange(sel.start, sel.end, template);
      widget.controller.value = widget.controller.value.copyWith(
        text: newText,
        selection: TextSelection(
          baseOffset: sel.start + selectedText.length + 3,
          extentOffset: sel.start + selectedText.length + 6,
        ),
      );
    }
  }

  void _openTaskContextMenu(BuildContext context, int offset, String currentMarker) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final position = box != null ? box.localToGlobal(Offset.zero) : Offset.zero;

    showMenu<TaskStateKind>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx + 50, position.dy + 50, 100, 100),
      items: TaskStateKind.values.where((k) => k != TaskStateKind.unknown).map((k) {
        final marker = canonicalMarkerFor(k);
        return PopupMenuItem<TaskStateKind>(
          value: k,
          child: Row(
            children: [
              Text('[$marker] ', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(k.name),
            ],
          ),
        );
      }).toList(),
    ).then((selected) {
      if (selected != null) {
        final newMarker = canonicalMarkerFor(selected);
        final text = widget.controller.text;
        if (offset >= 0 && offset < text.length) {
          final newText = text.replaceRange(offset, offset + 1, newMarker);
          widget.controller.value = widget.controller.value.copyWith(
            text: newText,
            selection: widget.controller.selection,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KeyboardListener(
      focusNode: _effectiveFocusNode,
      onKeyEvent: (event) => _handleKeyEvent(_effectiveFocusNode, event),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: OverlayPortal(
          controller: _overlayController,
          overlayChildBuilder: (context) => _buildAutocompleteOverlay(context),
          child: CustomPaint(
            painter: EditorBackdropPainter(
              text: widget.controller.text,
              selection: widget.controller.selection,
              colorScheme: theme.colorScheme,
              lineHeight: 24.0,
              padding: widget.padding,
            ),
            child: Padding(
              padding: widget.padding,
              child: EditableText(
                controller: widget.controller,
                focusNode: _editableFocusNode,
                style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 15.0,
                      height: 1.6,
                    ) ??
                    const TextStyle(fontSize: 15.0, height: 1.6),
                cursorColor: theme.colorScheme.primary,
                backgroundCursorColor:
                    theme.colorScheme.surfaceContainerHighest,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                autofocus: true,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutocompleteOverlay(BuildContext context) {
    return Positioned(
      width: 250.0,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(20.0, 40.0),
        child: Material(
          elevation: 6.0,
          borderRadius: BorderRadius.circular(8.0),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            itemCount: _autocompleteResults.length,
            itemBuilder: (context, index) {
              final item = _autocompleteResults[index];
              return ListTile(
                dense: true,
                title: Text(item, style: const TextStyle(fontSize: 14.0)),
                onTap: () => _insertAutocompleteCompletion(item),
              );
            },
          ),
        ),
      ),
    );
  }
}
