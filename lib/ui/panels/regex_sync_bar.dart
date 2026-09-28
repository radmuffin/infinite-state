import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../state/studio_controller.dart';

/// A self-contained, modular widget for bidirectional regular expression
/// synchronization with the formal finite state machine.
///
/// Can be docked under a toolbar, inside a sidebar, or shown as a card.
class RegexSyncBar extends StatefulWidget {
  final StudioController controller;
  final bool compact;

  const RegexSyncBar({
    super.key,
    required this.controller,
    this.compact = false,
  });

  @override
  State<RegexSyncBar> createState() => _RegexSyncBarState();
}

class _RegexSyncBarState extends State<RegexSyncBar> {
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  String _lastSyncedPattern = '';

  static const List<({String label, String pattern})> _presets = [
    (label: 'Ends with "abb"', pattern: '(a|b)*abb'),
    (label: 'Second from end is 1', pattern: '(0|1)*1(0|1)'),
    (label: 'Alternating pairs (01|10)+', pattern: '(01|10)+'),
    (label: 'Exactly two 1s', pattern: '0*10*10*'),
    (label: 'Contains "aa" or "bb"', pattern: '(a|b)*(aa|bb)(a|b)*'),
    (label: 'Identifier [a-z][a-z0-9]*', pattern: '(a|b|c)(a|b|c|0|1)*'),
  ];

  @override
  void initState() {
    super.initState();
    _lastSyncedPattern = widget.controller.regexPattern;
    _textController = TextEditingController(text: _lastSyncedPattern);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (widget.controller.regexPattern != _lastSyncedPattern && !_focusNode.hasFocus) {
      _lastSyncedPattern = widget.controller.regexPattern;
      _textController.text = _lastSyncedPattern;
    }
  }

  void _submitRegex() {
    final text = _textController.text.trim();
    widget.controller.setRegexPattern(text, syncToGraph: true);
  }

  void _insertSymbol(String symbol) {
    final text = _textController.text;
    final selection = _textController.selection;
    final newText = selection.isValid
        ? text.replaceRange(selection.start, selection.end, symbol)
        : '$text$symbol';
    final newOffset = (selection.isValid ? selection.start : text.length) + symbol.length;

    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    widget.controller.setRegexPattern(newText);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        _onControllerChanged();

        final hasError = widget.controller.regexError != null;
        final isOutOfSync = widget.controller.isGraphOutOfSyncWithRegex;
        final autoSync = widget.controller.regexAutoSync;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF131722),
            border: Border(
              bottom: BorderSide(color: Color(0xFF222838), width: 1.5),
            ),
          ),
          child: Row(
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.terminal, size: 13, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'REGEX',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Regex Input Field
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0E14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasError
                          ? const Color(0xFFEF4444)
                          : (isOutOfSync
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF2A334A)),
                      width: hasError ? 1.5 : 1.0,
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          style: TextStyle(
                            color: hasError ? const Color(0xFFFCA5A5) : Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: 'Enter regex (e.g. (a|b)*abb, a+, a?)...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade600,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          onChanged: (val) {
                            widget.controller.setRegexPattern(val);
                          },
                          onSubmitted: (_) => _submitRegex(),
                        ),
                      ),

                      // Quick insert epsilon button (+ε)
                      InkWell(
                        onTap: () => _insertSymbol('ε'),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2433),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: const Text(
                            '+ε',
                            style: TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Status Badge
              _buildStatusBadge(hasError, isOutOfSync),

              const SizedBox(width: 10),

              // Action Buttons
              // 1. Sync Regex -> Graph Button
              OutlinedButton.icon(
                onPressed: _submitRegex,
                icon: const Icon(Icons.arrow_downward, size: 14),
                label: const Text('Regex → Graph', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00E5FF),
                  side: const BorderSide(color: Color(0xFF0E7490)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // 2. Sync Graph -> Regex Button
              OutlinedButton.icon(
                onPressed: () {
                  widget.controller.syncGraphToRegex();
                  _textController.text = widget.controller.regexPattern;
                },
                icon: const Icon(Icons.arrow_upward, size: 14),
                label: const Text('Graph → Regex', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFA5B4FC),
                  side: const BorderSide(color: Color(0xFF4338CA)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Auto-sync Toggle Pill
              InkWell(
                onTap: widget.controller.toggleRegexAutoSync,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: autoSync
                        ? const Color(0xFF064E3B)
                        : const Color(0xFF1E222D),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: autoSync
                          ? const Color(0xFF10B981)
                          : const Color(0xFF334155),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sync,
                        size: 13,
                        color: autoSync
                            ? const Color(0xFF34D399)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Auto-Sync',
                        style: TextStyle(
                          color: autoSync
                              ? const Color(0xFF34D399)
                              : const Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Presets Dropdown
              PopupMenuButton<String>(
                tooltip: 'Textbook Regex Presets',
                icon: const Icon(Icons.bookmarks_outlined, size: 17, color: Color(0xFF94A3B8)),
                color: const Color(0xFF1E2333),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
                onSelected: (pattern) {
                  _textController.text = pattern;
                  widget.controller.setRegexPattern(pattern, syncToGraph: true);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    enabled: false,
                    height: 28,
                    child: Text(
                      'PRESET REGEX PATTERNS',
                      style: TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  ..._presets.map(
                    (p) => PopupMenuItem(
                      value: p.pattern,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.label,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            p.pattern,
                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Copy Regex Button
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy Regex to Clipboard',
                color: const Color(0xFF94A3B8),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _textController.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied regex "${_textController.text}" to clipboard'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: const Color(0xFF1E2433),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(bool hasError, bool isOutOfSync) {
    if (hasError) {
      return Tooltip(
        message: widget.controller.regexError ?? 'Invalid syntax',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF450A0A),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFEF4444)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 12, color: Color(0xFFEF4444)),
              SizedBox(width: 4),
              Text(
                'Syntax Error',
                style: TextStyle(
                  color: Color(0xFFFCA5A5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isOutOfSync) {
      return Tooltip(
        message: 'Graph and Regex are not synced. Click a sync button to align them.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF451A03),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFF59E0B)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFF59E0B)),
              SizedBox(width: 4),
              Text(
                'Modified',
                style: TextStyle(
                  color: Color(0xFFFCD34D),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF052E16),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF22C55E)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 12, color: Color(0xFF22C55E)),
          SizedBox(width: 4),
          Text(
            'Synced',
            style: TextStyle(
              color: Color(0xFF86EFAC),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
