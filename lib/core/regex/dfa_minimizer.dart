import 'dart:collection';
import 'dart:ui';
import '../layout/sugiyama_layout.dart';
import '../models/automaton.dart';
import '../models/state_node.dart';
import '../models/transition.dart';

/// Converts an arbitrary [Automaton] (including ε-NFAs) into an equivalent
/// Minimal Deterministic Finite Automaton (Minimal DFA) using:
/// 1. Subset Construction (Powerset construction with ε-closure)
/// 2. Hopcroft's Partition-Refinement Minimization Algorithm
/// 3. Dead state pruning & hierarchical flow layout.
class DfaMinimizer {
  /// Transforms [automaton] into an equivalent minimal DFA.
  static Automaton minimize(
    Automaton automaton, {
    Size canvasSize = const Size(1200, 800),
    bool applyLayout = true,
  }) {
    if (automaton.states.isEmpty) {
      return Automaton(states: {}, transitions: []);
    }

    final initial = automaton.initialState;
    if (initial == null) {
      return automaton;
    }

    // Step 1: Subset Construction (NFA / ε-NFA -> DFA)
    final dfa = _subsetConstruction(automaton);

    // Step 2: Hopcroft's Minimization (DFA -> Minimal DFA)
    final minimalDfa = _hopcroftMinimization(dfa);

    // Step 3: Prune dead / trap states that cannot reach any accept state
    final cleaned = _pruneDeadStates(minimalDfa);

    // Step 4: Re-index states in BFS flow order (q0, q1, ...)
    final reindexed = _reindexStates(cleaned);

    // Step 5: Apply hierarchical visual layout
    if (applyLayout) {
      const layout = SugiyamaLayout(layerSpacing: 200.0, nodeSpacing: 120.0);
      final positions = layout.calculateLayout(reindexed, canvasSize: canvasSize);
      final positionedStates = <String, StateNode>{};
      for (final s in reindexed.states.values) {
        positionedStates[s.id] = s.copyWith(
          position: positions[s.id] ?? s.position,
        );
      }
      return Automaton(
        states: positionedStates,
        transitions: reindexed.transitions,
      );
    }

    return reindexed;
  }

  /// Converts an NFA / ε-NFA to a DFA via subset construction.
  static _IntermediateDfa _subsetConstruction(Automaton nfa) {
    final alphabet = nfa.alphabet.toList()..sort();
    final initialNfa = nfa.initialState!;
    final acceptNfaIds = nfa.acceptStateIds;

    final initialClosure = nfa.epsilonClosure({initialNfa.id});

    String keyOf(Set<String> set) {
      final list = set.toList()..sort();
      return list.join(',');
    }

    final subsetToId = <String, int>{};
    final subsets = <Set<String>>[];
    final queue = Queue<Set<String>>();

    final initialKey = keyOf(initialClosure);
    subsetToId[initialKey] = 0;
    subsets.add(initialClosure);
    queue.add(initialClosure);

    final transitions = <int, Map<String, int>>{};
    final acceptStates = <int>{};

    if (initialClosure.any(acceptNfaIds.contains)) {
      acceptStates.add(0);
    }

    while (queue.isNotEmpty) {
      final currentSubset = queue.removeFirst();
      final currentId = subsetToId[keyOf(currentSubset)]!;
      transitions.putIfAbsent(currentId, () => {});

      for (final symbol in alphabet) {
        // Collect targets across all states in current subset on reading symbol
        final directTargets = <String>{};
        for (final stateId in currentSubset) {
          directTargets.addAll(nfa.getTargets(stateId, symbol));
        }

        if (directTargets.isEmpty) {
          continue; // No transition on this symbol (partial DFA)
        }

        final targetClosure = nfa.epsilonClosure(directTargets);
        if (targetClosure.isEmpty) continue;

        final targetKey = keyOf(targetClosure);
        int targetId;
        if (!subsetToId.containsKey(targetKey)) {
          targetId = subsets.length;
          subsetToId[targetKey] = targetId;
          subsets.add(targetClosure);
          queue.add(targetClosure);

          if (targetClosure.any(acceptNfaIds.contains)) {
            acceptStates.add(targetId);
          }
        } else {
          targetId = subsetToId[targetKey]!;
        }

        transitions[currentId]![symbol] = targetId;
      }
    }

    return _IntermediateDfa(
      numStates: subsets.length,
      initialState: 0,
      acceptStates: acceptStates,
      alphabet: alphabet,
      transitions: transitions,
    );
  }

