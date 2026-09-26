import 'package:flutter/material.dart';
import '../../core/models/state_node.dart';
import '../../state/studio_controller.dart';
import 'canvas_painter.dart';
import 'transition_curve.dart';

class AutomataCanvas extends StatefulWidget {
  final StudioController controller;

  const AutomataCanvas({super.key, required this.controller});

  @override
  State<AutomataCanvas> createState() => _AutomataCanvasState();
}

class _AutomataCanvasState extends State<AutomataCanvas> {
  final TransformationController _transformController =
      TransformationController();
  final Size _canvasVirtualSize = const Size(3000, 2000);

  String? _draggedNodeId;
  Offset? _cursorCanvasPos;

  @override
  void initState() {
    super.initState();
    // Center the viewport initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final viewSize = renderBox.size;
        final dx = -(1500.0 - viewSize.width / 2);
        final dy = -(1000.0 - viewSize.height / 2);
        _transformController.value = Matrix4.translationValues(dx, dy, 0.0);
      }
    });
  }

  Offset _toScene(Offset localPos) =>
      _transformController.toScene(localPos);

  StateNode? _hitTestNode(Offset scenePos) {
    for (final node in widget.controller.automaton.states.values) {
      if ((node.position - scenePos).distance <= TransitionGeometry.nodeRadius + 4.0) {
        return node;
      }
    }
    return null;
  }

  void _onPointerDown(PointerDownEvent event) {
    final scenePos = _toScene(event.localPosition);
    final clickedNode = _hitTestNode(scenePos);

    switch (widget.controller.currentTool) {
      case CanvasTool.select:
        if (clickedNode != null) {
          widget.controller.selectState(clickedNode.id);
          _draggedNodeId = clickedNode.id;
        } else {
          widget.controller.selectState(null);
        }
        break;

      case CanvasTool.addState:
        if (clickedNode == null) {
          widget.controller.addStateAt(scenePos);
        }
        break;

      case CanvasTool.addTransition:
        if (clickedNode != null) {
          widget.controller.handleTransitionConnect(clickedNode.id);
        } else {
          widget.controller.cancelPendingTransition();
        }
        break;

      case CanvasTool.delete:
        if (clickedNode != null) {
          widget.controller.selectState(clickedNode.id);
          widget.controller.deleteSelected();
        }
        break;
    }
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    final scenePos = _toScene(event.localPosition);
    _cursorCanvasPos = scenePos;

    if (_draggedNodeId != null &&
        widget.controller.currentTool == CanvasTool.select) {
      widget.controller.updateStatePosition(_draggedNodeId!, scenePos);
    } else {
      if (widget.controller.transitionPendingStartId != null) {
        setState(() {});
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _draggedNodeId = null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isStuck =
            widget.controller.simulator?.currentStep.isStuck ?? false;

        return ClipRect(
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            child: InteractiveViewer(
              transformationController: _transformController,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.25,
              maxScale: 2.5,
              panEnabled: _draggedNodeId == null &&
                  widget.controller.currentTool == CanvasTool.select,
              child: SizedBox(
                width: _canvasVirtualSize.width,
                height: _canvasVirtualSize.height,
                child: CustomPaint(
                  painter: CanvasPainter(
                    automaton: widget.controller.automaton,
                    selectedStateId: widget.controller.selectedStateId,
                    selectedTransitionId:
                        widget.controller.selectedTransitionId,
                    transitionPendingStartId:
                        widget.controller.transitionPendingStartId,
                    cursorPosition: _cursorCanvasPos,
                    activeStateIds: widget.controller.activeStateIds,
                    activeTransitionIds:
                        widget.controller.activeTransitionIds,
                    isSimulationStuck: isStuck,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }
}
