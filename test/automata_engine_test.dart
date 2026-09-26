import 'package:infinite_state/core/engine/automata_simulator.dart';
import 'package:infinite_state/core/layout/force_directed_layout.dart';
import 'package:infinite_state/core/layout/sugiyama_layout.dart';
import 'package:infinite_state/core/presets/example_automata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Automata Domain & Engine Tests', () {
    test('Binary Divisible by 3 qualifies as a DFA', () {
      final preset = ExampleAutomata.binaryDivisibleBy3;
      expect(preset.automaton.isDfa, isTrue);
      expect(preset.automaton.hasEpsilonTransitions, isFalse);
      expect(preset.automaton.alphabet, equals({'0', '1'}));
    });

    test('Binary Divisible by 3 correctly accepts and rejects strings', () {
      final automaton = ExampleAutomata.binaryDivisibleBy3.automaton;

      // 0 = 0 (mod 3 = 0) -> ACCEPT
      expect(
        AutomataSimulator.run(automaton: automaton, inputTape: '0')
            .isStringAccepted,
        isTrue,
      );

      // 11 = 3 (mod 3 = 0) -> ACCEPT
      expect(
        AutomataSimulator.run(automaton: automaton, inputTape: '11')
            .isStringAccepted,
        isTrue,
      );

      // 110 = 6 (mod 3 = 0) -> ACCEPT
      expect(
        AutomataSimulator.run(automaton: automaton, inputTape: '110')
            .isStringAccepted,
        isTrue,
      );

      // 1001 = 9 (mod 3 = 0) -> ACCEPT
      expect(
        AutomataSimulator.run(automaton: automaton, inputTape: '1001')
            .isStringAccepted,
        isTrue,
      );

      // 1 = 1 (mod 3 = 1) -> REJECT
      expect(
        AutomataSimulator.run(automaton: automaton, inputTape: '1')
            .isStringAccepted,
        isFalse,
      );

      // 10 = 2 (mod 3 = 2) -> REJECT
      expect(
        AutomataSimulator.run(automaton: automaton, inputTape: '10')
            .isStringAccepted,
        isFalse,
      );

      // 100 = 4 (mod 3 = 1) -> REJECT
      expect(
        AutomataSimulator.run(automaton: automaton, inputTape: '100')
            .isStringAccepted,
        isFalse,
      );
    });

    test('Epsilon-NFA correctly computes closures and branches concurrently', () {
      final preset = ExampleAutomata.epsilonNfaEven0sOr1s;
      expect(preset.automaton.isDfa, isFalse);
      expect(preset.automaton.hasEpsilonTransitions, isTrue);

      // Initial state 'qs' has epsilon transitions to 'q0e' and 'q1e'
      final closure = preset.automaton.epsilonClosure({'qs'});
      expect(closure, containsAll({'qs', 'q0e', 'q1e'}));

      // "001" has two 0s (even) and one 1 (odd) -> should accept via even 0s branch
      final sim1 = AutomataSimulator.run(
        automaton: preset.automaton,
        inputTape: '001',
      );
      expect(sim1.isStringAccepted, isTrue);

      // "011" has one 0 (odd) and two 1s (even) -> should accept via even 1s branch
      final sim2 = AutomataSimulator.run(
        automaton: preset.automaton,
        inputTape: '011',
      );
      expect(sim2.isStringAccepted, isTrue);

      // "01" has one 0 (odd) and one 1 (odd) -> REJECT
      final sim3 = AutomataSimulator.run(
        automaton: preset.automaton,
        inputTape: '01',
      );
      expect(sim3.isStringAccepted, isFalse);
    });

    test('Simulator step-by-step time travel', () {
      final automaton = ExampleAutomata.binaryDivisibleBy3.automaton;
      final sim = AutomataSimulator.run(automaton: automaton, inputTape: '11');

      expect(sim.currentStepIndex, equals(0));
      expect(sim.canStepForward, isTrue);
      expect(sim.canStepBackward, isFalse);

      sim.stepForward();
      expect(sim.currentStepIndex, equals(1));
      expect(sim.currentStep.consumedSymbol, equals('1'));
      expect(sim.canStepBackward, isTrue);

      sim.stepForward();
      expect(sim.currentStepIndex, equals(2));
      expect(sim.currentStep.consumedSymbol, equals('1'));
      expect(sim.currentStep.isAccepted, isTrue);
      expect(sim.isAtEnd, isTrue);

      sim.stepBackward();
      expect(sim.currentStepIndex, equals(1));
    });

    test('ForceDirectedLayout produces valid positions for all states', () {
      final automaton = ExampleAutomata.binaryDivisibleBy3.automaton;
      const layout = ForceDirectedLayout(iterations: 30);
      final positions = layout.calculateLayout(automaton);

      expect(positions.length, equals(automaton.states.length));
      for (final state in automaton.states.values) {
        expect(positions[state.id], isNotNull);
        expect(positions[state.id]!.dx.isFinite, isTrue);
        expect(positions[state.id]!.dy.isFinite, isTrue);
      }
    });

    test('SugiyamaLayout ranks states in hierarchical layers', () {
      final automaton = ExampleAutomata.binaryDivisibleBy3.automaton;
      const layout = SugiyamaLayout();
      final positions = layout.calculateLayout(automaton);

      expect(positions.length, equals(automaton.states.length));
      for (final state in automaton.states.values) {
        expect(positions[state.id], isNotNull);
        expect(positions[state.id]!.dx.isFinite, isTrue);
        expect(positions[state.id]!.dy.isFinite, isTrue);
      }
    });
  });
}
