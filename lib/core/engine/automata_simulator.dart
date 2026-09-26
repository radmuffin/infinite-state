import '../models/automaton.dart';
import 'simulation_step.dart';

/// Simulator engine that executes both DFA and NFA formal automata
/// symbol-by-symbol with full epsilon-closure support and time-travel history.
class AutomataSimulator {
  final Automaton automaton;
  final String inputTape;
  final List<SimulationStep> steps;

  int _currentStepIndex = 0;

  AutomataSimulator._({
    required this.automaton,
    required this.inputTape,
    required this.steps,
    int initialStep = 0,
  }) : _currentStepIndex = initialStep;

  /// Creates and executes a simulation of [automaton] against [inputTape].
  factory AutomataSimulator.run({
    required Automaton automaton,
    required String inputTape,
  }) {
    final steps = <SimulationStep>[];

    final initial = automaton.initialState;
    if (initial == null) {
      steps.add(
        const SimulationStep(
          stepIndex: 0,
          tapeIndex: 0,
          consumedSymbol: null,
          activeStateIds: {},
          traversedTransitionIds: {},
          isAccepted: false,
          isStuck: true,
          message: 'Error: No initial state designated.',
        ),
      );
      return AutomataSimulator._(
        automaton: automaton,
        inputTape: inputTape,
        steps: steps,
      );
    }

    // Step 0: Initial state and its ε-closure
    final initialClosure = automaton.epsilonClosure({initial.id});
    final acceptIds = automaton.acceptStateIds;
    final isInitialAccepted = initialClosure.any(acceptIds.contains);

    steps.add(
      SimulationStep(
        stepIndex: 0,
        tapeIndex: 0,
        consumedSymbol: null,
        activeStateIds: initialClosure,
        traversedTransitionIds: {},
        isAccepted: isInitialAccepted,
        isStuck: false,
        message: initialClosure.length > 1
            ? 'Initial state: ${initial.label} with ε-closure: {${initialClosure.map((id) => automaton.states[id]?.label ?? id).join(", ")}}'
            : 'Initial state: ${initial.label}',
      ),
    );

    var currentStates = initialClosure;
    for (int i = 0; i < inputTape.length; i++) {
      final symbol = inputTape[i];
      final nextStates = <String>{};
      final traversedTransitions = <String>{};

      for (final stateId in currentStates) {
        for (final t in automaton.transitionsFrom(stateId)) {
          if (t.symbols.contains(symbol)) {
            nextStates.add(t.toId);
            traversedTransitions.add(t.id);
          }
        }
      }

      if (nextStates.isEmpty) {
        // Trapped / stuck state
        steps.add(
          SimulationStep(
            stepIndex: steps.length,
            tapeIndex: i,
            consumedSymbol: symbol,
            activeStateIds: {},
            traversedTransitionIds: {},
            isAccepted: false,
            isStuck: true,
            message:
                'Stuck! No valid transition from {${currentStates.map((id) => automaton.states[id]?.label ?? id).join(", ")}} on symbol "$symbol". String Rejected.',
          ),
        );
        break;
      }

      // Compute ε-closure of reached states
      final closure = automaton.epsilonClosure(nextStates);
      final isStepAccepted = (i == inputTape.length - 1) &&
          closure.any(acceptIds.contains);

      final stateLabels = closure
          .map((id) => automaton.states[id]?.label ?? id)
          .join(', ');

      steps.add(
        SimulationStep(
          stepIndex: steps.length,
          tapeIndex: i + 1,
          consumedSymbol: symbol,
          activeStateIds: closure,
          traversedTransitionIds: traversedTransitions,
          isAccepted: isStepAccepted,
          isStuck: false,
          message:
              'Read "$symbol" → Active states: {$stateLabels}${isStepAccepted ? ' (Accepting!)' : ''}',
        ),
      );

      currentStates = closure;
    }

    return AutomataSimulator._(
      automaton: automaton,
      inputTape: inputTape,
      steps: steps,
    );
  }

  int get currentStepIndex => _currentStepIndex;
  SimulationStep get currentStep => steps[_currentStepIndex];
  int get totalSteps => steps.length;
  bool get canStepForward => _currentStepIndex < steps.length - 1;
  bool get canStepBackward => _currentStepIndex > 0;
  bool get isAtEnd => _currentStepIndex == steps.length - 1;

  /// Whether the input string is accepted by the automaton at the end of the simulation.
  bool get isStringAccepted {
    if (steps.isEmpty) return false;
    final lastStep = steps.last;
    if (lastStep.isStuck) return false;
    if (lastStep.tapeIndex != inputTape.length) return false;
    return lastStep.activeStateIds.any(automaton.acceptStateIds.contains);
  }

  void stepForward() {
    if (canStepForward) _currentStepIndex++;
  }

  void stepBackward() {
    if (canStepBackward) _currentStepIndex--;
  }

  void jumpTo(int index) {
    if (index >= 0 && index < steps.length) {
      _currentStepIndex = index;
    }
  }

  void reset() {
    _currentStepIndex = 0;
  }

  void runToEnd() {
    _currentStepIndex = steps.length - 1;
  }
}
