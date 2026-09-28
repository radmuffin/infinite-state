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
  RegexCompileMode _regexCompileMode = RegexCompileMode.minimalDfa;

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
  RegexCompileMode get regexCompileMode => _regexCompileMode;

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
      _initSimulator();
      _syncGraphToRegexInternal();
      notifyListeners();
    }
  }

  void selectState(String? id) {
    _selectedStateId = id;
    _selectedTransitionId = null;
    notifyListeners();
  }

  void selectTransition(String? id) {
    _selectedTransitionId = id;
    _selectedStateId = null;
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

  void connectStates(String fromId, String toId, {String defaultSymbol = '0'}) {
    _recordHistory();
    final existing = _automaton.transitionsBetween(fromId, toId);
    if (existing.isNotEmpty) {
      _selectedTransitionId = existing.first.id;
    } else {
      final newId = 't_${DateTime.now().millisecondsSinceEpoch}';
      final newTransition = Transition(
        id: newId,
        fromId: fromId,
        toId: toId,
        symbols: {defaultSymbol},
      );
      _automaton = _automaton.setTransition(newTransition);
      _selectedTransitionId = newId;
    }
    _initSimulator();
    notifyListeners();
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

  /// Sets the regex compilation strategy ([RegexCompileMode.minimalDfa] vs [RegexCompileMode.thompsonNfa]).
  /// If [recompile] is true and a non-empty regex pattern is set, immediately syncs to graph.
  void setRegexCompileMode(RegexCompileMode mode, {bool recompile = true}) {
    if (_regexCompileMode == mode) return;
    _regexCompileMode = mode;
    if (recompile && _regexPattern.trim().isNotEmpty) {
      syncRegexToGraph();
    } else {
      notifyListeners();
    }
  }

  /// Compiles current [_regexPattern] to an [Automaton] using [_regexCompileMode]
  /// and updates the canvas state with hierarchical auto-layout.
  void syncRegexToGraph() {
    _isSyncing = true;
    try {
      final newAutomaton = RegexService.regexToAutomaton(
        _regexPattern,
        mode: _regexCompileMode,
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
