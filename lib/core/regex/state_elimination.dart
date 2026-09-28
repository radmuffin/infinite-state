import '../models/automaton.dart';
import '../models/transition.dart';
import 'regex_ast.dart';

/// Implements the State Elimination Algorithm (Generalized NFA reduction)
/// to convert any [Automaton] (DFA, NFA, or ε-NFA) into an equivalent [RegexNode].
class StateElimination {
  /// Converts [automaton] into a simplified [RegexNode].
  static RegexNode toRegex(Automaton automaton) {
    final eliminator = StateElimination();
    return eliminator.convert(automaton);
  }

  RegexNode convert(Automaton automaton) {
    if (automaton.states.isEmpty) {
      return const RegexEmpty();
    }

    final initial = automaton.initialState;
    if (initial == null) {
      return const RegexEmpty();
    }

    final acceptIds = automaton.acceptStateIds;
    if (acceptIds.isEmpty) {
      return const RegexEmpty();
    }

    // GNFA special start and accept states
    const startId = '__gnfa_start__';
    const acceptId = '__gnfa_accept__';

    // Adjacency matrix of regex expressions: edges[u][v]
    final edges = <String, Map<String, RegexNode>>{};

    void setEdge(String from, String to, RegexNode node) {
      edges.putIfAbsent(from, () => {})[to] = node;
    }

    RegexNode? getEdge(String from, String to) {
      return edges[from]?[to];
    }

    void removeEdge(String from, String to) {
      edges[from]?.remove(to);
    }

    // 1. Initialise transitions between original states in automaton
    for (final state in automaton.states.values) {
      for (final t in automaton.transitionsFrom(state.id)) {
        if (!automaton.states.containsKey(t.toId)) continue;

        final symbolNodes = <RegexNode>[];
        for (final sym in t.symbols) {
          if (sym == Transition.epsilon) {
            symbolNodes.add(const RegexEpsilon());
          } else {
            symbolNodes.add(RegexLiteral(sym));
          }
        }

        if (symbolNodes.isEmpty) continue;

        final newBranch = symbolNodes.length == 1
            ? symbolNodes.first
            : RegexUnion(symbolNodes).simplify();

        final existing = getEdge(t.fromId, t.toId);
        if (existing == null) {
          setEdge(t.fromId, t.toId, newBranch);
        } else {
          setEdge(
            t.fromId,
            t.toId,
            RegexUnion([existing, newBranch]).simplify(),
          );
        }
      }
    }

    // 2. Add __gnfa_start__ with ε-transition to initial state
    setEdge(startId, initial.id, const RegexEpsilon());

    // 3. Add ε-transitions from all accept states to __gnfa_accept__
    for (final accId in acceptIds) {
      final existing = getEdge(accId, acceptId);
      if (existing == null) {
        setEdge(accId, acceptId, const RegexEpsilon());
      } else {
        setEdge(
          accId,
          acceptId,
          RegexUnion([existing, const RegexEpsilon()]).simplify(),
        );
      }
    }

    // 4. Eliminate intermediate states one by one
    final intermediateStates = Set<String>.from(automaton.states.keys);

    while (intermediateStates.isNotEmpty) {
      // Pick state with smallest in_degree * out_degree heuristic
      String bestState = intermediateStates.first;
      int bestWeight = 999999999;

      for (final k in intermediateStates) {
        int inDegree = 0;
        int outDegree = 0;

        for (final u in edges.keys) {
          if (u != k && edges[u]?.containsKey(k) == true) inDegree++;
        }
        final outMap = edges[k];
        if (outMap != null) {
          for (final v in outMap.keys) {
            if (v != k) outDegree++;
          }
        }

        final weight = inDegree * outDegree;
        if (weight < bestWeight) {
          bestWeight = weight;
          bestState = k;
        }
      }

      final k = bestState;
      intermediateStates.remove(k);

      // Self loop on state k: R(k, k)*
      final selfLoop = getEdge(k, k);
      final RegexNode rStar;
      if (selfLoop == null || selfLoop is RegexEmpty) {
        rStar = const RegexEpsilon();
      } else {
        rStar = RegexStar(selfLoop).simplify();
      }

      // Predecessors of k: all i != k with edge i -> k
      final predecessors = <String>[];
      for (final u in edges.keys) {
        if (u != k && edges[u]?.containsKey(k) == true) {
          predecessors.add(u);
        }
      }

      // Successors of k: all j != k with edge k -> j
      final successors = <String>[];
      final outMap = edges[k];
      if (outMap != null) {
        for (final v in outMap.keys) {
          if (v != k) {
            successors.add(v);
          }
        }
      }

      // Bypass k for every predecessor i and successor j
      for (final i in predecessors) {
        final rIn = getEdge(i, k)!;
        for (final j in successors) {
          final rOut = getEdge(k, j)!;

          // R_path = R(i, k) · R(k, k)* · R(k, j)
          final rPath = RegexConcat([rIn, rStar, rOut]).simplify();
          if (rPath is RegexEmpty) continue;

          final rExisting = getEdge(i, j);
          if (rExisting == null) {
            setEdge(i, j, rPath);
          } else {
            setEdge(i, j, RegexUnion([rExisting, rPath]).simplify());
          }
        }
      }

      // Remove state k from graph
      edges.remove(k);
      for (final u in edges.keys) {
        removeEdge(u, k);
      }
    }

    // 5. Final result is the edge between startId and acceptId
    final finalResult = getEdge(startId, acceptId);
    if (finalResult == null) {
      return const RegexEmpty();
    }

    return finalResult.simplify();
  }
}
