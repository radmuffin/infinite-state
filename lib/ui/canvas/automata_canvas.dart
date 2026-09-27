import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _hoveredNodeId;
  bool _isHoveringHandle = false;
  bool _isDraggingWire = false;
  String? _connectingSourceId;

  int _lastCenterViewTrigger = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerViewOnGraph();
    });
  }

  void _centerViewOnGraph() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final viewSize = renderBox.size;
    final states = widget.controller.automaton.states.values;

    if (states.isEmpty) {
      final dx = -(1500.0 - viewSize.width / 2);
      final dy = -(1000.0 - viewSize.height / 2);
      _transformController.value = Matrix4.translationValues(dx, dy, 0.0);
      return;
    }

    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;

    for (final s in states) {
      if (s.position.dx < minX) minX = s.position.dx;
      if (s.position.dy < minY) minY = s.position.dy;
      if (s.position.dx > maxX) maxX = s.position.dx;
      if (s.position.dy > maxY) maxY = s.position.dy;
    }

    final centerOfGraph = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    final dx = -(centerOfGraph.dx - viewSize.width / 2);
    final dy = -(centerOfGraph.dy - viewSize.height / 2);

    _transformController.value = Matrix4.translationValues(dx, dy, 0.0);
  }

  Offset _toScene(Offset localPos) =>
      _transformController.toScene(localPos);

  StateNode? _hitTestNode(Offset scenePos, {double extraRadius = 6.0}) {
    for (final node in widget.controller.automaton.states.values) {
      if ((node.position - scenePos).distance <=
          TransitionGeometry.nodeRadius + extraRadius) {
        return node;
      }
    }
    return null;
  }

  bool _hitTestConnectionHandle(StateNode node, Offset scenePos) {
    final handlePos =
        node.position + const Offset(TransitionGeometry.nodeRadius + 14.0, 0);
    return (handlePos - scenePos).distance <= 22.0;
  }

  void _onPointerDown(PointerDownEvent event) {
    final scenePos = _toScene(event.localPosition);

    // 1. If currently in click-to-connect mode:
    if (_connectingSourceId != null) {
      final targetNode = _hitTestNode(scenePos, extraRadius: 10.0);
      if (targetNode != null) {
        widget.controller.connectStates(_connectingSourceId!, targetNode.id);
      }
      setState(() {
        _connectingSourceId = null;
        _isDraggingWire = false;
      });
      return;
    }

    // 2. Check if clicking connection handle of selected state FIRST
    final selected = widget.controller.selectedState;
    if (selected != null && _hitTestConnectionHandle(selected, scenePos)) {
      _isDraggingWire = true;
      _draggedNodeId = null;
      widget.controller.startWireDrag(selected.id, scenePos);
      setState(() {});
      return;
    }

    // 3. Check if clicking a state node
    final clickedNode = _hitTestNode(scenePos);
    if (clickedNode != null) {
      // Shift-click/drag immediately starts connection wire
      if (HardwareKeyboard.instance.isShiftPressed) {
        _isDraggingWire = true;
        _draggedNodeId = null;
        widget.controller.startWireDrag(clickedNode.id, scenePos);
        setState(() {});
        return;
      }

      widget.controller.selectState(clickedNode.id);
      _draggedNodeId = clickedNode.id;
    } else {
      // 4. Clicked canvas background -> deselect
      widget.controller.selectState(null);
      widget.controller.selectTransition(null);
    }
    setState(() {});
  }

  void _updateHover(Offset scenePos) {
    final hoveredNode = _hitTestNode(scenePos);
    final selected = widget.controller.selectedState;
    final hoveredHandle =
        selected != null && _hitTestConnectionHandle(selected, scenePos);

    if (_hoveredNodeId != hoveredNode?.id ||
        _isHoveringHandle != hoveredHandle) {
      setState(() {
        _hoveredNodeId = hoveredNode?.id;
        _isHoveringHandle = hoveredHandle;
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final scenePos = _toScene(event.localPosition);
    _updateHover(scenePos);

    if (_isDraggingWire) {
      widget.controller.updateWireDrag(scenePos);
    } else if (_draggedNodeId != null) {
      widget.controller.updateStatePosition(_draggedNodeId!, scenePos);
    }
  }

  void _onPointerHover(PointerHoverEvent event) {
    final scenePos = _toScene(event.localPosition);
    _updateHover(scenePos);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isDraggingWire) {
      final scenePos = _toScene(event.localPosition);
      final targetNode = _hitTestNode(scenePos, extraRadius: 10.0);
      widget.controller.endWireDrag(targetNode?.id);
      _isDraggingWire = false;
    }
    _draggedNodeId = null;
    setState(() {});
  }

  void _onDoubleTapDown(TapDownDetails details) {
    final scenePos = _toScene(details.localPosition);
    final clickedNode = _hitTestNode(scenePos);
    if (clickedNode == null) {
      // Direct state creation on double click
      widget.controller.addStateAt(scenePos);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (widget.controller.centerViewTrigger != _lastCenterViewTrigger) {
          _lastCenterViewTrigger = widget.controller.centerViewTrigger;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _centerViewOnGraph();
          });
        }

        final isStuck =
            widget.controller.simulator?.currentStep.isStuck ?? false;
        final selectedState = widget.controller.selectedState;

        final isConnecting = _connectingSourceId != null;

        return ClipRect(
          child: MouseRegion(
            cursor: _isDraggingWire || _isHoveringHandle
                ? SystemMouseCursors.precise
                : (isConnecting
                    ? SystemMouseCursors.click
                    : (_hoveredNodeId != null
                        ? SystemMouseCursors.grab
                        : SystemMouseCursors.basic)),
            onHover: _onPointerHover,
            child: Stack(
              children: [
                // 1. Canvas Layer with Pan/Zoom & Node drag listener
                GestureDetector(
                  onDoubleTapDown: _onDoubleTapDown,
                  child: Listener(
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      minScale: 0.2,
                      maxScale: 2.5,
                      panEnabled: _draggedNodeId == null &&
                          !_isDraggingWire &&
                          !isConnecting &&
                          _hoveredNodeId == null &&
                          !_isHoveringHandle,
                      child: SizedBox(
                        width: _canvasVirtualSize.width,
                        height: _canvasVirtualSize.height,
                        child: CustomPaint(
                          painter: CanvasPainter(
                            automaton: widget.controller.automaton,
                            selectedStateId: widget.controller.selectedStateId,
                            selectedTransitionId:
                                widget.controller.selectedTransitionId,
                            wireSourceStateId:
                                widget.controller.wireSourceStateId,
                            wireCurrentPosition:
                                widget.controller.wireCurrentPosition,
                            hoveredStateId: _hoveredNodeId,
                            isHoveringHandle: _isHoveringHandle,
                            activeStateIds: widget.controller.activeStateIds,
                            activeTransitionIds:
                                widget.controller.activeTransitionIds,
                            isSimulationStuck: isStuck,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Floating Quick-Action Pill for selected state (on top of canvas)
                if (selectedState != null && !_isDraggingWire && !isConnecting)
                  _buildSelectedStateQuickActions(selectedState),

                    // Connect Mode Banner
                    if (isConnecting)
                      Positioned(
                        top: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2333),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: const Color(0xFF00E5FF), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF)
                                      .withValues(alpha: 0.25),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cable,
                                    size: 16, color: Color(0xFF00E5FF)),
                                const SizedBox(width: 8),
                                Text(
                                  'Connecting from ${widget.controller.automaton.states[_connectingSourceId]?.label ?? _connectingSourceId} → Click target state (or click self for loop)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _connectingSourceId = null;
                                      widget.controller.endWireDrag(null);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF334155),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                          color: Color(0xFFCBD5E1),
                                          fontSize: 11),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      }

  Widget _buildSelectedStateQuickActions(StateNode node) {
    // Convert scene coordinates to local widget coordinates
    final scenePos = node.position + const Offset(0, -TransitionGeometry.nodeRadius - 32.0);
    final matrix = _transformController.value;
    final screenPos = MatrixUtils.transformPoint(matrix, scenePos);

    return Positioned(
      left: screenPos.dx - 120,
      top: screenPos.dy,
      child: Material(
        color: const Color(0xFF1E2333),
        borderRadius: BorderRadius.circular(20),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3B445B), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Connect Button
            InkWell(
              onTap: () {
                setState(() {
                  _connectingSourceId = node.id;
                  widget.controller.startWireDrag(node.id, node.position);
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _connectingSourceId == node.id
                      ? const Color(0xFF0E7490)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cable,
                      size: 13,
                      color: Color(0xFF00E5FF),
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Connect',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Toggle Start
            InkWell(
              onTap: () => widget.controller.quickToggleInitial(node.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: node.isInitial
                      ? const Color(0xFF1E3A8A)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      size: 13,
                      color: node.isInitial
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Start',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: node.isInitial
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Toggle Accept
            InkWell(
              onTap: () => widget.controller.quickToggleAccept(node.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: node.isAccept
                      ? const Color(0xFF064E3B)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trip_origin,
                      size: 13,
                      color: node.isAccept
                          ? const Color(0xFF34D399)
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: node.isAccept
                            ? const Color(0xFF6EE7B7)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Delete
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 14),
              color: const Color(0xFFF87171),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Delete State',
              onPressed: () => widget.controller.deleteState(node.id),
            ),
          ],
        ),
      ),
    ),
  );
}

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }
}
