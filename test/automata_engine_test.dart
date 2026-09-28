import 'package:infinite_state/core/engine/automata_simulator.dart';
import 'package:infinite_state/core/layout/force_directed_layout.dart';
import 'package:infinite_state/core/layout/sugiyama_layout.dart';
import 'package:infinite_state/core/models/automaton.dart';
import 'package:infinite_state/core/presets/example_automata.dart';
import 'package:infinite_state/state/studio_controller.dart';
import 'package:infinite_state/ui/canvas/transition_curve.dart';
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

    test('StudioController setMatrixCell dynamically modifies transition graph', () {
      final automaton = ExampleAutomata.binaryDivisibleBy3.automaton;
      final controller = StudioController(initialAutomaton: automaton);

      // Initially q0 on '0' goes to q0.
      expect(controller.automaton.getTargets('q0', '0'), {'q0'});

      // Change q0 on '0' to transition to q1 instead
      controller.setMatrixCell('q0', '0', {'q1'});
      expect(controller.automaton.getTargets('q0', '0'), {'q1'});

      // Change q0 on '0' to transition to both q1 and q2 (NFA branching)
      controller.setMatrixCell('q0', '0', {'q1', 'q2'});
      final targets = controller.automaton.getTargets('q0', '0');
      expect(targets.contains('q1'), isTrue);
      expect(targets.contains('q2'), isTrue);
      expect(controller.automaton.isDfa, isFalse);

      // Clear transition from q0 on '0'
      controller.setMatrixCell('q0', '0', {});
      expect(controller.automaton.getTargets('q0', '0'), isEmpty);

      controller.dispose();
    });

    test('Automaton serialization round-trip maintains graph fidelity', () {
      final original = ExampleAutomata.binaryDivisibleBy3.automaton;
      final json = original.toJson();
      final restored = Automaton.fromJson(json);

      expect(restored.states.length, equals(original.states.length));
      expect(restored.transitions.length, equals(original.transitions.length));
      expect(restored.initialState?.id, equals(original.initialState?.id));
      expect(restored.acceptStateIds, equals(original.acceptStateIds));
      expect(restored.alphabet, equals(original.alphabet));
    });

    test('TransitionGeometry hitTest detects clicks on edges and badges', () {
      // 1. Straight edge from (100, 100) to (300, 100)
      const fromPos = Offset(100, 100);
      const toPos = Offset(300, 100);

      // Midpoint on line segment: (200, 100)
      expect(
        TransitionGeometry.hitTest(
          isSelfLoop: false,
          fromPos: fromPos,
          toPos: toPos,
          hasReciprocal: false,
          testPoint: const Offset(200, 100),
        ),
        isTrue,
      );

      // Slightly off the line within hitRadius (14px): (200, 108)
      expect(
        TransitionGeometry.hitTest(
          isSelfLoop: false,
          fromPos: fromPos,
          toPos: toPos,
          hasReciprocal: false,
          testPoint: const Offset(200, 108),
        ),
        isTrue,
      );

      // Far away point: (200, 200) -> false
      expect(
        TransitionGeometry.hitTest(
          isSelfLoop: false,
          fromPos: fromPos,
          toPos: toPos,
          hasReciprocal: false,
          testPoint: const Offset(200, 200),
        ),
        isFalse,
      );

      // 2. Self-loop on (200, 200)
      final loopGeom = TransitionGeometry.calculateSelfLoop(center: const Offset(200, 200));
      // Clicking exactly on label position
      expect(
        TransitionGeometry.hitTest(
          isSelfLoop: true,
          fromPos: const Offset(200, 200),
          toPos: const Offset(200, 200),
          hasReciprocal: false,
          testPoint: loopGeom.labelPosition,
        ),
        isTrue,
      );

      // 3. Reciprocal curved edge
      final curvedGeom = TransitionGeometry.calculateEdge(
        start: fromPos,
        end: toPos,
        hasReciprocal: true,
      );
      // Clicking near the label position of the curved edge
      expect(
        TransitionGeometry.hitTest(
          isSelfLoop: false,
          fromPos: fromPos,
          toPos: toPos,
          hasReciprocal: true,
          testPoint: curvedGeom.labelPosition,
        ),
        isTrue,
      );
    });

    test('StudioController connector mutation methods (toggle, endpoints, delete)', () {
      final automaton = ExampleAutomata.binaryDivisibleBy3.automaton;
      final controller = StudioController(initialAutomaton: automaton);

      // Find transition from q0 to q1 (which is on '1')
      final t = controller.automaton.transitions
          .firstWhere((tr) => tr.fromId == 'q0' && tr.toId == 'q1');

      // 1. Toggle symbol: add '0' so it triggers on both '1' and '0'
      controller.toggleTransitionSymbol(t.id, '0');
      var updatedT = controller.automaton.transitions.firstWhere((tr) => tr.id == t.id);
      expect(updatedT.symbols, equals({'1', '0'}));

      // Toggle '0' off
      controller.toggleTransitionSymbol(t.id, '0');
      updatedT = controller.automaton.transitions.firstWhere((tr) => tr.id == t.id);
      expect(updatedT.symbols, equals({'1'}));

      // 2. Update endpoints: redirect q0 -> q1 to q0 -> q2
      controller.updateTransitionEndpoints(t.id, toId: 'q2');
      final redirected = controller.automaton.transitions.firstWhere((tr) => tr.id == t.id);
      expect(redirected.fromId, 'q0');
      expect(redirected.toId, 'q2');

      // 3. Delete transition
      controller.deleteTransition(t.id);
      expect(
        controller.automaton.transitions.any((tr) => tr.id == t.id),
        isFalse,
      );

      // Verify undo restores it
      controller.undo();
      expect(
        controller.automaton.transitions.any((tr) => tr.id == t.id),
        isTrue,
      );

      controller.dispose();
    });

    test('StudioController autoAddConnectedNode creates node, connector, and handles chaining and undo', () {
      final controller = StudioController(initialAutomaton: Automaton());
      controller.addStateAt(const Offset(100, 100)); // Creates q0
      expect(controller.automaton.states.containsKey('q0'), isTrue);
      expect(controller.automaton.transitions, isEmpty);

      // 1. Auto add node from q0
      final q1 = controller.autoAddConnectedNode('q0');
      expect(q1, isNotNull);
      expect(controller.automaton.states.containsKey(q1!.id), isTrue);
      expect(controller.selectedStateId, equals(q1.id));
      expect(controller.automaton.transitions.length, equals(1));

      final t1 = controller.automaton.transitions.first;
      expect(t1.fromId, equals('q0'));
      expect(t1.toId, equals(q1.id));
      expect(t1.symbols, contains('0'));

      // 2. Chain another node from q1
      final q2 = controller.autoAddConnectedNode(q1.id);
      expect(q2, isNotNull);
      expect(controller.selectedStateId, equals(q2!.id));
      expect(controller.automaton.transitions.length, equals(2));
      expect(q2.position.dx, greaterThan(q1.position.dx));

      // 3. Auto add branching node from q0 (should pick '1' since '0' is used)
      final q3 = controller.autoAddConnectedNode('q0');
      expect(q3, isNotNull);
      final transitionsFromQ0 = controller.automaton.transitionsFrom('q0');
      expect(transitionsFromQ0.length, equals(2));
      final tBranch = transitionsFromQ0.firstWhere((t) => t.toId == q3!.id);
      expect(tBranch.symbols, contains('1'));

      // Non-overlapping check: q3 position should not collide with q1
      expect((q3!.position - q1.position).distance, greaterThanOrEqualTo(60.0));

      // 4. Undo should remove q3 and its transition
      controller.undo();
      expect(controller.automaton.states.containsKey(q3.id), isFalse);
      expect(controller.automaton.transitions.any((t) => t.toId == q3.id), isFalse);

      controller.dispose();
    });

    test('StudioController typeTransitionSymbol interprets "ab" as "a, b" without requiring comma', () {
      final controller = StudioController(initialAutomaton: Automaton());
      controller.addStateAt(const Offset(100, 100)); // creates q0

      // Auto add node q1 -> sets active connector to q0 -> q1 (default symbol '0')
      controller.autoAddConnectedNode('q0');
      expect(controller.hasActiveOrSelectedTransition, isTrue);

      // Type 'a' directly without clicking anything -> replaces default '0' with 'a'
      controller.typeTransitionSymbol('a');
      var t = controller.automaton.transitions.first;
      expect(t.symbols, equals({'a'}));
      expect(controller.transitionTypingActive, isTrue);

      // Type 'b' directly WITHOUT typing comma -> automatically appends to form {'a', 'b'}
      controller.typeTransitionSymbol('b');
      t = controller.automaton.transitions.first;
      expect(t.symbols, equals({'a', 'b'}));

      // Type 'c' directly -> appends to form {'a', 'b', 'c'}
      controller.typeTransitionSymbol('c');
      t = controller.automaton.transitions.first;
      expect(t.symbols, equals({'a', 'b', 'c'}));

      // Backspace removes the most recently added symbol ('c') -> leaving {'a', 'b'}
      expect(controller.canBackspaceTransitionSymbol, isTrue);
      controller.backspaceTransitionSymbol();
      t = controller.automaton.transitions.first;
      expect(t.symbols, equals({'a', 'b'}));

      // Reselecting the transition starts a fresh session; typing 'x' replaces previous symbols
      controller.selectTransition(t.id);
      expect(controller.transitionTypingActive, isFalse);
      controller.typeTransitionSymbol('x');
      t = controller.automaton.transitions.first;
      expect(t.symbols, equals({'x'}));

      // Multi-character string "ab" is also supported and yields {'a', 'b'}
      controller.finishTransitionTyping();
      controller.typeTransitionSymbol('ab');
      t = controller.automaton.transitions.first;
      expect(t.symbols, equals({'a', 'b'}));

      // Comma-separated string "0, 1" is also supported and yields {'0', '1'}
      controller.finishTransitionTyping();
      controller.typeTransitionSymbol('0, 1');
      t = controller.automaton.transitions.first;
      expect(t.symbols, equals({'0', '1'}));

      controller.dispose();
    });
  });
}
