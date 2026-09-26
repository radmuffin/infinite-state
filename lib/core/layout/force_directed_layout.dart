import 'dart:math';
import 'dart:ui';
import '../models/automaton.dart';
import 'layout_algorithm.dart';

/// Force-Directed Graph Layout based on the Fruchterman-Reingold algorithm
/// with simulated annealing cooling.
///
/// Nodes repel each other like electric charges, while edges act as springs
/// pulling connected nodes toward an equilibrium distance.
class ForceDirectedLayout implements LayoutAlgorithm {
  final int iterations;
  final double optimalDistance;

  const ForceDirectedLayout({
    this.iterations = 120,
    this.optimalDistance = 160.0,
  });

  @override
  String get name => 'Force-Directed (Spring)';

  @override
  String get description =>
      'Simulates physical repulsion and spring tension to untangle complex graphs.';

  @override
  Map<String, Offset> calculateLayout(
    Automaton automaton, {
    Size canvasSize = const Size(1200, 800),
  }) {
    final stateList = automaton.states.values.toList();
    if (stateList.isEmpty) return {};
    if (stateList.length == 1) {
      return {stateList.first.id: Offset(canvasSize.width / 2, canvasSize.height / 2)};
    }

    final positions = <String, Offset>{};
    final random = Random(42); // Deterministic seed for reproducible layouts
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);

    // Initialize positions if not set or all stacked
    for (int i = 0; i < stateList.length; i++) {
      final s = stateList[i];
      if (s.position == Offset.zero) {
        final angle = (2 * pi * i) / stateList.length;
        final radius = 150.0 + random.nextDouble() * 50.0;
        positions[s.id] = center + Offset(cos(angle) * radius, sin(angle) * radius);
      } else {
        positions[s.id] = s.position;
      }
    }

    final k = optimalDistance;
    final k2 = k * k;
    double temperature = canvasSize.width / 10.0;
    final coolingFactor = pow(0.01 / temperature, 1.0 / iterations).toDouble();

    // Map unique directed and undirected edges
    final edges = <({String from, String to})>[];
    for (final t in automaton.transitions) {
      if (!t.isSelfLoop) {
        edges.add((from: t.fromId, to: t.toId));
      }
    }

    for (int iter = 0; iter < iterations; iter++) {
      final displacements = <String, Offset>{
        for (final s in stateList) s.id: Offset.zero,
      };

      // 1. Repulsive forces between ALL pairs of vertices: f_r(d) = k^2 / d
      for (int i = 0; i < stateList.length; i++) {
        final uId = stateList[i].id;
        final posU = positions[uId]!;

        for (int j = i + 1; j < stateList.length; j++) {
          final vId = stateList[j].id;
          final posV = positions[vId]!;

          var delta = posU - posV;
          var distance = delta.distance;
          if (distance < 1.0) {
            // Avoid division by zero with small jitter
            delta = Offset(random.nextDouble() - 0.5, random.nextDouble() - 0.5);
            distance = 1.0;
          }

          final force = k2 / distance;
          final displacement = (delta / distance) * force;

          displacements[uId] = displacements[uId]! + displacement;
          displacements[vId] = displacements[vId]! - displacement;
        }
      }

      // 2. Attractive forces along edges: f_a(d) = d^2 / k
      for (final edge in edges) {
        final posU = positions[edge.from];
        final posV = positions[edge.to];
        if (posU == null || posV == null) continue;

        var delta = posV - posU;
        var distance = delta.distance;
        if (distance < 1.0) continue;

        final force = (distance * distance) / k;
        final displacement = (delta / distance) * force;

        displacements[edge.from] = displacements[edge.from]! + displacement;
        displacements[edge.to] = displacements[edge.to]! - displacement;
      }

      // 3. Weak pull toward canvas center to prevent drift
      for (final s in stateList) {
        final pos = positions[s.id]!;
        final toCenter = center - pos;
        displacements[s.id] = displacements[s.id]! + toCenter * 0.05;
      }

      // 4. Displace nodes capped by current temperature
      for (final s in stateList) {
        final disp = displacements[s.id]!;
        final dispLength = disp.distance;
        if (dispLength > 0) {
          final limitedDisp = (disp / dispLength) * min(dispLength, temperature);
          var newPos = positions[s.id]! + limitedDisp;

          // Keep within reasonable padding bounds
          newPos = Offset(
            newPos.dx.clamp(100.0, canvasSize.width - 100.0),
            newPos.dy.clamp(100.0, canvasSize.height - 100.0),
          );
          positions[s.id] = newPos;
        }
      }

      // Simulated annealing: reduce temperature
      temperature *= coolingFactor;
    }

    return positions;
  }
}
