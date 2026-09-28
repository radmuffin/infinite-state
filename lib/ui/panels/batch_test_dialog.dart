import 'package:flutter/material.dart';
import '../../state/studio_controller.dart';

class BatchTestDialog extends StatelessWidget {
  final StudioController controller;

  const BatchTestDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161922),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF282D3D), width: 1.5),
      ),
      child: SizedBox(
        width: 580,
        height: 520,
        child: BatchTestView(
          controller: controller,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

class BatchTestView extends StatefulWidget {
  final StudioController controller;
  final VoidCallback? onClose;

  const BatchTestView({
    super.key,
    required this.controller,
    this.onClose,
  });

  @override
  State<BatchTestView> createState() => _BatchTestViewState();
}

class _BatchTestViewState extends State<BatchTestView> {
  final List<({String input, bool expected})> _testCases = [
    (input: '0', expected: true),
    (input: '11', expected: true),
    (input: '110', expected: true),
    (input: '1001', expected: true),
    (input: '1', expected: false),
    (input: '10', expected: false),
    (input: '100', expected: false),
  ];

  List<BatchTestResult>? _results;
  final TextEditingController _inputController = TextEditingController();
  bool _newExpected = true;

  @override
  void initState() {
    super.initState();
    _runAll();
  }

  void _runAll() {
    setState(() {
      _results = widget.controller.runBatchTests(_testCases);
    });
  }

  void _addTestCase() {
    final text = _inputController.text.trim();
    setState(() {
      _testCases.add((input: text, expected: _newExpected));
      _inputController.clear();
      _runAll();
    });
  }

  void _removeTestCase(int index) {
    setState(() {
      _testCases.removeAt(index);
      _runAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _results?.length ?? 0;
    final passed = _results?.where((r) => r.passed).length ?? 0;
    final passRate = total > 0 ? (passed / total * 100).toStringAsFixed(0) : '0';

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
                const Icon(Icons.playlist_add_check,
                    color: Color(0xFF00E5FF), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'BATCH TESTS',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                // Pass rate chip
                if (_results != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: passed == total
                          ? const Color(0xFF052E16)
                          : const Color(0xFF450A0A),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: passed == total
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '$passed/$total ($passRate%)',
                      style: TextStyle(
                        color: passed == total
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFFF87171),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  tooltip: 'Rerun All',
                  color: const Color(0xFF00E5FF),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: _runAll,
                ),
                if (widget.onClose != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: 'Close Panel',
                    color: const Color(0xFF94A3B8),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: widget.onClose,
                  ),
                ],
              ],
            ),
          ),

          // Add Test Case Input Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF232838), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: TextField(
                          controller: _inputController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          decoration: InputDecoration(
                            hintText: 'Input (e.g. 1010)...',
                            hintStyle: const TextStyle(
                                color: Color(0xFF64748B), fontSize: 11),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            filled: true,
                            fillColor: const Color(0xFF1E222D),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide:
                                  const BorderSide(color: Color(0xFF334155)),
                            ),
                          ),
                          onSubmitted: (_) => _addTestCase(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Expect Accept/Reject toggle chip
                    InkWell(
                      onTap: () {
                        setState(() => _newExpected = !_newExpected);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: _newExpected
                              ? const Color(0xFF064E3B)
                              : const Color(0xFF450A0A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _newExpected
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _newExpected ? '✓ Accept' : '✕ Reject',
                          style: TextStyle(
                            color: _newExpected
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFF87171),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: _addTestCase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4338CA),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(36, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('Add',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Test Suite Table
          Expanded(
            child: ListView.separated(
              itemCount: _testCases.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: Color(0xFF222738), height: 1),
              itemBuilder: (context, index) {
                final tc = _testCases[index];
                final res = _results != null && index < _results!.length
                    ? _results![index]
                    : null;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        res?.passed == true
                            ? Icons.check_circle
                            : (res == null
                                ? Icons.help_outline
                                : Icons.cancel),
                        size: 16,
                        color: res?.passed == true
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFFF87171),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tc.input.isEmpty ? 'ε (empty)' : tc.input,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: tc.expected
                              ? const Color(0xFF052E16)
                              : const Color(0xFF450A0A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tc.expected ? 'Exp: ✓' : 'Exp: ✕',
                          style: TextStyle(
                            color: tc.expected
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFFFCA5A5),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        res != null
                            ? (res.actual ? 'Got: ✓' : 'Got: ✕')
                            : '—',
                        style: TextStyle(
                          color: res?.passed == true
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFF87171),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 15),
                        color: const Color(0xFF64748B),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 20, minHeight: 20),
                        onPressed: () => _removeTestCase(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}
