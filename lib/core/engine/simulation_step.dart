/// Represents an immutable point-in-time snapshot during the simulation of an automaton.
class SimulationStep {
  final int stepIndex;
  final int tapeIndex;
  final String? consumedSymbol;
  final Set<String> activeStateIds;
  final Set<String> traversedTransitionIds;
  final bool isAccepted;
  final bool isStuck;
  final String message;

  const SimulationStep({
    required this.stepIndex,
    required this.tapeIndex,
    required this.consumedSymbol,
    required this.activeStateIds,
    required this.traversedTransitionIds,
    required this.isAccepted,
    required this.isStuck,
    required this.message,
  });

  @override
  String toString() =>
      'Step $stepIndex (tape: $tapeIndex, sym: $consumedSymbol): states=$activeStateIds stuck=$isStuck accept=$isAccepted';
}
