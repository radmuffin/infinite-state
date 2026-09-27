import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/studio_controller.dart';
import 'canvas/automata_canvas.dart';
import 'canvas/canvas_hud.dart';
import 'panels/inspector_panel.dart';
import 'panels/simulation_bar.dart';
import 'panels/toolbar.dart';

class StudioPage extends StatefulWidget {
  const StudioPage({super.key});

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  late final StudioController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = StudioController();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _controller.togglePlayPause();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _controller.stepForward();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _controller.stepBackward();
      } else if (event.logicalKey == LogicalKeyboardKey.delete ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        _controller.deleteSelected();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _controller.selectState(null);
        _controller.selectTransition(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF0C0E14),
        body: SafeArea(
          child: Column(
            children: [
              // Top Toolbar
              StudioToolbar(controller: _controller),

              // Main Workspace (Canvas + Inspector Panel)
              Expanded(
                child: Row(
                  children: [
                    // Visual Canvas with Floating HUD
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: AutomataCanvas(controller: _controller),
                          ),
                          CanvasHud(controller: _controller),
                        ],
                      ),
                    ),

                    // Inspector & Transition Matrix Sidebar
                    InspectorPanel(controller: _controller),
                  ],
                ),
              ),

              // Bottom Simulation Bar (Tape + Controls)
              SimulationBar(controller: _controller),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
}
