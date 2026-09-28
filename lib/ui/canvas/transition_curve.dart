import 'dart:math';
import 'dart:ui';

class EdgeGeometry {
  final Path path;
  final Offset labelPosition;
  final Offset arrowTip;
  final double arrowDirection;
  final bool isCurved;
  final Offset? curveStart;
  final Offset? controlPoint;
  final Offset? curveEnd;

  const EdgeGeometry({
    required this.path,
    required this.labelPosition,
    required this.arrowTip,
    required this.arrowDirection,
    this.isCurved = false,
    this.curveStart,
    this.controlPoint,
    this.curveEnd,
  });
}

class TransitionGeometry {
  static const double nodeRadius = 30.0;
  static const double arrowLength = 12.0;
  static const double arrowAngle = pi / 6; // 30 degrees

  /// Computes the path for a directed transition from [start] to [end].
  /// If [hasReciprocal] is true, curves the line outward with [curveOffset].
  static EdgeGeometry calculateEdge({
    required Offset start,
    required Offset end,
    required bool hasReciprocal,
    double curveOffset = 36.0,
    List<Offset>? obstacles,
  }) {
    final delta = end - start;
    final distance = delta.distance;

    if (distance < 1.0) {
      // Degenerate case fallback
      return EdgeGeometry(
        path: Path(),
        labelPosition: start,
        arrowTip: end,
        arrowDirection: 0.0,
        isCurved: false,
      );
    }

    final unit = delta / distance;
    // Perpendicular normal vector (rotated 90 degrees counterclockwise)
    final normal = Offset(-unit.dy, unit.dx);

    bool shouldCurve = hasReciprocal;
    double effectiveCurveOffset = curveOffset;

    if (!hasReciprocal) {
      // Check for collision with intermediate state nodes (obstacles)
      Offset? collidedObstacle;
      double minPerpDist = double.infinity;
      double obstacleSide = 1.0;

      if (obstacles != null && obstacles.isNotEmpty) {
        for (final obs in obstacles) {
          // Ignore start and end nodes
          if ((obs - start).distance < 10.0 || (obs - end).distance < 10.0) {
            continue;
          }

          // Projection along unit vector
          final proj = (obs.dx - start.dx) * unit.dx + (obs.dy - start.dy) * unit.dy;
          // Only check obstacles situated between start and end
          if (proj > nodeRadius && proj < distance - nodeRadius) {
            // Perpendicular signed distance to the segment line
            final perp = (obs.dx - start.dx) * normal.dx + (obs.dy - start.dy) * normal.dy;
            if (perp.abs() < nodeRadius + 20.0) {
              if (perp.abs() < minPerpDist) {
                minPerpDist = perp.abs();
                collidedObstacle = obs;
                obstacleSide = perp >= 0 ? 1.0 : -1.0;
              }
            }
          }
        }
      }

      if (collidedObstacle != null) {
        shouldCurve = true;
        // Curve away from the obstacle
        final directionFactor = obstacleSide > 0 ? -1.0 : 1.0;
        final clearance = max(55.0, (nodeRadius * 2.0 + 20.0) - minPerpDist + 25.0);
        effectiveCurveOffset = directionFactor * clearance;
      } else if (end.dx < start.dx - 15.0) {
        // Textbook back-edge in left-to-right layout: arch cleanly underneath
        shouldCurve = true;
        final span = (start.dx - end.dx).abs();
        final archMagnitude = (45.0 + 0.12 * span).clamp(50.0, 95.0);
        effectiveCurveOffset = -archMagnitude;
      }
    }

    if (!shouldCurve) {
      // Straight line from node perimeter to node perimeter
      final lineStart = start + unit * nodeRadius;
      final lineEnd = end - unit * nodeRadius;

      final path = Path()
        ..moveTo(lineStart.dx, lineStart.dy)
        ..lineTo(lineEnd.dx, lineEnd.dy);

      final labelPos = (lineStart + lineEnd) / 2 + normal * 14.0;
      final direction = atan2(unit.dy, unit.dx);

      return EdgeGeometry(
        path: path,
        labelPosition: labelPos,
        arrowTip: lineEnd,
        arrowDirection: direction,
        isCurved: false,
      );
    } else {
      // Curved quadratic Bézier
      final midPoint = (start + end) / 2;
      final controlPoint = midPoint + normal * effectiveCurveOffset;

      // Start on perimeter towards control point
      final startToCtrl = controlPoint - start;
      final startDist = startToCtrl.distance;
      final startUnit = startDist > 0.001 ? startToCtrl / startDist : unit;
      final curveStart = start + startUnit * nodeRadius;

      // End on perimeter from control point
      final ctrlToEnd = end - controlPoint;
      final endDist = ctrlToEnd.distance;
      final endUnit = endDist > 0.001 ? ctrlToEnd / endDist : unit;
      final curveEnd = end - endUnit * nodeRadius;

      final path = Path()
        ..moveTo(curveStart.dx, curveStart.dy)
        ..quadraticBezierTo(
          controlPoint.dx,
          controlPoint.dy,
          curveEnd.dx,
          curveEnd.dy,
        );

      // Label at peak of quadratic curve (t = 0.5)
      final normalSign = effectiveCurveOffset >= 0 ? 1.0 : -1.0;
      final labelPos = Offset(
        0.25 * curveStart.dx + 0.5 * controlPoint.dx + 0.25 * curveEnd.dx,
        0.25 * curveStart.dy + 0.5 * controlPoint.dy + 0.25 * curveEnd.dy,
      ) + normal * (normalSign * 12.0);

      final direction = atan2(endUnit.dy, endUnit.dx);

      return EdgeGeometry(
        path: path,
        labelPosition: labelPos,
        arrowTip: curveEnd,
        arrowDirection: direction,
        isCurved: true,
        curveStart: curveStart,
        controlPoint: controlPoint,
        curveEnd: curveEnd,
      );
    }
  }

