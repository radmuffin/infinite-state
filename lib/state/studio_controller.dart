import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../core/engine/automata_simulator.dart';
import '../core/layout/force_directed_layout.dart';
import '../core/layout/sugiyama_layout.dart';
import '../core/models/automaton.dart';
import '../core/models/state_node.dart';
import '../core/models/transition.dart';
import '../core/presets/example_automata.dart';
import '../core/regex/regex_parser.dart';
import '../core/regex/regex_service.dart';
import '../core/storage/machine_storage.dart';

class BatchTestResult {
  final String input;
  final bool expected;
  final bool actual;
  final bool passed;

  BatchTestResult({
    required this.input,
    required this.expected,
    required this.actual,
  }) : passed = expected == actual;
}

enum SidebarTab {
  none,
  inspector,
  regex,
  batchTests,
  library,
}

class StudioController extends ChangeNotifier {
  String _machineName = 'Binary Divisible by 3';
  String? _currentMachineId;
  Automaton _automaton = ExampleAutomata.binaryDivisibleBy3.automaton;
  String _inputTape = ExampleAutomata.binaryDivisibleBy3.defaultInput;

  // Regex Synchronization State
  String _regexPattern = '';
  bool _regexAutoSync = true;
  String? _regexError;
  bool _isGraphOutOfSyncWithRegex = false;
  bool _isSyncing = false;

  // Explicit alphabet symbols added by user (in addition to transitions)
  final Set<String> _explicitAlphabet = {'0', '1'};

  String? _selectedStateId;
  String? _selectedTransitionId;

  // Active right sidebar tab & Live mode
  SidebarTab _activeSidebarTab = SidebarTab.inspector;
  bool _liveMode = false;

  // Quick connect wire drag
  String? _wireSourceStateId;
  Offset? _wireCurrentPosition;

  // Active / last created transition for direct keyboard input
  String? _lastActiveTransitionId;
  bool _isAwaitingCommaAppend = false;
  bool _transitionTypingActive = false;

  AutomataSimulator? _simulator;
  Timer? _playbackTimer;
  bool _isPlaying = false;
  final Duration _playbackSpeed = const Duration(milliseconds: 650);
  int _centerViewTrigger = 0;

  // Undo stack
  final List<Automaton> _undoStack = [];

  StudioController({Automaton? initialAutomaton, String? machineName}) {
    if (initialAutomaton != null) {
      _automaton = initialAutomaton;
      _explicitAlphabet.addAll(initialAutomaton.alphabet);
    }
    if (machineName != null) {
      _machineName = machineName;
    }
    _initSimulator();
    _syncGraphToRegexInternal();
  }

  // --- Getters ---
  String get machineName => _machineName;
  String? get currentMachineId => _currentMachineId;
  Automaton get automaton => _automaton;
  String get inputTape => _inputTape;
  String? get selectedStateId => _selectedStateId;
  String? get selectedTransitionId => _selectedTransitionId;
  String? get activeTransitionId => _selectedTransitionId ?? _lastActiveTransitionId;
  bool get hasActiveOrSelectedTransition {
    final targetId = activeTransitionId;
    if (targetId == null) return false;
    return _automaton.transitions.any((t) => t.id == targetId);
  }
  bool get isAwaitingCommaAppend => _isAwaitingCommaAppend;
  bool get transitionTypingActive => _transitionTypingActive;
  bool get canBackspaceTransitionSymbol {
    if (!_transitionTypingActive) return false;
    final targetId = activeTransitionId;
    if (targetId == null) return false;
    final transition = _automaton.transitions.firstWhere(
      (t) => t.id == targetId,
      orElse: () => Transition(id: '', fromId: '', toId: '', symbols: {}),
    );
    return transition.symbols.length > 1;
  }
  String? get wireSourceStateId => _wireSourceStateId;
  Offset? get wireCurrentPosition => _wireCurrentPosition;
  AutomataSimulator? get simulator => _simulator;
  bool get isPlaying => _isPlaying;
  Duration get playbackSpeed => _playbackSpeed;
  int get centerViewTrigger => _centerViewTrigger;
  SidebarTab get activeSidebarTab => _activeSidebarTab;
  bool get liveMode => _liveMode;

