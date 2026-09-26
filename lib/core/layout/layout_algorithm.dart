import 'dart:ui';
import '../models/automaton.dart';

/// Strategy interface for graph auto-layout algorithms.
abstract class LayoutAlgorithm {
  String get name;
  String get description;

  /// Calculates new positions for the automaton's states and returns a mapping from state ID to new [Offset].
  Map<String, Offset> calculateLayout(
    Automaton automaton, {
    Size canvasSize = const Size(1200, 800),
  });
}