  /// Computes a self-loop path arching above [center].
  static EdgeGeometry calculateSelfLoop({
    required Offset center,
    double loopRadius = 32.0,
  }) {
    // Self-loop emerges from top-left (angle -135°) and returns to top-right (angle -45°)
    const startAngle = -3 * pi / 4;
    const endAngle = -pi / 4;

    final startPoint = center + Offset(cos(startAngle), sin(startAngle)) * nodeRadius;
    final endPoint = center + Offset(cos(endAngle), sin(endAngle)) * nodeRadius;

    // Control points arching upward
    final cp1 = center + Offset(-loopRadius * 1.2, -nodeRadius - loopRadius * 1.8);
    final cp2 = center + Offset(loopRadius * 1.2, -nodeRadius - loopRadius * 1.8);

    final path = Path()
      ..moveTo(startPoint.dx, startPoint.dy)
      ..cubicTo(
        cp1.dx,
        cp1.dy,
        cp2.dx,
        cp2.dy,
        endPoint.dx,
        endPoint.dy,
      );

    final labelPos = center + Offset(0, -nodeRadius - loopRadius * 1.6);
    // Tangent at end of cubic curve towards endPoint
    final incomingVector = endPoint - cp2;
    final direction = atan2(incomingVector.dy, incomingVector.dx);

    return EdgeGeometry(
      path: path,
      labelPosition: labelPos,
      arrowTip: endPoint,
      arrowDirection: direction,
      isCurved: true,
    );
  }

  /// Appends an arrowhead at [tip] pointing in [direction].
  static void drawArrowHead(Canvas canvas, Offset tip, double direction, Paint paint) {
    final path = Path();
    final p1 = tip - Offset(cos(direction - arrowAngle), sin(direction - arrowAngle)) * arrowLength;
    final p2 = tip - Offset(cos(direction + arrowAngle), sin(direction + arrowAngle)) * arrowLength;

    path.moveTo(tip.dx, tip.dy);
    path.lineTo(p1.dx, p1.dy);
    path.lineTo(p2.dx, p2.dy);
    path.close();

    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }

  /// Determines whether [testPoint] hits the transition edge (curve/line or badge).
  static bool hitTest({
    required bool isSelfLoop,
    required Offset fromPos,
    required Offset toPos,
    required bool hasReciprocal,
    required Offset testPoint,
    double hitRadius = 14.0,
    List<Offset>? obstacles,
  }) {
    if (isSelfLoop) {
      final geom = calculateSelfLoop(center: fromPos);
      // 1. Direct hit on badge area (most intuitive place to click)
      if ((testPoint - geom.labelPosition).distance <= 22.0) {
        return true;
      }

      // 2. Check along the cubic loop curve
      const startAngle = -3 * pi / 4;
      const endAngle = -pi / 4;
      const loopRadius = 32.0;

      final p0 = fromPos + Offset(cos(startAngle), sin(startAngle)) * nodeRadius;
      final p3 = fromPos + Offset(cos(endAngle), sin(endAngle)) * nodeRadius;
      final p1 = fromPos + Offset(-loopRadius * 1.2, -nodeRadius - loopRadius * 1.8);
      final p2 = fromPos + Offset(loopRadius * 1.2, -nodeRadius - loopRadius * 1.8);

      for (double t = 0.0; t <= 1.0; t += 0.05) {
        final oneMinusT = 1.0 - t;
        final pt = p0 * (oneMinusT * oneMinusT * oneMinusT) +
            p1 * (3.0 * oneMinusT * oneMinusT * t) +
            p2 * (3.0 * oneMinusT * t * t) +
            p3 * (t * t * t);
        if ((testPoint - pt).distance <= hitRadius) {
          return true;
        }
      }
      return false;
    } else {
      final geom = calculateEdge(
        start: fromPos,
        end: toPos,
        hasReciprocal: hasReciprocal,
        obstacles: obstacles,
      );
      // 1. Direct hit on badge area
      if ((testPoint - geom.labelPosition).distance <= 22.0) {
        return true;
      }

      // 2. Check straight line or curved quadratic Bézier
      if (!geom.isCurved) {
        final delta = toPos - fromPos;
        final distance = delta.distance;
        if (distance < 1.0) return false;
        final unit = delta / distance;
        final lineStart = fromPos + unit * nodeRadius;
        final lineEnd = toPos - unit * nodeRadius;

        final ab = lineEnd - lineStart;
        final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
        if (lenSq == 0) return (testPoint - lineStart).distance <= hitRadius;
        final t = ((testPoint.dx - lineStart.dx) * ab.dx +
                (testPoint.dy - lineStart.dy) * ab.dy) /
            lenSq;
        final clampedT = t.clamp(0.0, 1.0);
        final proj = lineStart + ab * clampedT;
        return (testPoint - proj).distance <= hitRadius;
      } else {
        final curveStart = geom.curveStart!;
        final controlPoint = geom.controlPoint!;
        final curveEnd = geom.curveEnd!;

        for (double t = 0.0; t <= 1.0; t += 0.05) {
          final oneMinusT = 1.0 - t;
          final pt = curveStart * (oneMinusT * oneMinusT) +
              controlPoint * (2.0 * oneMinusT * t) +
              curveEnd * (t * t);
          if ((testPoint - pt).distance <= hitRadius) {
            return true;
          }
        }
        return false;
      }
    }
  }
}