  void setSidebarTab(SidebarTab tab) {
    _activeSidebarTab = tab;
    notifyListeners();
  }

  void toggleSidebarTab(SidebarTab tab) {
    if (_activeSidebarTab == tab) {
      _activeSidebarTab = SidebarTab.none;
    } else {
      _activeSidebarTab = tab;
    }
    notifyListeners();
  }

  void toggleLiveMode() {
    _liveMode = !_liveMode;
    if (_liveMode && _simulator != null) {
      _simulator!.runToEnd();
    }
    notifyListeners();
  }

  void setLiveMode(bool enabled) {
    if (_liveMode != enabled) {
      _liveMode = enabled;
      if (_liveMode && _simulator != null) {
        _simulator!.runToEnd();
      }
      notifyListeners();
    }
  }

  // --- Regex Synchronization Getters ---
  String get regexPattern => _regexPattern;
  bool get regexAutoSync => _regexAutoSync;
  String? get regexError => _regexError;
  bool get isGraphOutOfSyncWithRegex => _isGraphOutOfSyncWithRegex;

  /// Combined alphabet from transitions plus any explicitly added symbols.
  Set<String> get fullAlphabet {
    final set = Set<String>.from(_automaton.alphabet)..addAll(_explicitAlphabet);
    return set;
  }

  StateNode? get selectedState =>
      _selectedStateId != null ? _automaton.states[_selectedStateId] : null;

  Transition? get selectedTransition {
    if (_selectedTransitionId == null) return null;
    try {
      return _automaton.transitions
          .firstWhere((t) => t.id == _selectedTransitionId);
    } catch (_) {
      return null;
    }
  }

  Set<String> get activeStateIds =>
      _simulator?.currentStep.activeStateIds ?? {};

  Set<String> get activeTransitionIds =>
      _simulator?.currentStep.traversedTransitionIds ?? {};

  // --- Title & Persistence ---

  void setMachineName(String name) {
    _machineName = name.trim().isEmpty ? 'Untitled Machine' : name.trim();
    notifyListeners();
  }

  void saveCurrentMachine([String? name]) {
    if (name != null && name.trim().isNotEmpty) {
      _machineName = name.trim();
    }
    final id = _currentMachineId ?? 'm_${DateTime.now().millisecondsSinceEpoch}';
    _currentMachineId = id;

    final saved = SavedMachine(
      id: id,
      name: _machineName,
      updatedAt: DateTime.now(),
      automaton: _automaton,
      defaultInput: _inputTape,
    );

    MachineStorage.saveMachine(saved);
    notifyListeners();
  }

  void loadSavedMachine(SavedMachine machine) {
    _recordHistory();
    stopPlayback();
    _currentMachineId = machine.id;
    _machineName = machine.name;
    _automaton = machine.automaton;
    _inputTape = machine.defaultInput;
    _selectedStateId = null;
    _selectedTransitionId = null;
    _wireSourceStateId = null;
    _centerViewTrigger++;
    _initSimulator();
    _syncGraphToRegexInternal();
    notifyListeners();
  }

  void deleteSavedMachine(String id) {
    MachineStorage.deleteMachine(id);
    if (_currentMachineId == id) {
      _currentMachineId = null;
    }
    notifyListeners();
  }

  List<SavedMachine> listSavedMachines() => MachineStorage.loadAll();

  // --- State Manipulation & History ---

  void _recordHistory() {
    _undoStack.add(_automaton);
    if (_undoStack.length > 30) {
      _undoStack.removeAt(0);
    }
  }

  void undo() {
    if (_undoStack.isNotEmpty) {
      _automaton = _undoStack.removeLast();
      _selectedStateId = null;
      _selectedTransitionId = null;
      _wireSourceStateId = null;
      _lastActiveTransitionId = null;
      _isAwaitingCommaAppend = false;
      _transitionTypingActive = false;
      _initSimulator();
      _syncGraphToRegexInternal();
      notifyListeners();
    }
  }

  void selectState(String? id) {
    _selectedStateId = id;
    _selectedTransitionId = null;
    _lastActiveTransitionId = null;
    _isAwaitingCommaAppend = false;
    _transitionTypingActive = false;
    notifyListeners();
  }

