import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infinite_state/main.dart';
import 'package:infinite_state/ui/canvas/automata_canvas.dart';
import 'package:infinite_state/ui/panels/simulation_bar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('InfiniteStateApp loads and displays refined UI components',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const InfiniteStateApp());
    await tester.pumpAndSettle();

    // Verify Uncapitalized Title & Clean Toolbar
    expect(find.text('infinite state'), findsOneWidget);
    expect(find.text('Binary Divisible by 3'), findsOneWidget);

    // Verify redundant buttons are removed from top bar
    expect(find.text('Auto-Layout'), findsNothing);
    expect(find.text('Library & Save'), findsNothing);

    // Verify HUD in lower-left has center and layout switches
    expect(find.byTooltip('Center Graph on Screen'), findsOneWidget);
    expect(find.byTooltip('Force-Directed Auto-Layout'), findsOneWidget);
    expect(find.byTooltip('Hierarchical (Textbook Flow) Layout'), findsOneWidget);

    // Verify Consolidated Right Sidebar Activity Rail
    expect(find.byTooltip('Inspector & Matrix'), findsOneWidget);
    expect(find.byTooltip('Regex & Language L(M)'), findsOneWidget);
    expect(find.byTooltip('Batch Testing Suite'), findsOneWidget);
    expect(find.byTooltip('Library & Presets'), findsOneWidget);

    // Verify Inspector & Matrix is open by default
    expect(find.text('INSPECTOR & MATRIX'), findsOneWidget);
    expect(find.text('Transition Matrix (δ)'), findsOneWidget);

    // Verify Simulation Bar with Live mode toggle and no Set button
    expect(find.text('TAPE:'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Set'), findsNothing);
  });

  testWidgets('RightSidebar switches seamlessly between Inspector, Batch Tests, and Library',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const InfiniteStateApp());
    await tester.pumpAndSettle();

    // Inspector is open initially
    expect(find.text('INSPECTOR & MATRIX'), findsOneWidget);

    // Tap Batch Testing tab
    await tester.tap(find.byTooltip('Batch Testing Suite'));
    await tester.pumpAndSettle();

    // Verify Batch Test panel opened in the same place
    expect(find.text('BATCH TESTS'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('INSPECTOR & MATRIX'), findsNothing);

    // Tap Library & Presets tab
    await tester.tap(find.byTooltip('Library & Presets'));
    await tester.pumpAndSettle();

    // Verify Library panel opened in the same place
    expect(find.text('LIBRARY & PRESETS'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Presets'), findsOneWidget);
    expect(find.text('JSON'), findsOneWidget);
    expect(find.text('BATCH TESTS'), findsNothing);

    // Tap Library & Presets tab again to toggle closed
    await tester.tap(find.byTooltip('Library & Presets'));
    await tester.pumpAndSettle();

    // Panel is closed, maximizing canvas
    expect(find.text('LIBRARY & PRESETS'), findsNothing);
    expect(find.text('INSPECTOR & MATRIX'), findsNothing);
    expect(find.text('BATCH TESTS'), findsNothing);

    // Reopen Inspector tab
    await tester.tap(find.byTooltip('Inspector & Matrix'));
    await tester.pumpAndSettle();
    expect(find.text('INSPECTOR & MATRIX'), findsOneWidget);
  });

  testWidgets('Tape input auto-sets on change and Live Mode animates transitions with each key press',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const InfiniteStateApp());
    await tester.pumpAndSettle();

    final canvasFinder = find.byType(AutomataCanvas);
    final canvasWidget = tester.widget<AutomataCanvas>(canvasFinder);
    final controller = canvasWidget.controller;

    // Initially Binary Divisible by 3 has default input '1001'
    expect(controller.inputTape, equals('1001'));

    // Find the tape input text field (descendant of SimulationBar)
    final tapeFieldFinder = find.descendant(
      of: find.byType(SimulationBar),
      matching: find.byType(TextField),
    );
    expect(tapeFieldFinder, findsOneWidget);

    // 1. Auto-set test (no need to press a "Set" button)
    await tester.enterText(tapeFieldFinder, '10');
    await tester.pumpAndSettle();

    // Controller input tape is immediately updated
    expect(controller.inputTape, equals('10'));

    // 2. Live Mode toggle
    expect(controller.liveMode, isFalse);
    final liveButtonFinder = find.text('Live');
    await tester.tap(liveButtonFinder);
    await tester.pumpAndSettle();
    expect(controller.liveMode, isTrue);

    // In Binary Divisible by 3:
    // Initial state: q0
    // Input '1': transitions q0 -> q1
    // Input '10': transitions q1 -> q2
    // So for '10', the live simulator should be at step 2 with active state q2
    expect(controller.simulator?.currentStepIndex, equals(2));
    expect(controller.activeStateIds, equals({'q2'}));

    // Now type an additional character '1' -> input becomes '101'
    // Transition from q2 on '1': in binary divisible by 3, (2*2 + 1) mod 3 = 5 mod 3 = 2 -> goes to q2
    await tester.enterText(tapeFieldFinder, '101');
    await tester.pumpAndSettle();

    expect(controller.inputTape, equals('101'));
    // Step index advanced automatically on key press
    expect(controller.simulator?.currentStepIndex, equals(3));
    expect(controller.activeStateIds, equals({'q2'}));

    // Now backspace to '1' (deleting two characters)
    await tester.enterText(tapeFieldFinder, '1');
    await tester.pumpAndSettle();

    expect(controller.inputTape, equals('1'));
    // Simulation steps back to step 1 (q1)
    expect(controller.simulator?.currentStepIndex, equals(1));
    expect(controller.activeStateIds, equals({'q1'}));
  });

  testWidgets('Transition matrix allows inline cell editing without modal dialogs',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const InfiniteStateApp());
    await tester.pumpAndSettle();

    // Find cells in the transition matrix table (e.g. q1 target from q0 on '0')
    // Tap on cell displaying 'q1' or 'q0'
    final matrixCellFinder = find.text('q1').first;
    expect(matrixCellFinder, findsOneWidget);

    await tester.tap(matrixCellFinder);
    await tester.pumpAndSettle();

    // Verify the inline cell editor card opens beneath the table
    expect(find.textContaining('Targets'), findsOneWidget);
    expect(find.text('Clear (∅)'), findsOneWidget);
    expect(find.text('Tap state chips to toggle destinations in real-time:'),
        findsOneWidget);

    // Tap Clear (∅) to clear targets
    await tester.tap(find.text('Clear (∅)'));
    await tester.pumpAndSettle();

    // Verify cell now shows '—'
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('Toolbar supports in-place machine renaming and anchored clear menu',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const InfiniteStateApp());
    await tester.pumpAndSettle();

    // 1. In-place machine renaming
    final titleFinder = find.text('Binary Divisible by 3');
    expect(titleFinder, findsOneWidget);
    await tester.tap(titleFinder);
    await tester.pumpAndSettle();

    // Check TextField appeared directly inside the toolbar pill
    final textInputFinder = find.byType(TextField);
    expect(textInputFinder, findsWidgets);

    // Enter new name and submit
    await tester.enterText(textInputFinder.first, 'My Custom DFA');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('My Custom DFA'), findsOneWidget);

    // 2. Anchored clear menu
    final clearButtonFinder = find.byTooltip('Clear All States');
    expect(clearButtonFinder, findsOneWidget);
    await tester.tap(clearButtonFinder);
    await tester.pumpAndSettle();

    // Menu options appeared
    expect(find.textContaining('Clear all states & transitions?'), findsOneWidget);
    expect(find.text('Clear Canvas'), findsOneWidget);

    // Tap Clear Canvas
    await tester.tap(find.text('Clear Canvas'));
    await tester.pumpAndSettle();

    // States cleared: matrix table now shows empty notice
    expect(find.textContaining('No states in machine'), findsOneWidget);
  });

  testWidgets('Connector selection displays floating quick actions pill and inspector details',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const InfiniteStateApp());
    await tester.pumpAndSettle();

    final canvasFinder = find.byType(AutomataCanvas);
    expect(canvasFinder, findsOneWidget);

    final canvasWidget = tester.widget<AutomataCanvas>(canvasFinder);
    final controller = canvasWidget.controller;

    // Initially no transition selected
    expect(controller.selectedTransitionId, isNull);

    // Pick first transition (e.g. q0 -> q0 on '0' or q0 -> q1 on '1')
    final firstTransition = controller.automaton.transitions.first;

    // Select the transition
    controller.selectTransition(firstTransition.id);
    await tester.pumpAndSettle();

    // Verify floating quick actions pill appeared on canvas with source -> target label
    expect(
      find.textContaining('${firstTransition.fromId} → ${firstTransition.toId}'),
      findsWidgets,
    );
    expect(find.byTooltip('Delete Transition'), findsWidgets);

    // Verify Inspector displays transition properties
    expect(find.text('Selected Connector'), findsOneWidget);
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);

    // Test toggling '1' (which is not yet on q0 -> q0)
    expect(firstTransition.symbols.contains('1'), isFalse);
    final oneChip = find.text('1').first;
    await tester.tap(oneChip);
    await tester.pumpAndSettle();

    // Verify '1' is now in the transition symbols
    final updatedTrans = controller.automaton.transitions
        .firstWhere((t) => t.id == firstTransition.id);
    expect(updatedTrans.symbols.contains('1'), isTrue);
  });

  testWidgets('RightSidebar opens Regex panel and supports compile to graph and extract regex',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const InfiniteStateApp());
    await tester.pumpAndSettle();

    // Tap Regex Studio rail icon
    await tester.tap(find.byTooltip('Regex & Language L(M)'));
    await tester.pumpAndSettle();

    // Verify Regex Panel opened
    expect(find.text('REGEX & LANGUAGE'), findsOneWidget);
    expect(find.text('REGULAR EXPRESSION'), findsOneWidget);
    expect(find.text('Compile Regex → Canvas Graph'), findsOneWidget);
    expect(find.text('Extract Graph → Regex'), findsOneWidget);
    expect(find.text('Live Auto-Sync'), findsOneWidget);

    // Enter a new regex pattern
    final regexInputFinder = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText?.contains('e.g.') == true,
    );
    expect(regexInputFinder, findsOneWidget);

    await tester.enterText(regexInputFinder, '(a|b)*abb');
    await tester.pumpAndSettle();

    // Tap Compile Regex -> Canvas Graph
    await tester.tap(find.text('Compile Regex → Canvas Graph'));
    await tester.pumpAndSettle();

    // Canvas should now contain states for (a|b)*abb
    expect(find.text('Synced'), findsNothing); // Or verify status banner
    expect(find.text('In Sync with Graph'), findsOneWidget);
  });

  testWidgets('Adding a node allows auto-adding a connected node via + Node button and connector handle',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const InfiniteStateApp());
    await tester.pumpAndSettle();

    final canvasFinder = find.byType(AutomataCanvas);
    expect(canvasFinder, findsOneWidget);
    final canvasWidget = tester.widget<AutomataCanvas>(canvasFinder);
    final controller = canvasWidget.controller;

    // Clear canvas so we start fresh
    controller.clearAutomaton();
    await tester.pumpAndSettle();
    expect(controller.automaton.states, isEmpty);

    // 1. Add a single node q0 at (400, 300)
    controller.addStateAt(const Offset(400, 300));
    controller.triggerCenterView();
    await tester.pumpAndSettle();

    expect(controller.automaton.states.length, equals(1));
    // Verify streamlined quick action menu is visible for selected state without redundant '+ Node'
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('+ Node'), findsNothing);

    // 2. Auto-add connected node q1 from q0
    controller.autoAddConnectedNode('q0');
    await tester.pumpAndSettle();

    // Verify a new node was automatically created and connected
    expect(controller.automaton.states.length, equals(2));
    final q1 = controller.automaton.states['q1'];
    expect(q1, isNotNull);
    expect(controller.selectedStateId, equals('q1')); // Newly created node is selected

    // Verify transition exists from q0 -> q1
    final transitions = controller.automaton.transitionsBetween('q0', 'q1');
    expect(transitions, isNotEmpty);

    // 3. Test hitting the plus connector handle on the canvas directly
    // The newly selected node q1 has a handle at (q1.position + Offset(30 + 14, 0))
    final interactiveViewerFinder = find.byType(InteractiveViewer);
    final iv = tester.widget<InteractiveViewer>(interactiveViewerFinder);
    final matrix = iv.transformationController!.value;
    final ivOrigin = tester.getTopLeft(interactiveViewerFinder);
    final q1HandleScenePos = q1!.position + const Offset(44.0, 0.0);
    final q1HandleGlobalPos = ivOrigin + MatrixUtils.transformPoint(matrix, q1HandleScenePos);

    // Tap on the plus handle
    final gesture = await tester.startGesture(q1HandleGlobalPos);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    // Verify a 3rd node q2 was automatically created and connected from q1
    expect(controller.automaton.states.length, equals(3));
    final q2 = controller.automaton.states['q2'];
    expect(q2, isNotNull);
    expect(controller.selectedStateId, equals('q2'));
    expect(controller.automaton.transitionsBetween('q1', 'q2'), isNotEmpty);

    // 4. Test dragging from the plus handle into empty canvas space
    final q2HandleScenePos = q2!.position + const Offset(44.0, 0.0);
    final q2HandleGlobalPos = ivOrigin + MatrixUtils.transformPoint(matrix, q2HandleScenePos);
    final dragDropGlobalPos = q2HandleGlobalPos + const Offset(-40.0, 100.0);

    final dragGesture = await tester.startGesture(q2HandleGlobalPos);
    await tester.pump(const Duration(milliseconds: 50));
    await dragGesture.moveTo(dragDropGlobalPos);
    await tester.pump(const Duration(milliseconds: 50));
    await dragGesture.up();
    await tester.pumpAndSettle();

    // Verify a 4th node q3 was created at the drop location and connected from q2
    expect(controller.automaton.states.length, equals(4));
    final q3 = controller.automaton.states['q3'];
    expect(q3, isNotNull);
    expect(controller.selectedStateId, equals('q3'));
    expect(controller.automaton.transitionsBetween('q2', 'q3'), isNotEmpty);

    // 5. Test dragging from the plus handle to an EXISTING node (q3 -> q0)
    final q3HandleScenePos = q3!.position + const Offset(44.0, 0.0);
    final q3HandleGlobalPos = ivOrigin + MatrixUtils.transformPoint(matrix, q3HandleScenePos);
    final q0GlobalPos = ivOrigin + MatrixUtils.transformPoint(matrix, controller.automaton.states['q0']!.position);

    final connectExistingGesture = await tester.startGesture(q3HandleGlobalPos);
    await tester.pump(const Duration(milliseconds: 50));
    await connectExistingGesture.moveTo(q0GlobalPos);
    await tester.pump(const Duration(milliseconds: 50));
    await connectExistingGesture.up();
    await tester.pumpAndSettle();

    // Verify NO new node was created (still 4 states) and transition q3 -> q0 exists
    expect(controller.automaton.states.length, equals(4));
    expect(controller.automaton.transitionsBetween('q3', 'q0'), isNotEmpty);
  });

  testWidgets('Typing characters directly assigns them to the connector without middle steps',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const InfiniteStateApp());
    await tester.pumpAndSettle();

    final canvasFinder = find.byType(AutomataCanvas);
    final canvasWidget = tester.widget<AutomataCanvas>(canvasFinder);
    final controller = canvasWidget.controller;

    // Clear canvas
    controller.clearAutomaton();
    await tester.pumpAndSettle();

    // 1. Add state q0
    controller.addStateAt(const Offset(400, 300));
    await tester.pumpAndSettle();

    // 2. Add connected node q1 from q0
    controller.autoAddConnectedNode('q0');
    await tester.pumpAndSettle();

    final initialTransition = controller.automaton.transitionsBetween('q0', 'q1').first;
    expect(initialTransition.symbols, contains('0'));

    // 3. Directly type 'a' without clicking anything!
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    await tester.pumpAndSettle();

    var updatedTransition = controller.automaton.transitionsBetween('q0', 'q1').first;
    expect(updatedTransition.symbols, equals({'a'}));

    // 4. Directly type 'b' without needing comma -> automatically interpreted as 'a, b'!
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB, character: 'b');
    await tester.pumpAndSettle();

    updatedTransition = controller.automaton.transitionsBetween('q0', 'q1').first;
    expect(updatedTransition.symbols, equals({'a', 'b'}));

    // 5. Backspace removes the most recent symbol 'b', restoring 'a'
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    updatedTransition = controller.automaton.transitionsBetween('q0', 'q1').first;
    expect(updatedTransition.symbols, equals({'a'}));

    // 6. Select transition and type 'c' directly to start fresh session
    controller.selectTransition(updatedTransition.id);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyC, character: 'c');
    await tester.pumpAndSettle();

    updatedTransition = controller.automaton.transitionsBetween('q0', 'q1').first;
    expect(updatedTransition.symbols, equals({'c'}));
  });
}

