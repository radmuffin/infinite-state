import 'dart:ui';
import '../layout/sugiyama_layout.dart';
import '../models/automaton.dart';
import '../models/state_node.dart';
import '../models/transition.dart';
import 'regex_ast.dart';

class _Fragment {
  final String startId;
  final String acceptId;
  final Map<String, StateNode> states;
  final List<Transition> transitions;

  _Fragment({
    required this.startId,
    required this.acceptId,
    required this.states,
    required this.transitions,
  });
}

/// Converts a [RegexNode] AST into an equivalent [Automaton] (ε-NFA)
/// using textbook Thompson's Construction, and automatically lays out
/// the resulting graph with hierarchical textbook flow.
class ThompsonConstruction {
  int _stateCounter = 0;
  int _transitionCounter = 0;

  String _nextStateId() => 'q${_stateCounter++}';
  String _nextTransitionId() => 't_${_transitionCounter++}';

  StateNode _createState(String id, {bool isInitial = false, bool isAccept = false}) {
    return StateNode(
      id: id,
      label: id,
      position: Offset.zero,
      isInitial: isInitial,
      isAccept: isAccept,
    );
  }

  Transition _createTransition(String from, String to, String symbol) {
    return Transition(
      id: _nextTransitionId(),
      fromId: from,
      toId: to,
      symbols: {symbol},
    );
  }

  /// Builds an [Automaton] recognizing the language defined by [ast].
  static Automaton build(
    RegexNode ast, {
    Size canvasSize = const Size(1200, 800),
    bool applyLayout = true,
  }) {
    final builder = ThompsonConstruction();
    return builder._buildAutomaton(ast, canvasSize: canvasSize, applyLayout: applyLayout);
  }

  Automaton _buildAutomaton(
    RegexNode ast, {
    required Size canvasSize,
    required bool applyLayout,
  }) {
    final simplified = ast.simplify();
    final fragment = _buildFragment(simplified);

    // Re-index states in BFS/flow order starting from startId to acceptId
    // so node labels are clean q0, q1, q2...
    final orderedIds = _orderStateIds(fragment);
    final idMap = <String, String>{};
    for (int i = 0; i < orderedIds.length; i++) {
      idMap[orderedIds[i]] = 'q$i';
    }

    final newStartId = idMap[fragment.startId] ?? fragment.startId;
    final newAcceptId = idMap[fragment.acceptId] ?? fragment.acceptId;

    final reindexedStates = <String, StateNode>{};
    for (final oldId in orderedIds) {
      final newId = idMap[oldId]!;
      reindexedStates[newId] = StateNode(
        id: newId,
        label: newId,
        position: fragment.states[oldId]?.position ?? Offset.zero,
        isInitial: newId == newStartId,
        isAccept: newId == newAcceptId,
      );
    }

    // Merge multiple parallel transitions between same pairs of states
    final transitionMap = <String, Set<String>>{};
    for (final t in fragment.transitions) {
      final from = idMap[t.fromId] ?? t.fromId;
      final to = idMap[t.toId] ?? t.toId;
      final key = '$from->$to';
      transitionMap.putIfAbsent(key, () => <String>{}).addAll(t.symbols);
    }

    final reindexedTransitions = <Transition>[];
    int transIdx = 0;
    for (final entry in transitionMap.entries) {
      final parts = entry.key.split('->');
      reindexedTransitions.add(
        Transition(
          id: 't_$transIdx',
          fromId: parts[0],
          toId: parts[1],
          symbols: entry.value,
        ),
      );
      transIdx++;
    }

    var automaton = Automaton(
      states: reindexedStates,
      transitions: reindexedTransitions,
    );

    if (applyLayout) {
      const layout = SugiyamaLayout(layerSpacing: 180.0, nodeSpacing: 110.0);
      final positions = layout.calculateLayout(automaton, canvasSize: canvasSize);
      final positionedStates = <String, StateNode>{};
      for (final s in automaton.states.values) {
        positionedStates[s.id] = s.copyWith(
          position: positions[s.id] ?? s.position,
        );
      }
      automaton = Automaton(
        states: positionedStates,
        transitions: automaton.transitions,
      );
    }

    return automaton;
  }