  void selectTransition(String? id) {
    _selectedTransitionId = id;
    _selectedStateId = null;
    _lastActiveTransitionId = id;
    _isAwaitingCommaAppend = false;
    _transitionTypingActive = false;
    notifyListeners();
  }

  void triggerCenterView() {
    _centerViewTrigger++;
    notifyListeners();
  }

  void addStateAt(Offset position) {
    _recordHistory();
    final count = _automaton.states.length;
    String id = 'q$count';
    int suffix = count;
    while (_automaton.states.containsKey(id)) {
      id = 'q${++suffix}';
    }

    final isFirst = _automaton.states.isEmpty;
    final node = StateNode(
      id: id,
      label: id,
      position: position,
      isInitial: isFirst,
      isAccept: false,
    );

    _automaton = _automaton.setNode(node);
    _selectedStateId = node.id;
    _initSimulator();
    notifyListeners();
  }

  void updateStatePosition(String id, Offset newPosition) {
    final state = _automaton.states[id];
    if (state != null) {
      _automaton = _automaton.setNode(state.copyWith(position: newPosition));
      notifyListeners();
    }
  }

  void updateStateProperties({
    required String id,
    String? label,
    bool? isInitial,
    bool? isAccept,
  }) {
    final state = _automaton.states[id];
    if (state != null) {
      _recordHistory();
      _automaton = _automaton.setNode(state.copyWith(
        label: label,
        isInitial: isInitial,
        isAccept: isAccept,
      ));
      _initSimulator();
      notifyListeners();
    }
  }

  void quickToggleInitial(String stateId) {
    final state = _automaton.states[stateId];
    if (state != null) {
      updateStateProperties(id: stateId, isInitial: !state.isInitial);
    }
  }

  void quickToggleAccept(String stateId) {
    final state = _automaton.states[stateId];
    if (state != null) {
      updateStateProperties(id: stateId, isAccept: !state.isAccept);
    }
  }

  void deleteSelected() {
    _recordHistory();
    _transitionTypingActive = false;
    _isAwaitingCommaAppend = false;
    if (_selectedStateId != null) {
      _automaton = _automaton.removeNode(_selectedStateId!);
      _selectedStateId = null;
    } else if (_selectedTransitionId != null) {
      _automaton = _automaton.removeTransition(_selectedTransitionId!);
      _selectedTransitionId = null;
    }
    _initSimulator();
    notifyListeners();
  }

  void deleteState(String stateId) {
    _recordHistory();
    _automaton = _automaton.removeNode(stateId);
    if (_selectedStateId == stateId) _selectedStateId = null;
    _initSimulator();
    notifyListeners();
  }

  // --- Wire Drag & Transitions ---

  void startWireDrag(String fromStateId, Offset position) {
    _wireSourceStateId = fromStateId;
    _wireCurrentPosition = position;
    notifyListeners();
  }

  void updateWireDrag(Offset position) {
    _wireCurrentPosition = position;
    notifyListeners();
  }

  void endWireDrag(String? targetStateId) {
    if (_wireSourceStateId != null && targetStateId != null) {
      connectStates(_wireSourceStateId!, targetStateId);
    }
    _wireSourceStateId = null;
    _wireCurrentPosition = null;
    notifyListeners();
  }

  String _generateTransitionId() {
    var id = 't_${DateTime.now().microsecondsSinceEpoch}_${_automaton.transitions.length}';
    int suffix = 0;
    while (_automaton.transitions.any((t) => t.id == id)) {
      id = 't_${DateTime.now().microsecondsSinceEpoch}_${++suffix}';
    }
    return id;
  }

  void connectStates(String fromId, String toId, {String defaultSymbol = '0'}) {
    _recordHistory();
    final existing = _automaton.transitionsBetween(fromId, toId);
    if (existing.isNotEmpty) {
      _selectedTransitionId = existing.first.id;
      _lastActiveTransitionId = existing.first.id;
    } else {
      final newId = _generateTransitionId();
      final newTransition = Transition(
        id: newId,
        fromId: fromId,
        toId: toId,
        symbols: {defaultSymbol},
      );
      _automaton = _automaton.setTransition(newTransition);
      _selectedTransitionId = newId;
      _lastActiveTransitionId = newId;
    }
    _isAwaitingCommaAppend = false;
    _transitionTypingActive = false;
    _initSimulator();
    notifyListeners();
  }

