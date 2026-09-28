import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../state/studio_controller.dart';

/// Right-sidebar panel for formal bidirectional Regular Expression synchronization.
class RegexPanel extends StatefulWidget {
  final StudioController controller;
  final VoidCallback? onClose;

  const RegexPanel({
    super.key,
    required this.controller,
    this.onClose,
  });

  @override
  State<RegexPanel> createState() => _RegexPanelState();
}

class _RegexPanelState extends State<RegexPanel> {
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  String _lastSyncedPattern = '';

  static const List<({String label, String pattern, String description})> _presets = [
    (
      label: 'Ends with "abb"',
      pattern: '(a|b)*abb',
      description: 'Standard textbook NFA benchmark',
    ),
    (
      label: 'Second from end is 1',
      pattern: '(0|1)*1(0|1)',
      description: 'Classic NFA requiring 2ⁿ subset construction for DFA',
    ),
    (
      label: 'Alternating pairs',
      pattern: '(01|10)+',
      description: 'Repeats alternating binary digits 1 or more times',
    ),
    (
      label: 'Exactly two 1s',
      pattern: '0*10*10*',
      description: 'Binary strings containing exactly two ones',
    ),
    (
      label: 'Contains "aa" or "bb"',
      pattern: '(a|b)*(aa|bb)(a|b)*',
      description: 'Substrings with consecutive identical symbols',
    ),
    (
      label: 'Identifier [a-c][a-c0-1]*',
      pattern: '(a|b|c)(a|b|c|0|1)*',
      description: 'Lexer identifier token matching',
    ),
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

  void _submitRegexToGraph() {
    final text = _textController.text.trim();
    widget.controller.setRegexPattern(text, syncToGraph: true);
  }

  void _extractRegexFromGraph() {
    widget.controller.syncGraphToRegex();
    _textController.text = widget.controller.regexPattern;
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
          color: const Color(0xFF13161F),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF232838), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.code, color: Color(0xFF00E5FF), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'REGEX & LANGUAGE',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        color: const Color(0xFF94A3B8),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        onPressed: widget.onClose,
                      ),
                  ],
                ),
              ),

              // Content Area
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    // Status & Mode Banner
                    _buildStatusBanner(hasError, isOutOfSync, autoSync),

                    const SizedBox(height: 14),

                    // Expression Card
                    _buildExpressionCard(hasError),

                    const SizedBox(height: 14),

                    // Bidirectional Sync Actions Card
                    _buildSyncActionsCard(autoSync),

                    const SizedBox(height: 16),

                    // Textbook Presets Section
                    _buildPresetsSection(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBanner(bool hasError, bool isOutOfSync, bool autoSync) {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData icon;
    final String title;
    final String subtitle;

    if (hasError) {
      bgColor = const Color(0xFF450A0A);
      borderColor = const Color(0xFFEF4444);
      textColor = const Color(0xFFFCA5A5);
      icon = Icons.error_outline;
      title = 'Regex Syntax Error';
      subtitle = widget.controller.regexError ?? 'Invalid regular expression';
    } else if (isOutOfSync) {
      bgColor = const Color(0xFF451A03);
      borderColor = const Color(0xFFF59E0B);
      textColor = const Color(0xFFFCD34D);
      icon = Icons.sync_problem;
      title = 'Out of Sync';
      subtitle = 'Canvas graph or regex was edited. Click a sync action to align.';
    } else {
      bgColor = const Color(0xFF052E16);
      borderColor = const Color(0xFF22C55E);
      textColor = const Color(0xFF86EFAC);
      icon = Icons.check_circle_outline;
      title = 'In Sync with Graph';
      subtitle = autoSync
          ? 'Live Auto-Sync active — changes propagate immediately'
          : 'Expression matches current canvas automaton';
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: borderColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpressionCard(bool hasError) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A3246)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'REGULAR EXPRESSION',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 14, color: Color(0xFF94A3B8)),
                tooltip: 'Copy Regex',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _textController.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied "${_textController.text}" to clipboard'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: const Color(0xFF1E2433),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Monospace Regex Input
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            maxLines: 3,
            minLines: 1,
            style: TextStyle(
              color: hasError ? const Color(0xFFFCA5A5) : Colors.white,
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF11141D),
              hintText: 'e.g. (a|b)*abb, a+b?, 0*10*',
              hintStyle: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
              ),
            ),
            onChanged: (val) {
              widget.controller.setRegexPattern(val);
            },
            onSubmitted: (_) => _submitRegexToGraph(),
          ),

          const SizedBox(height: 10),

          // Symbol Quick-Insert Chips
          const Text(
            'Insert Symbol:',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _buildSymbolChip('ε', 'Epsilon (empty string)'),
              _buildSymbolChip('∅', 'Empty language'),
              _buildSymbolChip('*', 'Kleene star (0 or more)'),
              _buildSymbolChip('+', 'Positive closure (1 or more)'),
              _buildSymbolChip('?', 'Optional (0 or 1)'),
              _buildSymbolChip('|', 'Alternation / Union'),
              _buildSymbolChip('(', 'Open paren'),
              _buildSymbolChip(')', 'Close paren'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolChip(String symbol, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _insertSymbol(symbol),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF131722),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF2A344A)),
          ),
          child: Text(
            symbol,
            style: const TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncActionsCard(bool autoSync) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A3246)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SYNCHRONIZATION ACTIONS',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          // 1. Regex -> Graph Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitRegexToGraph,
              icon: const Icon(Icons.arrow_downward, size: 16),
              label: const Text(
                'Compile Regex → Canvas Graph',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E7490),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 2. Graph -> Regex Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _extractRegexFromGraph,
              icon: const Icon(Icons.arrow_upward, size: 16),
              label: const Text(
                'Extract Graph → Regex',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFA5B4FC),
                side: const BorderSide(color: Color(0xFF4338CA)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 3. Live Auto-Sync Switch
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Live Auto-Sync',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Propagate edits in real-time between graph and regex',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
              ),
              value: autoSync,
              activeThumbColor: const Color(0xFF10B981),
              onChanged: (val) {
                widget.controller.toggleRegexAutoSync(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TEXTBOOK REGEX PRESETS',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        ..._presets.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF263044)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              title: Text(
                p.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    p.pattern,
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    p.description,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                  ),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: () {
                  _textController.text = p.pattern;
                  widget.controller.setRegexPattern(p.pattern, syncToGraph: true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2538),
                  foregroundColor: const Color(0xFF818CF8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: Color(0xFF334155)),
                  ),
                ),
                child: const Text('Load', style: TextStyle(fontSize: 11)),
              ),
            ),
          );
        }),
      ],
    );
  }
}
