import 'package:flutter/material.dart';
import '../../state/studio_controller.dart';
import 'batch_test_dialog.dart';
import 'save_load_dialog.dart';

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
          decoration: const BoxDecoration(
            color: Color(0xFF11141D),
            border: Border(
              bottom: BorderSide(color: Color(0xFF222738), width: 1.5),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Logo
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF00E5FF)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
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

                const SizedBox(width: 14),

                // Editable Machine Title Pill
                _buildMachineTitlePill(context),

                const SizedBox(width: 10),

                // Classification Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDfa
                        ? const Color(0xFF064E3B)
                        : const Color(0xFF312E81),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDfa
                          ? const Color(0xFF10B981)
                          : const Color(0xFF818CF8),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isDfa ? 'DFA' : (hasEpsilon ? 'ε-NFA' : 'NFA'),
                    style: TextStyle(
                      color: isDfa
                          ? const Color(0xFF6EE7B7)
                          : const Color(0xFFA5B4FC),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // Save & Library Button
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => SaveLoadDialog(controller: controller),
                    );
                  },
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Library & Save',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2433),
                    foregroundColor: const Color(0xFF93C5FD),
                    side: const BorderSide(color: Color(0xFF313B54)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                ),

                const SizedBox(width: 10),

                // Auto-Layout Dropdown
                PopupMenuButton<String>(
                  tooltip: 'Auto-Layout Algorithms',
                  color: const Color(0xFF1E222D),
                  icon: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 16, color: Color(0xFFA5B4FC)),
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
                                'Physical repulsion & spring tension',
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

                const SizedBox(width: 16),

                // Batch Test Runner
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) =>
                          BatchTestDialog(controller: controller),
                    );
                  },
                  icon: const Icon(Icons.playlist_add_check, size: 17),
                  label: const Text('Batch Tests',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00E5FF),
                    side: const BorderSide(color: Color(0xFF0E7490)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                  ),
                ),

                const SizedBox(width: 10),

                // Center View Button
                IconButton(
                  icon: const Icon(Icons.center_focus_strong, size: 19),
                  tooltip: 'Center Graph on Screen',
                  color: const Color(0xFF94A3B8),
                  onPressed: controller.triggerCenterView,
                ),

                // Undo Button
                IconButton(
                  icon: const Icon(Icons.undo, size: 19),
                  tooltip: 'Undo',
                  color: const Color(0xFF94A3B8),
                  onPressed: controller.undo,
                ),

                // Clear All Button with Confirmation
                IconButton(
                  icon: const Icon(Icons.delete_sweep, size: 20),
                  tooltip: 'Clear All States',
                  color: const Color(0xFFF87171),
                  onPressed: () => _confirmClearAll(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMachineTitlePill(BuildContext context) {
    return InkWell(
      onTap: () => _showRenameDialog(context),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2333),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2E374D)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.machineName,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit, size: 12, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final textController = TextEditingController(text: controller.machineName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF2A3246)),
        ),
        title: const Text('Rename Machine',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF1E222D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
          ),
          onSubmitted: (val) {
            controller.setMachineName(val);
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              controller.setMachineName(textController.text);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF2A3246)),
        ),
        title: const Text('Clear All States?',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: const Text(
          'This will remove all states and transitions from the canvas. You can always use Undo to restore.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              controller.clearAutomaton();
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