  /// Automatically creates a new state and connects [fromStateId] to it.
  /// If [position] is omitted, an optimal non-overlapping position to the right is calculated.
  /// If [symbol] is omitted, the next unused symbol from the alphabet is selected.
  StateNode? autoAddConnectedNode(String fromStateId, {Offset? position, String? symbol}) {
    final fromState = _automaton.states[fromStateId];
    if (fromState == null) return null;

    _recordHistory();
    final targetPosition =
        position ?? calculateNextNodePosition(fromState.position);

    final count = _automaton.states.length;
    String id = 'q$count';
    int suffix = count;
    while (_automaton.states.containsKey(id)) {
      id = 'q${++suffix}';
    }

    final isFirst = _automaton.states.isEmpty;
    final newNode = StateNode(
      id: id,
      label: id,
      position: targetPosition,
      isInitial: isFirst,
      isAccept: false,
    );

    _automaton = _automaton.setNode(newNode);

    final transitionSymbol = symbol ?? _chooseDefaultSymbol(fromStateId);
    final newId = _generateTransitionId();
    final newTransition = Transition(
      id: newId,
      fromId: fromStateId,
      toId: newNode.id,
      symbols: {transitionSymbol},
    );
    _automaton = _automaton.setTransition(newTransition);

    _selectedStateId = newNode.id;
    _selectedTransitionId = null;
    _lastActiveTransitionId = newId;
    _isAwaitingCommaAppend = false;
    _transitionTypingActive = false;

    _initSimulator();
    notifyListeners();
    return newNode;
  }

  /// Direct keyboard entry of connector symbol(s) without needing to click any text field.
  /// Supports typing sequential characters directly (e.g. typing 'a' then 'b' yields "a, b"),
  /// multi-character strings (e.g. "ab" yields "a, b"), or comma/space separated inputs ("a, b").
  void typeTransitionSymbol(String input) {
    if (input.isEmpty) return;
    final targetId = activeTransitionId;
    if (targetId == null) return;

    final transition = _automaton.transitions.firstWhere(
      (t) => t.id == targetId,
      orElse: () => Transition(id: '', fromId: '', toId: '', symbols: {}),
    );
    if (transition.id.isEmpty) return;

    _recordHistory();

    if (input == ',') {
      _isAwaitingCommaAppend = true;
      _transitionTypingActive = true;
      notifyListeners();
      return;
    }

    final currentSymbols = Set<String>.from(
      _transitionTypingActive ? transition.symbols : <String>{},
    );

    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      if (ch == ',' || ch == ' ') {
        _isAwaitingCommaAppend = true;
        continue;
      }
      currentSymbols.add(ch);
      _explicitAlphabet.add(ch);
      _isAwaitingCommaAppend = false;
    }

