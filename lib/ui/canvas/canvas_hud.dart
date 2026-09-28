import 'dart:ui';
import 'package:flutter/material.dart';
import '../../state/studio_controller.dart';

class CanvasHud extends StatelessWidget {
  final StudioController controller;

  const CanvasHud({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      bottom: 20,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final zoomPercent = (controller.zoomScale * 100).round();

          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF161922).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2A3246), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Add State Quick Button
                    IconButton(
                      icon: const Icon(Icons.add_circle, size: 18),
                      tooltip: 'Add State (or Double-Click Canvas)',
                      color: const Color(0xFF818CF8),
                      onPressed: () {
                        final states = controller.automaton.states.values;
                        final pos = states.isEmpty
                            ? const Offset(400, 300)
                            : states.last.position + const Offset(120, 60);
                        controller.addStateAt(pos);
                      },
                    ),
                    const SizedBox(width: 2),

                    // Center Graph
                    IconButton(
                      icon: const Icon(Icons.center_focus_strong, size: 18),
                      tooltip: 'Center Graph on Screen',
                      color: const Color(0xFF94A3B8),
                      onPressed: controller.triggerCenterView,
                    ),

                    const SizedBox(
                      height: 20,
                      child: VerticalDivider(
                        color: Color(0xFF2A3246),
                        width: 12,
                      ),
                    ),

                    // Zoom Out Button
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16),
                      tooltip: 'Zoom Out (Ctrl + -)',
                      color: const Color(0xFF94A3B8),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: controller.triggerZoomOut,
                    ),

                    // Zoom Percentage Pill
                    InkWell(
                      onTap: controller.triggerResetZoom,
                      borderRadius: BorderRadius.circular(6),
                      child: Tooltip(
                        message: 'Reset Zoom to 100% (Ctrl+0)',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2333),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF333B4F), width: 1),
                          ),
                          child: Text(
                            '$zoomPercent%',
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Zoom In Button
                    IconButton(
                      icon: const Icon(Icons.add, size: 16),
                      tooltip: 'Zoom In (Ctrl + +)',
                      color: const Color(0xFF94A3B8),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: controller.triggerZoomIn,
                    ),

                    const SizedBox(
                      height: 20,
                      child: VerticalDivider(
                        color: Color(0xFF2A3246),
                        width: 12,
                      ),
                    ),

                    // Force-Directed Layout
                    IconButton(
                      icon: const Icon(Icons.hub_outlined, size: 18),
                      tooltip: 'Force-Directed Auto-Layout',
                      color: const Color(0xFF00E5FF),
                      onPressed: controller.applyForceDirectedLayout,
                    ),

                    // Hierarchical Sugiyama Layout
                    IconButton(
                      icon: const Icon(Icons.account_tree_outlined, size: 18),
                      tooltip: 'Hierarchical (Textbook Flow) Layout',
                      color: const Color(0xFFA5B4FC),
                      onPressed: controller.applySugiyamaLayout,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
