import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/studio_controller.dart';
import 'canvas/automata_canvas.dart';
import 'canvas/canvas_hud.dart';
import 'panels/right_sidebar.dart';
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

  bool _isPrintableSymbol(String char) {
    if (char.isEmpty) return false;
    if (char == 'ε') return true;
    final code = char.codeUnitAt(0);
    return char.length == 1 && code >= 33 && code <= 126;
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Don't intercept keystrokes if the user is typing in a text field
      final primaryFocus = FocusManager.instance.primaryFocus;
      if (primaryFocus != null && primaryFocus.context?.widget is EditableText) {
        return;
      }

      final isCtrlOrMeta = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;

      if (isCtrlOrMeta) {
        final isShift = HardwareKeyboard.instance.isShiftPressed;
        if (event.logicalKey == LogicalKeyboardKey.keyZ) {
          if (isShift) {
            _controller.redo();
          } else {
            _controller.undo();
          }
          return;
        } else if (event.logicalKey == LogicalKeyboardKey.keyY) {
          _controller.redo();
          return;
        } else if (event.logicalKey == LogicalKeyboardKey.digit0 ||
            event.logicalKey == LogicalKeyboardKey.numpad0) {
          _controller.triggerResetZoom();
          return;
        } else if (event.logicalKey == LogicalKeyboardKey.equal ||
            event.logicalKey == LogicalKeyboardKey.add) {
          _controller.triggerZoomIn();
          return;
        } else if (event.logicalKey == LogicalKeyboardKey.minus ||
            event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
          _controller.triggerZoomOut();
          return;
        }
        return;
      }

      if (HardwareKeyboard.instance.isAltPressed) {
        return;
      }

      if (event.logicalKey == LogicalKeyboardKey.space) {
        if (_controller.hasActiveOrSelectedTransition &&
            (_controller.isAwaitingCommaAppend || _controller.transitionTypingActive)) {
          // Allow typing "a, b" smoothly without space toggling playback
          return;
        }
        _controller.togglePlayPause();
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (_controller.transitionTypingActive) {
          _controller.finishTransitionTyping();
          return;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _controller.stepForward();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _controller.stepBackward();
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_controller.transitionTypingActive) {
          if (_controller.canBackspaceTransitionSymbol) {
            _controller.backspaceTransitionSymbol();
            return;
          } else {
            _controller.finishTransitionTyping();
            return;
          }
        }
        _controller.deleteSelected();
      } else if (event.logicalKey == LogicalKeyboardKey.delete) {
        _controller.deleteSelected();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _controller.selectState(null);
        _controller.selectTransition(null);
        _controller.finishTransitionTyping();
      } else if (event.character != null && event.character!.isNotEmpty) {
        final char = event.character!;
        if (_controller.hasActiveOrSelectedTransition && _isPrintableSymbol(char)) {
          _controller.typeTransitionSymbol(char);
        }
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

                    // Consolidated Toggle-able Right Sidebar
                    RightSidebar(controller: _controller),
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