    if (currentSymbols.isNotEmpty) {
      _transitionTypingActive = true;
      _automaton = _automaton.setTransition(transition.copyWith(symbols: currentSymbols));
      _initSimulator();
      notifyListeners();
    }
  }

  /// Concludes active direct keyboard symbol entry for the current connector.
  void finishTransitionTyping() {
    _transitionTypingActive = false;
    _isAwaitingCommaAppend = false;
    notifyListeners();
  }

  /// Removes the most recently added symbol from the active transition during keyboard typing.
  void backspaceTransitionSymbol() {
    final targetId = activeTransitionId;
    if (targetId == null) return;
    final transition = _automaton.transitions.firstWhere(
      (t) => t.id == targetId,
      orElse: () => Transition(id: '', fromId: '', toId: '', symbols: {}),
    );
    if (transition.id.isEmpty || transition.symbols.length <= 1) return;

    _recordHistory();
    final list = transition.symbols.toList();
    list.removeLast();
    _automaton = _automaton.setTransition(transition.copyWith(symbols: list.toSet()));
    _initSimulator();
    notifyListeners();
  }

  /// Calculates a non-overlapping position near [sourcePos] for a newly connected node.
  Offset calculateNextNodePosition(Offset sourcePos) {
    const spacingX = 140.0;
    const spacingY = 90.0;
    final candidates = [
      sourcePos + const Offset(spacingX, 0),
      sourcePos + const Offset(spacingX, spacingY),
      sourcePos + const Offset(spacingX, -spacingY),
      sourcePos + const Offset(spacingX, spacingY * 2),
      sourcePos + const Offset(spacingX, -spacingY * 2),
      sourcePos + const Offset(spacingX * 2, 0),
    ];

    for (final candidate in candidates) {
      bool collision = false;
      for (final s in _automaton.states.values) {
        if ((s.position - candidate).distance < 60.0) {
          collision = true;
          break;
        }
      }
      if (!collision) {
        return candidate;
      }
    }
    return sourcePos + Offset(spacingX + (_automaton.states.length * 20.0), 0);
  }

  /// Chooses an intuitive default transition symbol for outgoing transitions from [fromId].
  String _chooseDefaultSymbol(String fromId) {
    final outgoingTransitions = _automaton.transitionsFrom(fromId);
    final usedSymbols = <String>{};
    for (final t in outgoingTransitions) {
      usedSymbols.addAll(t.symbols);
    }
    final alphabet = fullAlphabet.toList()..sort();
    for (final sym in alphabet) {
      if (!usedSymbols.contains(sym)) {
        return sym;
      }
    }
    if (alphabet.isNotEmpty) return alphabet.first;
    return '0';
  }

  void updateTransitionSymbols(String transitionId, Set<String> symbols) {
    final t = _automaton.transitions.firstWhere((t) => t.id == transitionId);
    _recordHistory();
    if (symbols.isEmpty) {
      _automaton = _automaton.removeTransition(transitionId);
      _selectedTransitionId = null;
    } else {
      _automaton = _automaton.setTransition(t.copyWith(symbols: symbols));
    }
    _initSimulator();
    notifyListeners();
  }

  void toggleTransitionSymbol(String transitionId, String symbol) {
    final t = _automaton.transitions.firstWhere((t) => t.id == transitionId);
    final nextSymbols = Set<String>.from(t.symbols);
    if (nextSymbols.contains(symbol)) {
      nextSymbols.remove(symbol);
    } else {
      nextSymbols.add(symbol);
    }
    updateTransitionSymbols(transitionId, nextSymbols);
  }

  void updateTransitionEndpoints(String transitionId, {String? fromId, String? toId}) {
    final t = _automaton.transitions.firstWhere((t) => t.id == transitionId);
    final targetFrom = fromId ?? t.fromId;
    final targetTo = toId ?? t.toId;
    if (targetFrom == t.fromId && targetTo == t.toId) return;

    _recordHistory();
    final existing = _automaton.transitionsBetween(targetFrom, targetTo);
    if (existing.isNotEmpty && existing.first.id != transitionId) {
      final mergedSymbols = Set<String>.from(existing.first.symbols)..addAll(t.symbols);
      _automaton = _automaton.removeTransition(transitionId);
      _automaton = _automaton.setTransition(existing.first.copyWith(symbols: mergedSymbols));
      _selectedTransitionId = existing.first.id;
    } else {
      _automaton = _automaton.removeTransition(transitionId);
      final updated = t.copyWith(fromId: targetFrom, toId: targetTo);
      _automaton = _automaton.setTransition(updated);
    }
    _initSimulator();
    notifyListeners();
  }

  void deleteTransition(String transitionId) {
    _recordHistory();
    _transitionTypingActive = false;
    _isAwaitingCommaAppend = false;
    _automaton = _automaton.removeTransition(transitionId);
    if (_selectedTransitionId == transitionId) {
      _selectedTransitionId = null;
    }
    _initSimulator();
    notifyListeners();
  }

  // --- Bi-Directional Editable Transition Matrix ---

  void addAlphabetSymbol(String symbol) {
    final trimmed = symbol.trim();
    if (trimmed.isNotEmpty) {
      _explicitAlphabet.add(trimmed);
      notifyListeners();
    }
  }

  void removeAlphabetSymbol(String symbol) {
    _recordHistory();
    _explicitAlphabet.remove(symbol);
    // Remove symbol from all transitions in automaton
    var updated = _automaton;
    for (final t in _automaton.transitions) {
      if (t.symbols.contains(symbol)) {
        final newSymbols = Set<String>.from(t.symbols)..remove(symbol);
        if (newSymbols.isEmpty) {
          updated = updated.removeTransition(t.id);
        } else {
          updated = updated.setTransition(t.copyWith(symbols: newSymbols));
        }
      }
    }
    _automaton = updated;
    _initSimulator();
    notifyListeners();
  }

  /// Sets destination state(s) for a given (sourceState, symbol) matrix cell.
  /// If targetStateIds is empty, removes symbol transitions from this state.
  void setMatrixCell(String stateId, String symbol, Set<String> targetStateIds) {
    _recordHistory();
    var updated = _automaton;

    // 1. Find all current transitions from this state that contain this symbol
    for (final t in _automaton.transitionsFrom(stateId)) {
      if (t.symbols.contains(symbol)) {
        if (!targetStateIds.contains(t.toId)) {
          // Remove symbol from transition towards toId
          final remaining = Set<String>.from(t.symbols)..remove(symbol);
          if (remaining.isEmpty) {
            updated = updated.removeTransition(t.id);
          } else {
            updated = updated.setTransition(t.copyWith(symbols: remaining));
          }
        }
      }
    }

    // 2. Ensure all requested targets have this symbol
    for (final targetId in targetStateIds) {
      final existing = updated.transitionsBetween(stateId, targetId);
      if (existing.isNotEmpty) {
        final t = existing.first;
        if (!t.symbols.contains(symbol)) {
          final newSymbols = Set<String>.from(t.symbols)..add(symbol);
          updated = updated.setTransition(t.copyWith(symbols: newSymbols));
        }
      } else {
        final newId = 't_${DateTime.now().millisecondsSinceEpoch}_$targetId';
        final newT = Transition(
          id: newId,
          fromId: stateId,
          toId: targetId,
          symbols: {symbol},
        );
        updated = updated.setTransition(newT);
      }
    }

    _automaton = updated;
    _initSimulator();
    notifyListeners();
  }

  // --- Auto-Layout Algorithms ---

  void applyForceDirectedLayout({Size canvasSize = const Size(1200, 800)}) {
    _recordHistory();
    const layout = ForceDirectedLayout();
    final newPositions = layout.calculateLayout(_automaton, canvasSize: canvasSize);

    var updated = _automaton;
    for (final entry in newPositions.entries) {
      final state = updated.states[entry.key];
      if (state != null) {
        updated = updated.setNode(state.copyWith(position: entry.value));
      }
    }
    _automaton = updated;
    _centerViewTrigger++;
    notifyListeners();
  }

  void applySugiyamaLayout({Size canvasSize = const Size(1200, 800)}) {
    _recordHistory();
    const layout = SugiyamaLayout();
    final newPositions = layout.calculateLayout(_automaton, canvasSize: canvasSize);

    var updated = _automaton;
    for (final entry in newPositions.entries) {
      final state = updated.states[entry.key];
      if (state != null) {
        updated = updated.setNode(state.copyWith(position: entry.value));
      }
    }
    _automaton = updated;
    _centerViewTrigger++;
    notifyListeners();
  }

  void loadPreset(AutomataPreset preset) {
    _recordHistory();
    stopPlayback();
    _currentMachineId = null;
    _machineName = preset.title;
    _automaton = preset.automaton;
    _inputTape = preset.defaultInput;
    _selectedStateId = null;
    _selectedTransitionId = null;
    _wireSourceStateId = null;
    _centerViewTrigger++;
    _initSimulator();
    notifyListeners();
  }

  void clearAutomaton() {
    _recordHistory();
    stopPlayback();
    _machineName = 'Untitled Machine';
    _currentMachineId = null;
    _automaton = Automaton();
    _selectedStateId = null;
    _selectedTransitionId = null;
    _lastActiveTransitionId = null;
    _isAwaitingCommaAppend = false;
    _transitionTypingActive = false;
    _wireSourceStateId = null;
    _initSimulator();
    notifyListeners();
  }

  // --- Bi-Directional Regex Synchronization ---

  /// Updates the regex pattern. If [syncToGraph] is true or [regexAutoSync] is active,
  /// compiles the regex to automaton and updates the canvas graph.
  void setRegexPattern(String pattern, {bool syncToGraph = false}) {
    _regexPattern = pattern;
    if (syncToGraph || _regexAutoSync) {
      syncRegexToGraph();
    } else {
      _isGraphOutOfSyncWithRegex = true;
      notifyListeners();
    }
  }

  /// Compiles current [_regexPattern] to an [Automaton] via Thompson's Construction
  /// and updates the canvas state with hierarchical auto-layout.
  void syncRegexToGraph() {
    _isSyncing = true;
    try {
      final newAutomaton = RegexService.regexToAutomaton(
        _regexPattern,
        applyLayout: true,
      );
      _recordHistory();
      _automaton = newAutomaton;
      _explicitAlphabet.addAll(newAutomaton.alphabet);
      _selectedStateId = null;
      _selectedTransitionId = null;
      _wireSourceStateId = null;
      _centerViewTrigger++;
      _initSimulator(syncRegex: false);
      _regexError = null;
      _isGraphOutOfSyncWithRegex = false;
    } on RegexParseException catch (e) {
      _regexError = e.message;
    } catch (e) {
      _regexError = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Extracts the regular expression from the current [Automaton] via State Elimination
  /// and updates [_regexPattern].
  void syncGraphToRegex() {
    _isSyncing = true;
    try {
      _regexPattern = RegexService.automatonToRegex(_automaton);
      _regexError = null;
      _isGraphOutOfSyncWithRegex = false;
    } catch (e) {
      _regexError = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Toggles live bidirectional auto-sync between regex and graph.
  void toggleRegexAutoSync([bool? enabled]) {
    _regexAutoSync = enabled ?? !_regexAutoSync;
    if (_regexAutoSync && _isGraphOutOfSyncWithRegex) {
      syncGraphToRegex();
    } else {
      notifyListeners();
    }
  }

  void _syncGraphToRegexInternal() {
    if (_isSyncing) return;
    if (_regexAutoSync) {
      _isSyncing = true;
      try {
        _regexPattern = RegexService.automatonToRegex(_automaton);
        _regexError = null;
        _isGraphOutOfSyncWithRegex = false;
      } catch (e) {
        _regexError = e.toString();
      } finally {
        _isSyncing = false;
      }
    } else {
      _isGraphOutOfSyncWithRegex = true;
    }
  }

  // --- Simulation Management ---

  void setInputTape(String tape) {
    _inputTape = tape;
    _initSimulator(syncRegex: false);
    if (_liveMode && _simulator != null) {
      _simulator!.runToEnd();
    }
    notifyListeners();
  }

  void _initSimulator({bool syncRegex = true}) {
    stopPlayback();
    _simulator = AutomataSimulator.run(
      automaton: _automaton,
      inputTape: _inputTape,
    );
    if (syncRegex) {
      _syncGraphToRegexInternal();
    }
  }

  void stepForward() {
    _simulator?.stepForward();
    notifyListeners();
  }

  void stepBackward() {
    _simulator?.stepBackward();
    notifyListeners();
  }

  void jumpToStep(int index) {
    _simulator?.jumpTo(index);
    notifyListeners();
  }

  void resetSimulation() {
    _simulator?.reset();
    notifyListeners();
  }

  void togglePlayPause() {
    if (_isPlaying) {
      stopPlayback();
    } else {
      startPlayback();
    }
  }

  void startPlayback() {
    if (_simulator == null) return;
    if (_simulator!.isAtEnd) {
      _simulator!.reset();
    }
    _isPlaying = true;
    notifyListeners();

    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(_playbackSpeed, (timer) {
      if (_simulator != null && _simulator!.canStepForward) {
        _simulator!.stepForward();
        notifyListeners();
      } else {
        stopPlayback();
      }
    });
  }

  void stopPlayback() {
    _isPlaying = false;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    notifyListeners();
  }

  List<BatchTestResult> runBatchTests(List<({String input, bool expected})> suite) {
    return suite.map((testCase) {
      final sim = AutomataSimulator.run(
        automaton: _automaton,
        inputTape: testCase.input,
      );
      return BatchTestResult(
        input: testCase.input,
        expected: testCase.expected,
        actual: sim.isStringAccepted,
      );
    }).toList();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }
}