  /// Minimizes a DFA using Hopcroft's partition-refinement algorithm.
  static _IntermediateDfa _hopcroftMinimization(_IntermediateDfa dfa) {
    if (dfa.numStates <= 1) return dfa;

    final alphabet = dfa.alphabet;
    final totalStates = dfa.numStates;

    // For complete Hopcroft, introduce an implicit sink state index if transitions are partial
    final sinkState = totalStates;
    var hasMissingTransitions = false;

    for (int s = 0; s < totalStates; s++) {
      for (final sym in alphabet) {
        if (dfa.transitions[s]?[sym] == null) {
          hasMissingTransitions = true;
          break;
        }
      }
      if (hasMissingTransitions) break;
    }

    final totalWithSink = hasMissingTransitions ? totalStates + 1 : totalStates;

    // Transition lookup function for complete DFA
    int delta(int state, String symbol) {
      if (state == sinkState) return sinkState;
      final target = dfa.transitions[state]?[symbol];
      return target ?? sinkState;
    }

    // Step 2a: Initialize partitions P = { F, Q \ F }
    final fSet = Set<int>.from(dfa.acceptStates);
    final nonFSet = <int>{};
    for (int i = 0; i < totalWithSink; i++) {
      if (!fSet.contains(i)) {
        nonFSet.add(i);
      }
    }

    final partitions = <Set<int>>[];
    if (fSet.isNotEmpty) partitions.add(fSet);
    if (nonFSet.isNotEmpty) partitions.add(nonFSet);

    // Worklist W: start with the smaller partition
    final worklist = <Set<int>>[];
    if (fSet.isNotEmpty && (nonFSet.isEmpty || fSet.length <= nonFSet.length)) {
      worklist.add(Set<int>.from(fSet));
    } else if (nonFSet.isNotEmpty) {
      worklist.add(Set<int>.from(nonFSet));
    }

    while (worklist.isNotEmpty) {
      final a = worklist.removeLast();

      for (final c in alphabet) {
        // Compute preimage X: states that lead into set A on symbol c
        final x = <int>{};
        for (int state = 0; state < totalWithSink; state++) {
          if (a.contains(delta(state, c))) {
            x.add(state);
          }
        }

        if (x.isEmpty) continue;

        // Check each set Y in partitions
        final newPartitions = <Set<int>>[];
        for (final y in partitions) {
          final intersection = y.intersection(x);
          final difference = y.difference(x);

          if (intersection.isNotEmpty && difference.isNotEmpty) {
            newPartitions.add(intersection);
            newPartitions.add(difference);

            // Update worklist
            final inWorklist = worklist.indexWhere(
              (w) => w.length == y.length && w.containsAll(y),
            );
            if (inWorklist != -1) {
              worklist.removeAt(inWorklist);
              worklist.add(intersection);
              worklist.add(difference);
            } else {
              if (intersection.length <= difference.length) {
                worklist.add(intersection);
              } else {
                worklist.add(difference);
              }
            }
          } else {
            newPartitions.add(y);
          }
        }
        partitions
          ..clear()
          ..addAll(newPartitions);
      }
    }

    // Step 2b: Build minimized DFA from partition blocks
    // Ensure the block containing initialState is index 0
    final stateToBlock = <int, int>{};
    final blocks = <Set<int>>[];

    // Find block containing initial state
    final initialBlock = partitions.firstWhere(
      (b) => b.contains(dfa.initialState),
      orElse: () => partitions.first,
    );
    blocks.add(initialBlock);

    for (final b in partitions) {
      if (b != initialBlock) {
        blocks.add(b);
      }
    }

    for (int bIdx = 0; bIdx < blocks.length; bIdx++) {
      for (final s in blocks[bIdx]) {
        stateToBlock[s] = bIdx;
      }
    }

    final newAccept = <int>{};
    final newTransitions = <int, Map<String, int>>{};

    final sinkBlockIdx = hasMissingTransitions ? stateToBlock[sinkState] : null;

    for (int bIdx = 0; bIdx < blocks.length; bIdx++) {
      final block = blocks[bIdx];
      // If block is the pure sink block and not initial, we don't need transitions from it
      if (bIdx == sinkBlockIdx && bIdx != 0) continue;

      final rep = block.first;
      if (dfa.acceptStates.contains(rep)) {
        newAccept.add(bIdx);
      }

      newTransitions[bIdx] = {};
      for (final c in alphabet) {
        final tgt = delta(rep, c);
        final tgtBlock = stateToBlock[tgt]!;
        // Omit transitions to the sink block to keep diagram partial and concise
        if (tgtBlock != sinkBlockIdx) {
          newTransitions[bIdx]![c] = tgtBlock;
        }
      }
    }

    return _IntermediateDfa(
      numStates: blocks.length,
      initialState: 0,
      acceptStates: newAccept,
      alphabet: alphabet,
      transitions: newTransitions,
      sinkBlockIdx: sinkBlockIdx,
    );
  }

