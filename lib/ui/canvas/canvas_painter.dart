import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/models/automaton.dart';
import 'transition_curve.dart';

class CanvasPainter extends CustomPainter {
  final Automaton automaton;
  final String? selectedStateId;
  final String? selectedTransitionId;
  final String? wireSourceStateId;
  final Offset? wireCurrentPosition;
  final String? hoveredStateId;
  final Set<String> activeStateIds;
  final Set<String> activeTransitionIds;
  final bool isSimulationStuck;

  CanvasPainter({
    required this.automaton,
    this.selectedStateId,
    this.selectedTransitionId,
    this.wireSourceStateId,
    this.wireCurrentPosition,
    this.hoveredStateId,
    this.isHoveringHandle = false,
    required this.activeStateIds,
    required this.activeTransitionIds,
    this.isSimulationStuck = false,
  });

  final bool isHoveringHandle;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawTransitions(canvas);
    _drawLiveWire(canvas);
    _drawStates(canvas);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFF1E2333)
      ..style = PaintingStyle.fill;

    const step = 28.0;
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
        baseColor = const Color(0xFF00E5FF); // Neon Cyan
        strokeWidth = 3.5;
      } else if (isSelected) {
        baseColor = const Color(0xFF818CF8); // Indigo Accent
        strokeWidth = 2.8;
      } else {
        baseColor = const Color(0xFF5B677E); // Slate line
        strokeWidth = 2.0;
      }

      // Outer glow for active transition
      if (isActive) {
        final glowPaint = Paint()
          ..color = const Color(0x6600E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

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
            : (isSelected ? const Color(0xFFA5B4FC) : const Color(0xFFE2E8F0)),
        fontSize: 12.0,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeWidth = max(textPainter.width + 14.0, 24.0);
    final badgeHeight = max(textPainter.height + 6.0, 20.0);
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: position, width: badgeWidth, height: badgeHeight),
      const Radius.circular(10.0),
    );

    // Subtle drop shadow behind badge
    canvas.drawRRect(
      badgeRect.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );

    // Pill background
    final bgPaint = Paint()
      ..color = const Color(0xFF161922)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(badgeRect, bgPaint);

    // Pill border
    final borderPaint = Paint()
      ..color = isActive
          ? const Color(0xFF00E5FF)
          : (isSelected ? const Color(0xFF818CF8) : const Color(0xFF333B4F))
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected || isActive ? 1.6 : 1.2;
    canvas.drawRRect(badgeRect, borderPaint);

    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy - textPainter.height / 2),
    );
  }

  void _drawLiveWire(Canvas canvas) {
    if (wireSourceStateId == null || wireCurrentPosition == null) return;
    final startNode = automaton.states[wireSourceStateId];
    if (startNode == null) return;

    final start = startNode.position;
    final end = wireCurrentPosition!;

    // Glow line
    final glowPaint = Paint()
      ..color = const Color(0x666366F1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawLine(start, end, glowPaint);

    // Core line
    final wirePaint = Paint()
      ..color = const Color(0xFF818CF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, wirePaint);

    // Live arrowhead at cursor
    final delta = end - start;
    if (delta.distance > 5.0) {
      final angle = atan2(delta.dy, delta.dx);
      TransitionGeometry.drawArrowHead(
        canvas,
        end,
        angle,
        Paint()..color = const Color(0xFF818CF8),
      );
    }
  }

  void _drawStates(Canvas canvas) {
    for (final node in automaton.states.values) {
      final isSelected = node.id == selectedStateId;
      final isActive = activeStateIds.contains(node.id);
      final isHovered = node.id == hoveredStateId;
      final isWireSource = node.id == wireSourceStateId;

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
          ..color = glowColor.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0);
        canvas.drawCircle(node.position, TransitionGeometry.nodeRadius + 9.0, glowPaint);
      } else if (isSelected || isWireSource) {
        final selectGlow = Paint()
          ..color = const Color(0x4D6366F1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
        canvas.drawCircle(node.position, TransitionGeometry.nodeRadius + 6.0, selectGlow);
      }

      // 3. Drop shadow
      canvas.drawCircle(
        node.position + const Offset(0, 3),
        TransitionGeometry.nodeRadius,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
      );

      // 4. Main State Circle Fill
      final fillPaint = Paint()
        ..shader = RadialGradient(
          colors: isSelected
              ? [const Color(0xFF2C3246), const Color(0xFF1B2030)]
              : (isActive
                  ? [const Color(0xFF1E3A2F), const Color(0xFF0D221A)]
                  : [const Color(0xFF1F2432), const Color(0xFF141722)]),
        ).createShader(Rect.fromCircle(center: node.position, radius: TransitionGeometry.nodeRadius));

      canvas.drawCircle(node.position, TransitionGeometry.nodeRadius, fillPaint);

      // 5. Main State Circle Border
      final Color borderColor;
      final double borderWidth;
      if (isActive) {
        borderColor = isSimulationStuck ? const Color(0xFFFF5252) : const Color(0xFF00E676);
        borderWidth = 3.0;
      } else if (isSelected || isWireSource) {
        borderColor = const Color(0xFF818CF8);
        borderWidth = 2.8;
      } else if (isHovered) {
        borderColor = const Color(0xFF94A3B8);
        borderWidth = 2.2;
      } else {
        borderColor = const Color(0xFF475569);
        borderWidth = 1.8;
      }

      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawCircle(node.position, TransitionGeometry.nodeRadius, borderPaint);

      // 6. Accepting State Inner Ring
      if (node.isAccept) {
        final innerBorderPaint = Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        canvas.drawCircle(node.position, TransitionGeometry.nodeRadius - 6.0, innerBorderPaint);
      }

      // 7. Label Text
      final textSpan = TextSpan(
        text: node.label,
        style: TextStyle(
          color: isActive ? Colors.white : const Color(0xFFF8FAFC),
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

      // 8. Quick Connection Handle when selected
      if (isSelected && wireSourceStateId == null) {
        final handlePos = node.position + const Offset(TransitionGeometry.nodeRadius + 14.0, 0);
        final radius = isHoveringHandle ? 11.0 : 9.0;
        final glowRadius = isHoveringHandle ? 18.0 : 14.0;

        // Outer cyan glow
        canvas.drawCircle(
          handlePos,
          glowRadius,
          Paint()
            ..color = const Color(0x6600E5FF)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0),
        );

        // Circular handle button
        canvas.drawCircle(
          handlePos,
          radius,
          Paint()..color = isHoveringHandle ? const Color(0xFF67E8F9) : const Color(0xFF00E5FF),
        );

        // Inner plus icon
        final plusPaint = Paint()
          ..color = const Color(0xFF0C0E14)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(handlePos - const Offset(4, 0), handlePos + const Offset(4, 0), plusPaint);
        canvas.drawLine(handlePos - const Offset(0, 4), handlePos + const Offset(0, 4), plusPaint);
      }
    }
  }

  void _drawInitialArrow(Canvas canvas, Offset center) {
    const arrowLen = 38.0;
    final tip = center - const Offset(TransitionGeometry.nodeRadius, 0);
    final start = tip - const Offset(arrowLen, 0);

    final linePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, tip, linePaint);
    TransitionGeometry.drawArrowHead(
      canvas,
      tip,
      0,
      Paint()..color = const Color(0xFF38BDF8),
    );
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) => true;
}
