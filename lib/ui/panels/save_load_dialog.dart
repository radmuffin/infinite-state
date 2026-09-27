import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/automaton.dart';
import '../../core/presets/example_automata.dart';
import '../../core/storage/machine_storage.dart';
import '../../state/studio_controller.dart';

class SaveLoadDialog extends StatefulWidget {
  final StudioController controller;

  const SaveLoadDialog({super.key, required this.controller});

  @override
  State<SaveLoadDialog> createState() => _SaveLoadDialogState();
}

class _SaveLoadDialogState extends State<SaveLoadDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _nameController;
  final TextEditingController _jsonController = TextEditingController();

  List<SavedMachine> _savedMachines = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _nameController =
        TextEditingController(text: widget.controller.machineName);
    _loadMachines();
    _jsonController.text =
        const JsonEncoder.withIndent('  ').convert(widget.controller.automaton.toJson());
  }

  void _loadMachines() {
    setState(() {
      _savedMachines = widget.controller.listSavedMachines();
    });
  }

  void _saveCurrent() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      widget.controller.saveCurrentMachine(name);
      _loadMachines();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "$name" successfully!'),
          backgroundColor: const Color(0xFF065F46),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF13161F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF282D3D), width: 1.5),
      ),
      child: Container(
        width: 600,
        height: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Title Header
            Row(
              children: [
                const Icon(Icons.folder_special,
                    color: Color(0xFF818CF8), size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Machine Library & Persistence',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: const Color(0xFF94A3B8),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF00E5FF),
              unselectedLabelColor: const Color(0xFF94A3B8),
              indicatorColor: const Color(0xFF00E5FF),
              tabs: const [
                Tab(text: 'My Saved Machines'),
                Tab(text: 'Textbook Presets'),
                Tab(text: 'Import / Export JSON'),
              ],
            ),
            const SizedBox(height: 14),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSavedMachinesTab(),
                  _buildPresetsTab(),
                  _buildJsonTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedMachinesTab() {
    return Column(
      children: [
        // Save As input row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Machine name...',
                  hintStyle:
                      const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFF1E222D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _saveCurrent,
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save Current', style: TextStyle(fontSize: 12)),
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
        const SizedBox(height: 12),

        // List of saved machines
        Expanded(
          child: _savedMachines.isEmpty
              ? Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161922),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'No saved machines yet.\nEnter a name above and click "Save Current".',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                )
              : ListView.separated(
                  itemCount: _savedMachines.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: Color(0xFF282D3D), height: 1),
                  itemBuilder: (context, index) {
                    final item = _savedMachines[index];
                    final stateCount = item.automaton.states.length;
                    final transCount = item.automaton.transitions.length;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      color: const Color(0xFF161922),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$stateCount states • $transCount transitions • ${item.updatedAt.toLocal().toString().split('.').first}',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              widget.controller.loadSavedMachine(item);
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF00E5FF),
                              side: const BorderSide(color: Color(0xFF0E7490)),
                            ),
                            child: const Text('Load',
                                style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: const Color(0xFFF87171),
                            tooltip: 'Delete Machine',
                            onPressed: () {
                              widget.controller.deleteSavedMachine(item.id);
                              _loadMachines();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPresetsTab() {
    final presets = ExampleAutomata.all;
    return ListView.separated(
      itemCount: presets.length,
      separatorBuilder: (_, _) =>
          const Divider(color: Color(0xFF282D3D), height: 1),
      itemBuilder: (context, index) {
        final p = presets[index];
        final isDfa = p.automaton.isDfa;
        final hasEps = p.automaton.hasEpsilonTransitions;

        return Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF161922),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          p.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDfa
                                ? const Color(0xFF064E3B)
                                : const Color(0xFF312E81),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isDfa ? 'DFA' : (hasEps ? 'ε-NFA' : 'NFA'),
                            style: TextStyle(
                              color: isDfa
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFFA5B4FC),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.description,
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  widget.controller.loadPreset(p);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF312E81),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Load Preset',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJsonTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Export or import JSON automata definitions directly:',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            controller: _jsonController,
            maxLines: null,
            expands: true,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1E222D),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _jsonController.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied JSON to clipboard!'),
                    backgroundColor: Color(0xFF065F46),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy JSON', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00E5FF),
                side: const BorderSide(color: Color(0xFF0E7490)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                try {
                  final data = jsonDecode(_jsonController.text);
                  final imported =
                      Automaton.fromJson(data as Map<String, dynamic>);
                  widget.controller.loadSavedMachine(
                    SavedMachine(
                      id: 'imported_${DateTime.now().millisecondsSinceEpoch}',
                      name: 'Imported Machine',
                      updatedAt: DateTime.now(),
                      automaton: imported,
                    ),
                  );
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Invalid JSON format: $e'),
                      backgroundColor: const Color(0xFF7F1D1D),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.file_upload, size: 16),
              label: const Text('Import JSON', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _jsonController.dispose();
    super.dispose();
  }
}