  /// Prunes unreachable states and dead/sink states that cannot reach any accept state.
  static Automaton _pruneDeadStates(_IntermediateDfa dfa) {
    final reachableFromStart = <int>{};
    final q = Queue<int>()..add(dfa.initialState);
    reachableFromStart.add(dfa.initialState);

    while (q.isNotEmpty) {
      final curr = q.removeFirst();
      final trans = dfa.transitions[curr] ?? {};
      for (final to in trans.values) {
        if (reachableFromStart.add(to)) {
          q.add(to);
        }
      }
    }

    // Identify states that can reach at least one accept state (reverse reachability)
    final canReachAccept = Set<int>.from(dfa.acceptStates);
    final reverseAdj = <int, Set<int>>{};
    for (final entry in dfa.transitions.entries) {
      final from = entry.key;
      for (final to in entry.value.values) {
        reverseAdj.putIfAbsent(to, () => {}).add(from);
      }
    }

    final revQ = Queue<int>()..addAll(dfa.acceptStates);
    while (revQ.isNotEmpty) {
      final curr = revQ.removeFirst();
      for (final from in reverseAdj[curr] ?? const <int>{}) {
        if (canReachAccept.add(from)) {
          revQ.add(from);
        }
      }
    }

    // Keep state if it's reachable from start AND can reach accept,
    // OR if it's the start state itself (e.g. for empty language or unfulfillable regex)
    final liveStates = <int>{};
    for (final s in reachableFromStart) {
      if (canReachAccept.contains(s) || s == dfa.initialState) {
        // Also don't include the explicit sink block
        if (s != dfa.sinkBlockIdx) {
          liveStates.add(s);
        }
      }
    }

    if (liveStates.isEmpty) {
      liveStates.add(dfa.initialState);
    }

    // Build intermediate Automaton
    final stateNodes = <String, StateNode>{};
    for (final s in liveStates) {
      final id = 's$s';
      stateNodes[id] = StateNode(
        id: id,
        label: id,
        position: Offset.zero,
        isInitial: s == dfa.initialState,
        isAccept: dfa.acceptStates.contains(s),
      );
    }

    // Collect transitions between live states
    final transitionMap = <String, Set<String>>{};
    for (final from in liveStates) {
      final trans = dfa.transitions[from] ?? {};
      for (final entry in trans.entries) {
        final symbol = entry.key;
        final to = entry.value;
        if (liveStates.contains(to)) {
          final key = 's$from->s$to';
          transitionMap.putIfAbsent(key, () => {}).add(symbol);
        }
      }
    }

    final transitionsList = <Transition>[];
    int tIdx = 0;
    for (final entry in transitionMap.entries) {
      final parts = entry.key.split('->');
      transitionsList.add(
        Transition(
          id: 't_$tIdx',
          fromId: parts[0],
          toId: parts[1],
          symbols: entry.value,
        ),
      );
      tIdx++;
    }

    return Automaton(
      states: stateNodes,
      transitions: transitionsList,
    );
  }

  /// Re-indexes state labels to clean textbook notation (q0, q1, q2...)
  /// using BFS order originating from the initial state.
  static Automaton _reindexStates(Automaton automaton) {
    if (automaton.states.isEmpty) return automaton;

    final initial = automaton.initialState ?? automaton.states.values.first;
    final ordered = <String>[];
    final visited = <String>{initial.id};
    final q = Queue<String>()..add(initial.id);

    while (q.isNotEmpty) {
      final curr = q.removeFirst();
      ordered.add(curr);

      // Sort outgoing transitions for deterministic ordering
      final outgoing = automaton.transitionsFrom(curr)
        ..sort((a, b) => a.symbols.join(',').compareTo(b.symbols.join(',')));

      for (final t in outgoing) {
        if (visited.add(t.toId)) {
          q.add(t.toId);
        }
      }
    }

    // Include any disconnected states
    for (final id in automaton.states.keys) {
      if (!visited.contains(id)) {
        ordered.add(id);
      }
    }

    final idMap = <String, String>{};
    for (int i = 0; i < ordered.length; i++) {
      idMap[ordered[i]] = 'q$i';
    }

    final newStates = <String, StateNode>{};
    for (final oldId in ordered) {
      final newId = idMap[oldId]!;
      final oldNode = automaton.states[oldId]!;
      newStates[newId] = oldNode.copyWith(
        id: newId,
        label: newId,
      );
    }

    final newTransitions = <Transition>[];
    for (int i = 0; i < automaton.transitions.length; i++) {
      final oldT = automaton.transitions[i];
      final newFrom = idMap[oldT.fromId];
      final newTo = idMap[oldT.toId];
      if (newFrom != null && newTo != null) {
        newTransitions.add(
          Transition(
            id: 't_$i',
            fromId: newFrom,
            toId: newTo,
            symbols: oldT.symbols,
          ),
        );
      }
    }

    return Automaton(
      states: newStates,
      transitions: newTransitions,
    );
  }
}

class _IntermediateDfa {
  final int numStates;
  final int initialState;
  final Set<int> acceptStates;
  final List<String> alphabet;
  final Map<int, Map<String, int>> transitions;
  final int? sinkBlockIdx;

  _IntermediateDfa({
    required this.numStates,
    required this.initialState,
    required this.acceptStates,
    required this.alphabet,
    required this.transitions,
    this.sinkBlockIdx,
  });
}
