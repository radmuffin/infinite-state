import 'dart:ui';
import '../models/automaton.dart';
import '../models/state_node.dart';
import '../models/transition.dart';

class AutomataPreset {
  final String title;
  final String description;
  final String defaultInput;
  final Automaton automaton;

  const AutomataPreset({
    required this.title,
    required this.description,
    required this.defaultInput,
    required this.automaton,
  });
}

class ExampleAutomata {
  /// DFA: Binary strings whose value is divisible by 3.
  /// Accepts: "0", "11" (3), "110" (6), "1001" (9), "1100" (12)
  static AutomataPreset get binaryDivisibleBy3 {
    final q0 = const StateNode(
      id: 'q0',
      label: 'q0 (rem 0)',
      position: Offset(200, 300),
      isInitial: true,
      isAccept: true,
    );
    final q1 = const StateNode(
      id: 'q1',
      label: 'q1 (rem 1)',
      position: Offset(500, 180),
      isInitial: false,
      isAccept: false,
    );
    final q2 = const StateNode(
      id: 'q2',
      label: 'q2 (rem 2)',
      position: Offset(500, 420),
      isInitial: false,
      isAccept: false,
    );

    final transitions = [
      Transition(id: 't1', fromId: 'q0', toId: 'q0', symbols: {'0'}),
      Transition(id: 't2', fromId: 'q0', toId: 'q1', symbols: {'1'}),
      Transition(id: 't3', fromId: 'q1', toId: 'q2', symbols: {'0'}),
      Transition(id: 't4', fromId: 'q1', toId: 'q0', symbols: {'1'}),
      Transition(id: 't5', fromId: 'q2', toId: 'q1', symbols: {'0'}),
      Transition(id: 't6', fromId: 'q2', toId: 'q2', symbols: {'1'}),
    ];

    return AutomataPreset(
      title: 'Binary Divisible by 3 (DFA)',
      description:
          'Recognizes binary representations of numbers divisible by 3 by tracking modular remainder.',
      defaultInput: '1001', // 9 in binary -> should accept
      automaton: Automaton(
        states: {'q0': q0, 'q1': q1, 'q2': q2},
        transitions: transitions,
      ),
    );
  }

  /// DFA: Strings over {a, b} containing the substring "ab".
  static AutomataPreset get containsSubstringAb {
    final q0 = const StateNode(
      id: 'q0',
      label: 'q0',
      position: Offset(200, 300),
      isInitial: true,
      isAccept: false,
    );
    final q1 = const StateNode(
      id: 'q1',
      label: 'q1',
      position: Offset(450, 300),
      isInitial: false,
      isAccept: false,
    );
    final q2 = const StateNode(
      id: 'q2',
      label: 'q2',
      position: Offset(700, 300),
      isInitial: false,
      isAccept: true,
    );

    final transitions = [
      Transition(id: 't1', fromId: 'q0', toId: 'q0', symbols: {'b'}),
      Transition(id: 't2', fromId: 'q0', toId: 'q1', symbols: {'a'}),
      Transition(id: 't3', fromId: 'q1', toId: 'q1', symbols: {'a'}),
      Transition(id: 't4', fromId: 'q1', toId: 'q2', symbols: {'b'}),
      Transition(id: 't5', fromId: 'q2', toId: 'q2', symbols: {'a', 'b'}),
    ];

    return AutomataPreset(
      title: 'Contains Substring "ab" (DFA)',
      description:
          'Accepts any string over {a, b} that contains "ab" as a contiguous substring.',
      defaultInput: 'babab',
      automaton: Automaton(
        states: {'q0': q0, 'q1': q1, 'q2': q2},
        transitions: transitions,
      ),
    );
  }

  /// NFA with ε-transitions: Strings with even 0s OR even 1s.
  static AutomataPreset get epsilonNfaEven0sOr1s {
    final qStart = const StateNode(
      id: 'qs',
      label: 'Start',
      position: Offset(150, 300),
      isInitial: true,
      isAccept: false,
    );
    // Sub-machine for even 0s
    final q0Even = const StateNode(
      id: 'q0e',
      label: 'Even 0s',
      position: Offset(400, 180),
      isInitial: false,
      isAccept: true,
    );
    final q0Odd = const StateNode(
      id: 'q0o',
      label: 'Odd 0s',
      position: Offset(650, 180),
      isInitial: false,
      isAccept: false,
    );

    // Sub-machine for even 1s
    final q1Even = const StateNode(
      id: 'q1e',
      label: 'Even 1s',
      position: Offset(400, 420),
      isInitial: false,
      isAccept: true,
    );
    final q1Odd = const StateNode(
      id: 'q1o',
      label: 'Odd 1s',
      position: Offset(650, 420),
      isInitial: false,
      isAccept: false,
    );

    final transitions = [
      // ε-branches from start
      Transition(
          id: 'te1',
          fromId: 'qs',
          toId: 'q0e',
          symbols: {Transition.epsilon}),
      Transition(
          id: 'te2',
          fromId: 'qs',
          toId: 'q1e',
          symbols: {Transition.epsilon}),

      // Even 0s branch
      Transition(id: 't_0e_1', fromId: 'q0e', toId: 'q0e', symbols: {'1'}),
      Transition(id: 't_0e_0', fromId: 'q0e', toId: 'q0o', symbols: {'0'}),
      Transition(id: 't_0o_1', fromId: 'q0o', toId: 'q0o', symbols: {'1'}),
      Transition(id: 't_0o_0', fromId: 'q0o', toId: 'q0e', symbols: {'0'}),

      // Even 1s branch
      Transition(id: 't_1e_0', fromId: 'q1e', toId: 'q1e', symbols: {'0'}),
      Transition(id: 't_1e_1', fromId: 'q1e', toId: 'q1o', symbols: {'1'}),
      Transition(id: 't_1o_0', fromId: 'q1o', toId: 'q1o', symbols: {'0'}),
      Transition(id: 't_1o_1', fromId: 'q1o', toId: 'q1e', symbols: {'1'}),
    ];

    return AutomataPreset(
      title: 'Even 0s or Even 1s (ε-NFA)',
      description:
          'Demonstrates nondeterministic branching using ε-transitions to split execution across two concurrent sub-machines.',
      defaultInput: '001', // has two 0s (even) -> accepted
      automaton: Automaton(
        states: {
          'qs': qStart,
          'q0e': q0Even,
          'q0o': q0Odd,
          'q1e': q1Even,
          'q1o': q1Odd,
        },
        transitions: transitions,
      ),
    );
  }

  static List<AutomataPreset> get all => [
        binaryDivisibleBy3,
        containsSubstringAb,
        epsilonNfaEven0sOr1s,
      ];
}
