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
  String? _lastSelectedStateId;
  String? _lastSelectedTransitionId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final selectedState = widget.controller.selectedState;
        final selectedTransition = widget.controller.selectedTransition;

        // Sync controllers when selection changes
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
          width: 320,
          decoration: const BoxDecoration(
            color: Color(0xFF161922),
            border: Border(
              left: BorderSide(color: Color(0xFF282D3D), width: 1.5),
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
                    bottom: BorderSide(color: Color(0xFF282D3D), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tune, size: 16, color: Color(0xFF818CF8)),
                    const SizedBox(width: 8),
                    const Text(
                      'INSPECTOR & MATRIX',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
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
                      const SizedBox(height: 20),
                    ] else if (selectedTransition != null) ...[
                      _buildTransitionInspector(selectedTransition),
                      const SizedBox(height: 20),
                    ] else ...[
                      const Text(
                        'Select a state or transition to inspect and edit properties.',
                        style:
                            TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                    ],

                    const Divider(color: Color(0xFF282D3D)),
                    const SizedBox(height: 12),

                    // Transition Matrix Table
                    _buildTransitionMatrix(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.radio_button_checked,
                size: 16, color: Color(0xFF00E5FF)),
            const SizedBox(width: 6),
            Text(
              'State: ${selectedState.label}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Label Input
        const Text('Label',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: _labelController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF1E222D),
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
        const SizedBox(height: 12),

        // Toggles
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

        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.controller.deleteSelected,
            icon: const Icon(Icons.delete_outline,
                size: 16, color: Color(0xFFF87171)),
            label: const Text('Delete State',
                style: TextStyle(color: Color(0xFFF87171), fontSize: 12)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF7F1D1D)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransitionInspector(Transition selectedTransition) {
    final fromState =
        widget.controller.automaton.states[selectedTransition.fromId];
    final toState = widget.controller.automaton.states[selectedTransition.toId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.arrow_right_alt,
                size: 18, color: Color(0xFFFFB74D)),
            const SizedBox(width: 6),
            Text(
              '${fromState?.label ?? selectedTransition.fromId} → ${toState?.label ?? selectedTransition.toId}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Symbols (comma-separated, use ε for epsilon)',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _symbolsController,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF1E222D),
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
              symbols.isEmpty ? {'ε'} : symbols,
            );
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.controller.deleteSelected,
            icon: const Icon(Icons.delete_outline,
                size: 16, color: Color(0xFFF87171)),
            label: const Text('Delete Transition',
                style: TextStyle(color: Color(0xFFF87171), fontSize: 12)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF7F1D1D)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransitionMatrix() {
    final automaton = widget.controller.automaton;
    final alphabetList = automaton.alphabet.toList()..sort();
    if (automaton.hasEpsilonTransitions) {
      alphabetList.add(Transition.epsilon);
    }

    final statesList = automaton.states.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.grid_on, size: 15, color: Color(0xFF38BDF8)),
            const SizedBox(width: 6),
            const Flexible(
              child: Text(
                'Transition Function (δ)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (statesList.isEmpty)
          const Text('No states added yet.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 32,
              dataRowMinHeight: 28,
              dataRowMaxHeight: 32,
              columnSpacing: 16,
              headingRowColor:
                  WidgetStateProperty.all(const Color(0xFF1E222D)),
              columns: [
                const DataColumn(
                  label: Text('State',
                      style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                ...alphabetList.map(
                  (sym) => DataColumn(
                    label: Text(
                      sym,
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
              rows: statesList.map((state) {
                final prefix = state.isInitial ? '→ ' : '';
                final suffix = state.isAccept ? ' *' : '';
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        '$prefix${state.label}$suffix',
                        style: TextStyle(
                          color: state.isAccept
                              ? const Color(0xFF4ADE80)
                              : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...alphabetList.map((sym) {
                      final targets = automaton
                          .transitionsFrom(state.id)
                          .where((t) => t.symbols.contains(sym))
                          .map((t) =>
                              automaton.states[t.toId]?.label ?? t.toId)
                          .toList();

                      final text = targets.isEmpty
                          ? '—'
                          : (targets.length == 1
                              ? targets.first
                              : '{${targets.join(", ")}}');

                      return DataCell(
                        Text(
                          text,
                          style: TextStyle(
                            color: targets.isEmpty
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _symbolsController.dispose();
    super.dispose();
  }
}
