import 'dart:math';
import 'dart:ui';
import '../models/automaton.dart';
import 'layout_algorithm.dart';

/// Hierarchical Layered Layout (Sugiyama method adaptation for finite automata).
///
/// Places the initial state on the far left, assigns states to logical layers
/// based on their transition distance from the start, and centers them vertically
/// to produce clean textbook flow diagrams (Left-to-Right).
class SugiyamaLayout implements LayoutAlgorithm {
  final double layerSpacing;
  final double nodeSpacing;

  const SugiyamaLayout({
    this.layerSpacing = 220.0,
    this.nodeSpacing = 140.0,
  });

  @override
  String get name => 'Hierarchical (Textbook Flow)';

  @override
  String get description =>
      'Arranges states in left-to-right layers from initial state to accepting states.';

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

    final initial = automaton.initialState ?? stateList.first;
    final layerMap = <String, int>{};
    final visited = <String>{};

    // 1. Layer assignment via BFS from the initial state
    final queue = <String>[initial.id];
    layerMap[initial.id] = 0;
    visited.add(initial.id);

    while (queue.isNotEmpty) {
      final currId = queue.removeAt(0);
      final currLayer = layerMap[currId]!;

      for (final t in automaton.transitionsFrom(currId)) {
        if (!t.isSelfLoop) {
          final targetId = t.toId;
          if (!visited.contains(targetId)) {
            visited.add(targetId);
            layerMap[targetId] = currLayer + 1;
            queue.add(targetId);
          } else {
            // If already visited, we might push it to a deeper layer if reachable via longer chain
            if (layerMap[targetId]! < currLayer + 1) {
              // Keep layering forward-flowing
              layerMap[targetId] = currLayer + 1;
            }
          }
        }
      }
    }

    // Assign any unvisited (disconnected) states to layer 0 or maximum layer
    int maxLayer = layerMap.values.fold(0, max);
    for (final s in stateList) {
      if (!layerMap.containsKey(s.id)) {
        layerMap[s.id] = maxLayer + 1;
      }
    }

    // 2. Group states by layer
    final layers = <int, List<String>>{};
    for (final entry in layerMap.entries) {
      layers.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    final sortedLayerIndices = layers.keys.toList()..sort();
    final totalLayers = sortedLayerIndices.length;

    // 3. Compute (x, y) coordinates
    final positions = <String, Offset>{};
    final totalWidth = (totalLayers - 1) * layerSpacing;
    final startX = (canvasSize.width - totalWidth) / 2;

    for (int colIdx = 0; colIdx < sortedLayerIndices.length; colIdx++) {
      final layerIndex = sortedLayerIndices[colIdx];
      final nodesInLayer = layers[layerIndex]!;
      final x = startX + colIdx * layerSpacing;

      final totalHeight = (nodesInLayer.length - 1) * nodeSpacing;
      final startY = (canvasSize.height - totalHeight) / 2;

      for (int rowIdx = 0; rowIdx < nodesInLayer.length; rowIdx++) {
        final stateId = nodesInLayer[rowIdx];
        final y = startY + rowIdx * nodeSpacing;
        positions[stateId] = Offset(x, y);
      }
    }

    return positions;
  }
}
