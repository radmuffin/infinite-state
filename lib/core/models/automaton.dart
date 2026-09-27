import 'state_node.dart';
import 'transition.dart';

/// Represents a formal finite state automaton (DFA or NFA),
/// formalized as the 5-tuple: M = (Q, Σ, δ, q₀, F).
class Automaton {
  final Map<String, StateNode> states;
  final List<Transition> transitions;

  Automaton({
    Map<String, StateNode>? states,
    List<Transition>? transitions,
  })  : states = Map.unmodifiable(states ?? {}),
        transitions = List.unmodifiable(transitions ?? []);

  /// The input alphabet Σ, consisting of all non-epsilon symbols used in transitions.
  Set<String> get alphabet {
    final set = <String>{};
    for (final t in transitions) {
      for (final s in t.symbols) {
        if (s != Transition.epsilon && s.isNotEmpty) {
          set.add(s);
        }
      }
    }
    return set;
  }

  /// Initial state q₀, if defined.
  StateNode? get initialState {
    try {
      return states.values.firstWhere((s) => s.isInitial);
    } catch (_) {
      return null;
    }
  }

  /// The set of accept states F.
  Set<String> get acceptStateIds =>
      states.values.where((s) => s.isAccept).map((s) => s.id).toSet();

  /// Transitions originating from [stateId].
  List<Transition> transitionsFrom(String stateId) =>
      transitions.where((t) => t.fromId == stateId).toList();

  /// Transitions leading into [stateId].
  List<Transition> transitionsTo(String stateId) =>
      transitions.where((t) => t.toId == stateId).toList();

  /// Transitions directly between [fromId] and [toId].
  List<Transition> transitionsBetween(String fromId, String toId) =>
      transitions.where((t) => t.fromId == fromId && t.toId == toId).toList();

  /// Target state IDs reachable from [fromId] on reading [symbol].
  Set<String> getTargets(String fromId, String symbol) => transitionsFrom(fromId)
      .where((t) => t.symbols.contains(symbol))
      .map((t) => t.toId)
      .toSet();

  /// Whether the automaton has any epsilon transitions.
  bool get hasEpsilonTransitions =>
      transitions.any((t) => t.symbols.contains(Transition.epsilon));

  /// Determines if this automaton qualifies strictly as a Deterministic Finite Automaton (DFA):
  /// 1. Exactly one initial state.
  /// 2. No epsilon transitions.
  /// 3. For every state and symbol, there is at most one outbound transition.
  bool get isDfa {
    final initCount = states.values.where((s) => s.isInitial).length;
    if (initCount != 1) return false;
    if (hasEpsilonTransitions) return false;

    for (final state in states.values) {
      final seenSymbols = <String>{};
      for (final t in transitionsFrom(state.id)) {
        for (final sym in t.symbols) {
          if (seenSymbols.contains(sym)) {
            return false; // Nondeterministic branch detected
          }
          seenSymbols.add(sym);
        }
      }
    }
    return true;
  }

  /// Computes the ε-closure of a set of states.
  /// That is, the set of all states reachable from [stateIds] via zero or more ε-transitions.
  Set<String> epsilonClosure(Set<String> stateIds) {
    final closure = Set<String>.from(stateIds);
    final stack = List<String>.from(stateIds);

    while (stack.isNotEmpty) {
      final currId = stack.removeLast();
      for (final t in transitionsFrom(currId)) {
        if (t.symbols.contains(Transition.epsilon)) {
          if (closure.add(t.toId)) {
            stack.add(t.toId);
          }
        }
      }
    }
    return closure;
  }

  /// Returns a new Automaton with updated or added state.
  Automaton setNode(StateNode node) {
    final newStates = Map<String, StateNode>.from(states);
    // If setting as initial, clear initial on other nodes
    if (node.isInitial) {
      for (final key in newStates.keys) {
        if (key != node.id && newStates[key]!.isInitial) {
          newStates[key] = newStates[key]!.copyWith(isInitial: false);
        }
      }
    }
    newStates[node.id] = node;
    return Automaton(states: newStates, transitions: transitions);
  }

  /// Returns a new Automaton with the state and its connected transitions removed.
  Automaton removeNode(String id) {
    final newStates = Map<String, StateNode>.from(states)..remove(id);
    final newTrans = transitions
        .where((t) => t.fromId != id && t.toId != id)
        .toList();
    return Automaton(states: newStates, transitions: newTrans);
  }

  /// Returns a new Automaton with an added or updated transition.
  Automaton setTransition(Transition transition) {
    final newTrans = transitions.where((t) => t.id != transition.id).toList()
      ..add(transition);
    return Automaton(states: states, transitions: newTrans);
  }

  /// Returns a new Automaton with the transition removed.
  Automaton removeTransition(String id) {
    final newTrans = transitions.where((t) => t.id != id).toList();
    return Automaton(states: states, transitions: newTrans);
  }

  Map<String, dynamic> toJson() => {
        'states': states.values.map((s) => s.toJson()).toList(),
        'transitions': transitions.map((t) => t.toJson()).toList(),
      };

  factory Automaton.fromJson(Map<String, dynamic> json) {
    final statesList = (json['states'] as List)
        .map((e) => StateNode.fromJson(e as Map<String, dynamic>));
    final statesMap = {for (final s in statesList) s.id: s};

    final transitionsList = (json['transitions'] as List)
        .map((e) => Transition.fromJson(e as Map<String, dynamic>))
        .toList();

    return Automaton(states: statesMap, transitions: transitionsList);
  }
}
