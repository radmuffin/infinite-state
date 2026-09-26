import 'dart:math';
import 'dart:ui';

class TransitionGeometry {
  static const double nodeRadius = 30.0;
  static const double arrowLength = 12.0;
  static const double arrowAngle = pi / 6; // 30 degrees

  /// Computes the path for a directed transition from [start] to [end].
  /// If [hasReciprocal] is true, curves the line outward with [curveOffset].
  static ({
    Path path,
    Offset labelPosition,
    Offset arrowTip,
    double arrowDirection,
  }) calculateEdge({
    required Offset start,
    required Offset end,
    required bool hasReciprocal,
    double curveOffset = 36.0,
  }) {
    final delta = end - start;
    final distance = delta.distance;

    if (distance < 1.0) {
      // Degenerate case fallback
      return (
        path: Path(),
        labelPosition: start,
        arrowTip: end,
        arrowDirection: 0.0,
      );
    }

    final unit = delta / distance;
    // Perpendicular normal vector (rotated 90 degrees counterclockwise)
    final normal = Offset(-unit.dy, unit.dx);

    if (!hasReciprocal) {
      // Straight line from node perimeter to node perimeter
      final lineStart = start + unit * nodeRadius;
      final lineEnd = end - unit * nodeRadius;

      final path = Path()
        ..moveTo(lineStart.dx, lineStart.dy)
        ..lineTo(lineEnd.dx, lineEnd.dy);

      final labelPos = (lineStart + lineEnd) / 2 + normal * 14.0;
      final direction = atan2(unit.dy, unit.dx);

      return (
        path: path,
        labelPosition: labelPos,
        arrowTip: lineEnd,
        arrowDirection: direction,
      );
    } else {
      // Curved quadratic Bézier
      final midPoint = (start + end) / 2;
      final controlPoint = midPoint + normal * curveOffset;

      // Start on perimeter towards control point
      final startToCtrl = controlPoint - start;
      final startUnit = startToCtrl / startToCtrl.distance;
      final curveStart = start + startUnit * nodeRadius;

      // End on perimeter from control point
      final ctrlToEnd = end - controlPoint;
      final endUnit = ctrlToEnd / ctrlToEnd.distance;
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
      final labelPos = Offset(
        0.25 * curveStart.dx + 0.5 * controlPoint.dx + 0.25 * curveEnd.dx,
        0.25 * curveStart.dy + 0.5 * controlPoint.dy + 0.25 * curveEnd.dy,
      ) + normal * 12.0;

      final direction = atan2(endUnit.dy, endUnit.dx);

      return (
        path: path,
        labelPosition: labelPos,
        arrowTip: curveEnd,
        arrowDirection: direction,
      );
    }
  }

  /// Computes a self-loop path arching above [center].
  static ({
    Path path,
    Offset labelPosition,
    Offset arrowTip,
    double arrowDirection,
  }) calculateSelfLoop({
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

    return (
      path: path,
      labelPosition: labelPos,
      arrowTip: endPoint,
      arrowDirection: direction,
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
}