  _Fragment _buildFragment(RegexNode node) {
    if (node is RegexEmpty) {
      final s = _nextStateId();
      final a = _nextStateId();
      return _Fragment(
        startId: s,
        acceptId: a,
        states: {
          s: _createState(s),
          a: _createState(a),
        },
        transitions: [],
      );
    }

    if (node is RegexEpsilon) {
      final s = _nextStateId();
      final a = _nextStateId();
      return _Fragment(
        startId: s,
        acceptId: a,
        states: {
          s: _createState(s),
          a: _createState(a),
        },
        transitions: [
          _createTransition(s, a, Transition.epsilon),
        ],
      );
    }

    if (node is RegexLiteral) {
      final s = _nextStateId();
      final a = _nextStateId();
      return _Fragment(
        startId: s,
        acceptId: a,
        states: {
          s: _createState(s),
          a: _createState(a),
        },
        transitions: [
          _createTransition(s, a, node.symbol),
        ],
      );
    }

    if (node is RegexConcat) {
      if (node.children.isEmpty) {
        return _buildFragment(const RegexEpsilon());
      }
      if (node.children.length == 1) {
        return _buildFragment(node.children.first);
      }

      final fragments = node.children.map(_buildFragment).toList();
      final allStates = <String, StateNode>{};
      final allTransitions = <Transition>[];

      for (int i = 0; i < fragments.length; i++) {
        allStates.addAll(fragments[i].states);
        allTransitions.addAll(fragments[i].transitions);

        if (i < fragments.length - 1) {
          // Connect accept of curr to start of next with epsilon
          allTransitions.add(
            _createTransition(
              fragments[i].acceptId,
              fragments[i + 1].startId,
              Transition.epsilon,
            ),
          );
        }
      }

      return _Fragment(
        startId: fragments.first.startId,
        acceptId: fragments.last.acceptId,
        states: allStates,
        transitions: allTransitions,
      );
    }

    if (node is RegexUnion) {
      if (node.children.isEmpty) {
        return _buildFragment(const RegexEmpty());
      }
      if (node.children.length == 1) {
        return _buildFragment(node.children.first);
      }

      final fragments = node.children.map(_buildFragment).toList();
      final s = _nextStateId();
      final a = _nextStateId();
      final allStates = <String, StateNode>{
        s: _createState(s),
        a: _createState(a),
      };
      final allTransitions = <Transition>[];

      for (final f in fragments) {
        allStates.addAll(f.states);
        allTransitions.addAll(f.transitions);
        // s -> f.start
        allTransitions.add(_createTransition(s, f.startId, Transition.epsilon));
        // f.accept -> a
        allTransitions.add(_createTransition(f.acceptId, a, Transition.epsilon));
      }

      return _Fragment(
        startId: s,
        acceptId: a,
        states: allStates,
        transitions: allTransitions,
      );
    }

    if (node is RegexStar) {
      final inner = _buildFragment(node.child);
      final s = _nextStateId();
      final a = _nextStateId();
      final allStates = <String, StateNode>{
        ...inner.states,
        s: _createState(s),
        a: _createState(a),
      };
      final allTransitions = <Transition>[
        ...inner.transitions,
        _createTransition(s, inner.startId, Transition.epsilon),
        _createTransition(s, a, Transition.epsilon), // 0 occurrences
        _createTransition(inner.acceptId, inner.startId, Transition.epsilon), // loop back
        _createTransition(inner.acceptId, a, Transition.epsilon),
      ];

      return _Fragment(
        startId: s,
        acceptId: a,
        states: allStates,
        transitions: allTransitions,
      );
    }

    if (node is RegexPlus) {
      final inner = _buildFragment(node.child);
      final s = _nextStateId();
      final a = _nextStateId();
      final allStates = <String, StateNode>{
        ...inner.states,
        s: _createState(s),
        a: _createState(a),
      };
      final allTransitions = <Transition>[
        ...inner.transitions,
        _createTransition(s, inner.startId, Transition.epsilon),
        _createTransition(inner.acceptId, inner.startId, Transition.epsilon),
        _createTransition(inner.acceptId, a, Transition.epsilon),
      ];

      return _Fragment(
        startId: s,
        acceptId: a,
        states: allStates,
        transitions: allTransitions,
      );
    }

    if (node is RegexOptional) {
      final inner = _buildFragment(node.child);
      final s = _nextStateId();
      final a = _nextStateId();
      final allStates = <String, StateNode>{
        ...inner.states,
        s: _createState(s),
        a: _createState(a),
      };
      final allTransitions = <Transition>[
        ...inner.transitions,
        _createTransition(s, inner.startId, Transition.epsilon),
        _createTransition(s, a, Transition.epsilon),
        _createTransition(inner.acceptId, a, Transition.epsilon),
      ];

      return _Fragment(
        startId: s,
        acceptId: a,
        states: allStates,
        transitions: allTransitions,
      );
    }

    throw UnsupportedError('Unsupported RegexNode type: ${node.runtimeType}');
  }

  List<String> _orderStateIds(_Fragment fragment) {
    final ordered = <String>[];
    final visited = <String>{};
    final queue = <String>[fragment.startId];

    visited.add(fragment.startId);

    // Adjacency list
    final adj = <String, List<String>>{};
    for (final t in fragment.transitions) {
      adj.putIfAbsent(t.fromId, () => []).add(t.toId);
    }

    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      ordered.add(curr);

      final nextStates = adj[curr] ?? [];
      for (final next in nextStates) {
        if (!visited.contains(next)) {
          visited.add(next);
          queue.add(next);
        }
      }
    }

    // Add any remaining disconnected states (if any)
    for (final id in fragment.states.keys) {
      if (!visited.contains(id)) {
        visited.add(id);
        ordered.add(id);
      }
    }

    return ordered;
  }
}
