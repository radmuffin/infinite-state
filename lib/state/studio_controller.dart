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

enum CanvasTool {
  select,
  addState,
  addTransition,
  delete,
}

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

class StudioController extends ChangeNotifier {
  Automaton _automaton = ExampleAutomata.binaryDivisibleBy3.automaton;
  String _inputTape = ExampleAutomata.binaryDivisibleBy3.defaultInput;

  CanvasTool _currentTool = CanvasTool.select;
  String? _selectedStateId;
  String? _selectedTransitionId;
  String? _transitionPendingStartId;

  AutomataSimulator? _simulator;
  Timer? _playbackTimer;
  bool _isPlaying = false;
  final Duration _playbackSpeed = const Duration(milliseconds: 650);
  int _centerViewTrigger = 0;

  // Undo stack
  final List<Automaton> _undoStack = [];

  StudioController() {
    _initSimulator();
  }

  // --- Getters ---
  Automaton get automaton => _automaton;
  String get inputTape => _inputTape;
  CanvasTool get currentTool => _currentTool;
  String? get selectedStateId => _selectedStateId;
  String? get selectedTransitionId => _selectedTransitionId;
  String? get transitionPendingStartId => _transitionPendingStartId;
  AutomataSimulator? get simulator => _simulator;
  bool get isPlaying => _isPlaying;
  Duration get playbackSpeed => _playbackSpeed;
  int get centerViewTrigger => _centerViewTrigger;

  void triggerCenterView() {
    _centerViewTrigger++;
    notifyListeners();
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

  // --- State Manipulation ---

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
      _transitionPendingStartId = null;
      _initSimulator();
      notifyListeners();
    }
  }

  void setTool(CanvasTool tool) {
    _currentTool = tool;
    _transitionPendingStartId = null;
    notifyListeners();
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

  void addStateAt(Offset position) {
    _recordHistory();
    final count = _automaton.states.length;
    final newId = 'q$count';
    // Ensure unique ID
    String id = newId;
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

  void handleTransitionConnect(String targetId) {
    if (_transitionPendingStartId == null) {
      _transitionPendingStartId = targetId;
      notifyListeners();
    } else {
      final fromId = _transitionPendingStartId!;
      _transitionPendingStartId = null;
      _recordHistory();

      // Check if a transition already exists between these states
      final existing = _automaton.transitionsBetween(fromId, targetId);
      if (existing.isNotEmpty) {
        // Already exists, just select it
        _selectedTransitionId = existing.first.id;
      } else {
        final newId = 't_${DateTime.now().millisecondsSinceEpoch}';
        final newTransition = Transition(
          id: newId,
          fromId: fromId,
          toId: targetId,
          symbols: {'0'},
        );
        _automaton = _automaton.setTransition(newTransition);
        _selectedTransitionId = newId;
      }
      _initSimulator();
      notifyListeners();
    }
  }

  void cancelPendingTransition() {
    _transitionPendingStartId = null;
    notifyListeners();
  }

  void updateTransitionSymbols(String transitionId, Set<String> symbols) {
    final t = _automaton.transitions.firstWhere((t) => t.id == transitionId);
    _recordHistory();
    _automaton = _automaton.setTransition(t.copyWith(symbols: symbols));
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
    _automaton = preset.automaton;
    _inputTape = preset.defaultInput;
    _selectedStateId = null;
    _selectedTransitionId = null;
    _transitionPendingStartId = null;
    _centerViewTrigger++;
    _initSimulator();
    notifyListeners();
  }

  void clearAutomaton() {
    _recordHistory();
    stopPlayback();
    _automaton = Automaton();
    _selectedStateId = null;
    _selectedTransitionId = null;
    _transitionPendingStartId = null;
    _initSimulator();
    notifyListeners();
  }

  // --- Simulation Management ---

  void setInputTape(String tape) {
    _inputTape = tape;
    _initSimulator();
    notifyListeners();
  }

  void _initSimulator() {
    stopPlayback();
    _simulator = AutomataSimulator.run(
      automaton: _automaton,
      inputTape: _inputTape,
    );
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
