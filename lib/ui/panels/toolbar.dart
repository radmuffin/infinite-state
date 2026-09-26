import 'package:flutter/material.dart';
import '../../core/presets/example_automata.dart';
import '../../state/studio_controller.dart';
import 'batch_test_dialog.dart';

class StudioToolbar extends StatelessWidget {
  final StudioController controller;

  const StudioToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isDfa = controller.automaton.isDfa;
        final hasEpsilon = controller.automaton.hasEpsilonTransitions;

        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          decoration: BoxDecoration(
            color: const Color(0xFF161922),
            border: const Border(
              bottom: BorderSide(color: Color(0xFF282D3D), width: 1.5),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
            children: [
              // Logo / Title
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF00E5FF)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '∞',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Infinite State',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 12),

              // Classification Badge (DFA vs NFA vs ε-NFA)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDfa
                      ? const Color(0xFF064E3B)
                      : const Color(0xFF312E81),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDfa
                        ? const Color(0xFF10B981)
                        : const Color(0xFF818CF8),
                    width: 1,
                  ),
                ),
                child: Text(
                  isDfa
                      ? 'DFA'
                      : (hasEpsilon ? 'ε-NFA' : 'NFA'),
                  style: TextStyle(
                    color: isDfa
                        ? const Color(0xFF6EE7B7)
                        : const Color(0xFFA5B4FC),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 20),
              const VerticalDivider(
                  color: Color(0xFF282D3D), indent: 10, endIndent: 10),
              const SizedBox(width: 12),

              // Tool Mode Segmented Buttons
              _buildToolButton(
                icon: Icons.near_me_outlined,
                label: 'Select',
                tool: CanvasTool.select,
              ),
              const SizedBox(width: 4),
              _buildToolButton(
                icon: Icons.add_circle_outline,
                label: 'State',
                tool: CanvasTool.addState,
              ),
              const SizedBox(width: 4),
              _buildToolButton(
                icon: Icons.trending_flat,
                label: 'Transition',
                tool: CanvasTool.addTransition,
              ),
              const SizedBox(width: 4),
              _buildToolButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                tool: CanvasTool.delete,
              ),

              const SizedBox(width: 16),
              const VerticalDivider(
                  color: Color(0xFF282D3D), indent: 10, endIndent: 10),
              const SizedBox(width: 12),

              // Auto-Layout Popup Menu
              PopupMenuButton<String>(
                tooltip: 'Auto-Layout Algorithms',
                color: const Color(0xFF1E222D),
                icon: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 17, color: Color(0xFFA5B4FC)),
                    SizedBox(width: 5),
                    Text(
                      'Auto-Layout',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down,
                        size: 16, color: Color(0xFF94A3B8)),
                  ],
                ),
                onSelected: (val) {
                  if (val == 'force') {
                    controller.applyForceDirectedLayout();
                  } else if (val == 'sugiyama') {
                    controller.applySugiyamaLayout();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'force',
                    child: Row(
                      children: [
                        Icon(Icons.hub, size: 18, color: Color(0xFF00E5FF)),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Force-Directed (Spring)',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Simulated annealing physical repulsion',
                              style: TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sugiyama',
                    child: Row(
                      children: [
                        Icon(Icons.account_tree,
                            size: 18, color: Color(0xFF818CF8)),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hierarchical (Textbook Flow)',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Left-to-right topological layering',
                              style: TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 12),

              // Presets Dropdown
              PopupMenuButton<AutomataPreset>(
                tooltip: 'Load Presets',
                color: const Color(0xFF1E222D),
                icon: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book, size: 17, color: Color(0xFF38BDF8)),
                    SizedBox(width: 5),
                    Text(
                      'Examples',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down,
                        size: 16, color: Color(0xFF94A3B8)),
                  ],
                ),
                onSelected: (preset) => controller.loadPreset(preset),
                itemBuilder: (context) => ExampleAutomata.all.map((preset) {
                  return PopupMenuItem(
                    value: preset,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          preset.description,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(width: 24),

              // Batch Test Runner Button
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => BatchTestDialog(controller: controller),
                  );
                },
                icon: const Icon(Icons.playlist_add_check, size: 17),
                label: const Text('Batch Test Runner',
                    style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00E5FF),
                  side: const BorderSide(color: Color(0xFF0E7490)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),

              const SizedBox(width: 8),

              // Undo Button
              IconButton(
                icon: const Icon(Icons.undo, size: 19),
                tooltip: 'Undo',
                color: const Color(0xFF94A3B8),
                onPressed: controller.undo,
              ),

              // Clear Canvas
              IconButton(
                icon: const Icon(Icons.clear, size: 19),
                tooltip: 'Clear Canvas',
                color: const Color(0xFF94A3B8),
                onPressed: controller.clearAutomaton,
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required CanvasTool tool,
  }) {
    final isSelected = controller.currentTool == tool;

    return Material(
      color: isSelected ? const Color(0xFF3730A3) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => controller.setTool(tool),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
