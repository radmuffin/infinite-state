import 'package:flutter/material.dart';
import '../../core/models/transition.dart';
import '../../state/studio_controller.dart';

class InspectorPanel extends StatefulWidget {
  final StudioController controller;

  const InspectorPanel({super.key, required this.controller});

  @override
  State<InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends State<InspectorPanel> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _symbolsController = TextEditingController();
  final TextEditingController _newSymbolController = TextEditingController();
  String? _lastSelectedStateId;
  String? _lastSelectedTransitionId;

  // Inline transition matrix cell editor state
  String? _editingCellFromId;
  String? _editingCellSymbol;
  bool _isAddingSymbol = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final selectedState = widget.controller.selectedState;
        final selectedTransition = widget.controller.selectedTransition;

        if (selectedState != null && selectedState.id != _lastSelectedStateId) {
          _lastSelectedStateId = selectedState.id;
          _labelController.text = selectedState.label;
        }
        if (selectedTransition != null &&
            selectedTransition.id != _lastSelectedTransitionId) {
          _lastSelectedTransitionId = selectedTransition.id;
          _symbolsController.text = selectedTransition.symbols.join(', ');
        }

        return Container(
          width: 340,
          decoration: const BoxDecoration(
            color: Color(0xFF13161F),
            border: Border(
              left: BorderSide(color: Color(0xFF232838), width: 1.5),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF232838), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tune, size: 16, color: Color(0xFF818CF8)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'INSPECTOR & MATRIX',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    if (selectedState != null || selectedTransition != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        color: const Color(0xFF94A3B8),
                        onPressed: () {
                          widget.controller.selectState(null);
                          widget.controller.selectTransition(null);
                        },
                      ),
                  ],
                ),
              ),

              // Content Area
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (selectedState != null) ...[
                      _buildStateInspector(selectedState),
                      const SizedBox(height: 16),
                    ] else if (selectedTransition != null) ...[
                      _buildTransitionInspector(selectedTransition),
                      const SizedBox(height: 16),
                    ],

                    // Interactive Two-Way Transition Matrix
                    _buildInteractiveTransitionMatrix(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStateInspector(dynamic selectedState) {
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
            children: [
              const Icon(Icons.radio_button_checked,
                  size: 15, color: Color(0xFF818CF8)),
              const SizedBox(width: 6),
              Text(
                'Selected State (${selectedState.id})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _labelController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'State Label',
              labelStyle:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF13161F),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
            onChanged: (val) {
              widget.controller.updateStateProperties(
                id: selectedState.id,
                label: val,
              );
            },
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Initial State (q₀)',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
              value: selectedState.isInitial,
              activeThumbColor: const Color(0xFF6366F1),
              onChanged: (val) {
                widget.controller.updateStateProperties(
                  id: selectedState.id,
                  isInitial: val,
                );
              },
            ),
          ),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accepting State (F)',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
              value: selectedState.isAccept,
              activeThumbColor: const Color(0xFF10B981),
              onChanged: (val) {
                widget.controller.updateStateProperties(
                  id: selectedState.id,
                  isAccept: val,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitionInspector(Transition selectedTransition) {
    final fromState =
        widget.controller.automaton.states[selectedTransition.fromId];
    final toState = widget.controller.automaton.states[selectedTransition.toId];

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
            children: [
              const Icon(Icons.arrow_right_alt,
                  size: 18, color: Color(0xFF00E5FF)),
              const SizedBox(width: 6),
              Text(
                '${fromState?.label ?? selectedTransition.fromId} → ${toState?.label ?? selectedTransition.toId}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _symbolsController,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: 'Symbols (comma-separated, e.g. 0, 1, ε)',
              labelStyle:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF13161F),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
            onChanged: (val) {
              final symbols = val
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toSet();
              widget.controller.updateTransitionSymbols(
                selectedTransition.id,
                symbols,
              );
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.controller.deleteSelected,
              icon: const Icon(Icons.delete_outline,
                  size: 15, color: Color(0xFFF87171)),
              label: const Text('Delete Edge',
                  style: TextStyle(color: Color(0xFFF87171), fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF7F1D1D)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTransitionMatrix() {
    final automaton = widget.controller.automaton;
    final alphabetList = widget.controller.fullAlphabet.toList()..sort();
    if (automaton.hasEpsilonTransitions &&
        !alphabetList.contains(Transition.epsilon)) {
      alphabetList.add(Transition.epsilon);
    }

    final statesList = automaton.states.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header & Quick Action Buttons
        Row(
          children: [
            const Icon(Icons.grid_on, size: 15, color: Color(0xFF38BDF8)),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Transition Matrix (δ)',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            // Add Symbol Button
            IconButton(
              icon: Icon(_isAddingSymbol ? Icons.close : Icons.add, size: 16),
              tooltip: _isAddingSymbol ? 'Cancel' : 'Add Symbol to Alphabet',
              color: const Color(0xFF00E5FF),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: () {
                setState(() {
                  _isAddingSymbol = !_isAddingSymbol;
                  if (!_isAddingSymbol) _newSymbolController.clear();
                });
              },
            ),
            // Add State Button
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 16),
              tooltip: 'Add State',
              color: const Color(0xFF818CF8),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: () {
                final pos = statesList.isEmpty
                    ? const Offset(400, 300)
                    : statesList.last.position + const Offset(120, 60);
                widget.controller.addStateAt(pos);
              },
            ),
          ],
        ),

        // Inline Add Symbol Field
        if (_isAddingSymbol)
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2433),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newSymbolController,
                    autofocus: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Symbol (e.g. 0, 1, a, ε)',
                      hintStyle:
                          TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _submitNewSymbol(),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: _submitNewSymbol,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: const Color(0xFF0C0E14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Add',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

        const SizedBox(height: 4),
        const Text(
          'Click any cell to edit transition targets in real-time.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
        ),
        const SizedBox(height: 10),

        if (statesList.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'No states in machine.\nDouble-click the canvas or click "+" above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161922),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF252A3C)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 34,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 34,
                columnSpacing: 18,
                headingRowColor:
                    WidgetStateProperty.all(const Color(0xFF1F2433)),
                columns: [
                  const DataColumn(
                    label: Text(
                      'State',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...alphabetList.map(
                    (sym) => DataColumn(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            sym,
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 2),
                          InkWell(
                            onTap: () => widget.controller
                                .removeAlphabetSymbol(sym),
                            child: const Icon(Icons.close,
                                size: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                rows: statesList.map((state) {
                  final isSelected =
                      state.id == widget.controller.selectedStateId;
                  final prefix = state.isInitial ? '→ ' : '';
                  final suffix = state.isAccept ? ' *' : '';

                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (_) =>
                        widget.controller.selectState(state.id),
                    cells: [
                      // State Label Cell
                      DataCell(
                        Text(
                          '$prefix${state.label}$suffix',
                          style: TextStyle(
                            color: state.isAccept
                                ? const Color(0xFF4ADE80)
                                : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Target State Cells
                      ...alphabetList.map((sym) {
                        final targets = automaton
                            .transitionsFrom(state.id)
                            .where((t) => t.symbols.contains(sym))
                            .map((t) => t.toId)
                            .toSet();

                        final targetLabels = targets
                            .map((id) => automaton.states[id]?.label ?? id)
                            .toList();

                        final displayText = targetLabels.isEmpty
                            ? '—'
                            : (targetLabels.length == 1
                                ? targetLabels.first
                                : '{${targetLabels.join(", ")}}');

                        final isEditingThisCell =
                            _editingCellFromId == state.id &&
                                _editingCellSymbol == sym;

                        return DataCell(
                          InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              setState(() {
                                if (_editingCellFromId == state.id &&
                                    _editingCellSymbol == sym) {
                                  _editingCellFromId = null;
                                  _editingCellSymbol = null;
                                } else {
                                  _editingCellFromId = state.id;
                                  _editingCellSymbol = sym;
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isEditingThisCell
                                    ? const Color(0xFF0E7490)
                                        .withValues(alpha: 0.45)
                                    : (targets.isNotEmpty
                                        ? const Color(0xFF242C3F)
                                        : Colors.transparent),
                                borderRadius: BorderRadius.circular(4),
                                border: isEditingThisCell
                                    ? Border.all(
                                        color: const Color(0xFF00E5FF),
                                        width: 1.2)
                                    : null,
                              ),
                              child: Text(
                                displayText,
                                style: TextStyle(
                                  color: isEditingThisCell
                                      ? const Color(0xFF00E5FF)
                                      : (targets.isNotEmpty
                                          ? const Color(0xFF93C5FD)
                                          : const Color(0xFF475569)),
                                  fontSize: 11,
                                  fontWeight: isEditingThisCell ||
                                          targets.isNotEmpty
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

        // Inline Cell Editor Card (opens right beneath table when a cell is tapped)
        _buildInlineCellEditor(),
      ],
    );
  }

  void _submitNewSymbol() {
    final sym = _newSymbolController.text.trim();
    if (sym.isNotEmpty) {
      widget.controller.addAlphabetSymbol(sym);
      setState(() {
        _isAddingSymbol = false;
        _newSymbolController.clear();
      });
    }
  }

  Widget _buildInlineCellEditor() {
    if (_editingCellFromId == null || _editingCellSymbol == null) {
      return const SizedBox.shrink();
    }
    final automaton = widget.controller.automaton;
    final fromState = automaton.states[_editingCellFromId];
    if (fromState == null) return const SizedBox.shrink();

    final currentTargets =
        automaton.getTargets(_editingCellFromId!, _editingCellSymbol!);
    final allStates = automaton.states.values.toList();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF191E2B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xFF00E5FF), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'δ(${fromState.label}, "$_editingCellSymbol") → Targets',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              // Clear All Targets
              TextButton(
                onPressed: () {
                  widget.controller.setMatrixCell(
                      _editingCellFromId!, _editingCellSymbol!, {});
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFF87171),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear (∅)', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon:
                    const Icon(Icons.close, size: 15, color: Color(0xFF94A3B8)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                onPressed: () {
                  setState(() {
                    _editingCellFromId = null;
                    _editingCellSymbol = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap state chips to toggle destinations in real-time:',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: allStates.map((s) {
              final isTarget = currentTargets.contains(s.id);
              return InkWell(
                onTap: () {
                  final newTargets = Set<String>.from(currentTargets);
                  if (isTarget) {
                    newTargets.remove(s.id);
                  } else {
                    newTargets.add(s.id);
                  }
                  widget.controller.setMatrixCell(
                      _editingCellFromId!, _editingCellSymbol!, newTargets);
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isTarget
                        ? const Color(0xFF0E7490)
                        : const Color(0xFF13161F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isTarget
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF2A3246),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isTarget) ...[
                        const Icon(Icons.check,
                            size: 13, color: Color(0xFF00E5FF)),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        s.label,
                        style: TextStyle(
                          color: isTarget
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                          fontWeight: isTarget
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _symbolsController.dispose();
    _newSymbolController.dispose();
    super.dispose();
  }
}
