import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/models/automaton.dart';
import 'transition_curve.dart';

class CanvasPainter extends CustomPainter {
  final Automaton automaton;
  final String? selectedStateId;
  final String? selectedTransitionId;
  final String? transitionPendingStartId;
  final Offset? cursorPosition;
  final Set<String> activeStateIds;
  final Set<String> activeTransitionIds;
  final bool isSimulationStuck;

  CanvasPainter({
    required this.automaton,
    this.selectedStateId,
    this.selectedTransitionId,
    this.transitionPendingStartId,
    this.cursorPosition,
    required this.activeStateIds,
    required this.activeTransitionIds,
    this.isSimulationStuck = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawTransitions(canvas);
    _drawPendingWire(canvas);
    _drawStates(canvas);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFF2A2E3D)
      ..style = PaintingStyle.fill;

    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.0, dotPaint);
      }
    }
  }

  void _drawTransitions(Canvas canvas) {
    for (final t in automaton.transitions) {
      final fromNode = automaton.states[t.fromId];
      final toNode = automaton.states[t.toId];
      if (fromNode == null || toNode == null) continue;

      final isSelected = t.id == selectedTransitionId;
      final isActive = activeTransitionIds.contains(t.id);

      final Color baseColor;
      final double strokeWidth;
      if (isActive) {
        baseColor = const Color(0xFF00E5FF); // Vibrant Cyan
        strokeWidth = 3.5;
      } else if (isSelected) {
        baseColor = const Color(0xFFFFB74D); // Amber
        strokeWidth = 2.8;
      } else {
        baseColor = const Color(0xFF7E8B9B); // Soft slate
        strokeWidth = 2.0;
      }

      // Outer glow for active transition
      if (isActive) {
        final glowPaint = Paint()
          ..color = const Color(0x6600E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

        if (t.isSelfLoop) {
          final geom = TransitionGeometry.calculateSelfLoop(center: fromNode.position);
          canvas.drawPath(geom.path, glowPaint);
        } else {
          final hasReciprocal = automaton.transitionsBetween(t.toId, t.fromId).isNotEmpty;
          final geom = TransitionGeometry.calculateEdge(
            start: fromNode.position,
            end: toNode.position,
            hasReciprocal: hasReciprocal,
          );
          canvas.drawPath(geom.path, glowPaint);
        }
      }

      final linePaint = Paint()
        ..color = baseColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final arrowPaint = Paint()..color = baseColor;

      final Offset labelPos;

      if (t.isSelfLoop) {
        final geom = TransitionGeometry.calculateSelfLoop(center: fromNode.position);
        canvas.drawPath(geom.path, linePaint);
        TransitionGeometry.drawArrowHead(canvas, geom.arrowTip, geom.arrowDirection, arrowPaint);
        labelPos = geom.labelPosition;
      } else {
        final hasReciprocal = automaton.transitionsBetween(t.toId, t.fromId).isNotEmpty;
        final geom = TransitionGeometry.calculateEdge(
          start: fromNode.position,
          end: toNode.position,
          hasReciprocal: hasReciprocal,
        );
        canvas.drawPath(geom.path, linePaint);
        TransitionGeometry.drawArrowHead(canvas, geom.arrowTip, geom.arrowDirection, arrowPaint);
        labelPos = geom.labelPosition;
      }

      // Symbol pill badge
      _drawSymbolBadge(canvas, labelPos, t.symbols.join(', '), isSelected, isActive);
    }
  }

  void _drawSymbolBadge(
    Canvas canvas,
    Offset position,
    String symbolsText,
    bool isSelected,
    bool isActive,
  ) {
    final textSpan = TextSpan(
      text: symbolsText.isEmpty ? 'ε' : symbolsText,
      style: TextStyle(
        color: isActive
            ? const Color(0xFF00E5FF)
            : (isSelected ? const Color(0xFFFFB74D) : const Color(0xFFE2E8F0)),
        fontSize: 12.0,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeWidth = max(textPainter.width + 12.0, 22.0);
    final badgeHeight = max(textPainter.height + 6.0, 18.0);
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: position, width: badgeWidth, height: badgeHeight),
      const Radius.circular(9.0),
    );

    // Pill background
    final bgPaint = Paint()
      ..color = const Color(0xFF1E222D)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(badgeRect, bgPaint);

    // Pill border
    final borderPaint = Paint()
      ..color = isActive
          ? const Color(0xFF00E5FF)
          : (isSelected ? const Color(0xFFFFB74D) : const Color(0xFF4A5568))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(badgeRect, borderPaint);

    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy - textPainter.height / 2),
    );
  }

  void _drawPendingWire(Canvas canvas) {
    if (transitionPendingStartId == null || cursorPosition == null) return;
    final startNode = automaton.states[transitionPendingStartId];
    if (startNode == null) return;

    final wirePaint = Paint()
      ..color = const Color(0xFF6366F1).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(startNode.position, cursorPosition!, wirePaint);
  }

  void _drawStates(Canvas canvas) {
    for (final node in automaton.states.values) {
      final isSelected = node.id == selectedStateId;
      final isActive = activeStateIds.contains(node.id);
      final isPendingStart = node.id == transitionPendingStartId;

      // 1. Initial State Indicator Arrow
      if (node.isInitial) {
        _drawInitialArrow(canvas, node.position);
      }

      // 2. Active / Selected / Error Aura Glow
      if (isActive) {
        final glowColor = isSimulationStuck
            ? const Color(0xFFFF5252) // Error Red
            : const Color(0xFF00E676); // Emerald Green
        final glowPaint = Paint()
          ..color = glowColor.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
        canvas.drawCircle(node.position, TransitionGeometry.nodeRadius + 8.0, glowPaint);
      }

      // 3. Main State Circle Fill
      final fillPaint = Paint()
        ..color = isSelected
            ? const Color(0xFF2C3246)
            : (isActive ? const Color(0xFF1B332B) : const Color(0xFF1E222D))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node.position, TransitionGeometry.nodeRadius, fillPaint);

      // 4. Main State Circle Border
      final Color borderColor;
      final double borderWidth;
      if (isActive) {
        borderColor = isSimulationStuck ? const Color(0xFFFF5252) : const Color(0xFF00E676);
        borderWidth = 3.0;
      } else if (isSelected || isPendingStart) {
        borderColor = const Color(0xFFFFB74D);
        borderWidth = 2.8;
      } else {
        borderColor = const Color(0xFF64748B);
        borderWidth = 2.0;
      }

      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawCircle(node.position, TransitionGeometry.nodeRadius, borderPaint);

      // 5. Accepting State Inner Ring (Formal Automata standard)
      if (node.isAccept) {
        final innerBorderPaint = Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        canvas.drawCircle(node.position, TransitionGeometry.nodeRadius - 6.0, innerBorderPaint);
      }

      // 6. Label Text
      final textSpan = TextSpan(
        text: node.label,
        style: TextStyle(
          color: isActive ? Colors.white : const Color(0xFFF1F5F9),
          fontSize: 13.0,
          fontWeight: FontWeight.w600,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: TransitionGeometry.nodeRadius * 1.8);

      textPainter.paint(
        canvas,
        Offset(
          node.position.dx - textPainter.width / 2,
          node.position.dy - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawInitialArrow(Canvas canvas, Offset center) {
    const arrowLen = 38.0;
    final tip = center - const Offset(TransitionGeometry.nodeRadius, 0);
    final start = tip - const Offset(arrowLen, 0);

    final linePaint = Paint()
      ..color = const Color(0xFF60A5FA)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, tip, linePaint);
    TransitionGeometry.drawArrowHead(
      canvas,
      tip,
      0, // Pointing rightwards (0 radians)
      Paint()..color = const Color(0xFF60A5FA),
    );
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) => true;
}
