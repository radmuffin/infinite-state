import 'package:flutter/material.dart';
import '../../state/studio_controller.dart';

class BatchTestDialog extends StatefulWidget {
  final StudioController controller;

  const BatchTestDialog({super.key, required this.controller});

  @override
  State<BatchTestDialog> createState() => _BatchTestDialogState();
}

class _BatchTestDialogState extends State<BatchTestDialog> {
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

    return Dialog(
      backgroundColor: const Color(0xFF161922),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF282D3D), width: 1.5),
      ),
      child: Container(
        width: 580,
        height: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.playlist_add_check,
                    color: Color(0xFF00E5FF), size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Automata Batch Test Suite',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Pass rate chip
                if (_results != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: passed == total
                          ? const Color(0xFF052E16)
                          : const Color(0xFF450A0A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: passed == total
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    child: Text(
                      '$passed / $total Passed ($passRate%)',
                      style: TextStyle(
                        color: passed == total
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFFF87171),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: const Color(0xFF94A3B8),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Add Test Case Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'Enter test input (e.g. 1010)...',
                      hintStyle: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 12),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF1E222D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                    ),
                    onSubmitted: (_) => _addTestCase(),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<bool>(
                  value: _newExpected,
                  dropdownColor: const Color(0xFF1E222D),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  items: const [
                    DropdownMenuItem(
                      value: true,
                      child: Text('Expect: Accept',
                          style: TextStyle(color: Color(0xFF4ADE80))),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text('Expect: Reject',
                          style: TextStyle(color: Color(0xFFF87171))),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _newExpected = val);
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _addTestCase,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Test',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4338CA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Test Suite Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E222D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF282D3D)),
                ),
                child: ListView.separated(
                  itemCount: _testCases.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Color(0xFF282D3D), height: 1),
                  itemBuilder: (context, index) {
                    final tc = _testCases[index];
                    final res =
                        _results != null && index < _results!.length
                            ? _results![index]
                            : null;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            res?.passed == true
                                ? Icons.check_circle
                                : (res == null
                                    ? Icons.help_outline
                                    : Icons.cancel),
                            size: 18,
                            color: res?.passed == true
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFF87171),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tc.input.isEmpty ? 'ε (empty)' : tc.input,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            tc.expected ? 'Expect: Accept' : 'Expect: Reject',
                            style: TextStyle(
                              color: tc.expected
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFFFCA5A5),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            res != null
                                ? (res.actual ? 'Got: Accept' : 'Got: Reject')
                                : '—',
                            style: TextStyle(
                              color: res?.passed == true
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFF87171),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16),
                            color: const Color(0xFF64748B),
                            onPressed: () => _removeTestCase(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _runAll,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Rerun All', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00E5FF),
                    side: const BorderSide(color: Color(0xFF0E7490)),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}
