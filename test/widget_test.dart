import 'package:flutter/material.dart';
import 'package:infinite_state/main.dart';
import 'package:infinite_state/ui/canvas/automata_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('InfiniteStateApp loads and displays refined UI components',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const InfiniteStateApp());
    await tester.pumpAndSettle();

    // Verify Title & Toolbar
    expect(find.text('Infinite State'), findsOneWidget);
    expect(find.text('Library & Save'), findsOneWidget);
    expect(find.text('Auto-Layout'), findsOneWidget);
    expect(find.text('Batch Tests'), findsOneWidget);

    // Verify Inspector & Matrix
    expect(find.text('INSPECTOR & MATRIX'), findsOneWidget);
    expect(find.text('Transition Matrix (δ)'), findsOneWidget);

    // Verify Simulation Bar
    expect(find.text('TAPE:'), findsOneWidget);
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
}

