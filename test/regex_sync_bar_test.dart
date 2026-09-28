import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_state/state/studio_controller.dart';
import 'package:infinite_state/ui/panels/regex_sync_bar.dart';

void main() {
  testWidgets('RegexSyncBar renders regex input, status badge, and sync buttons',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = StudioController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegexSyncBar(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify presence of UI components
    expect(find.text('REGEX'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Regex → Graph'), findsOneWidget);
    expect(find.text('Graph → Regex'), findsOneWidget);
    expect(find.text('Auto-Sync'), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);
    expect(find.text('+ε'), findsOneWidget);
  });

  testWidgets('Entering regex and clicking Regex -> Graph updates controller',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = StudioController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegexSyncBar(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter a new regex into the text field
    final inputFinder = find.byType(TextField);
    await tester.enterText(inputFinder, '(0|1)*1');
    await tester.pumpAndSettle();

    // Tap Regex -> Graph
    await tester.tap(find.text('Regex → Graph'));
    await tester.pumpAndSettle();

    // Controller should now have parsed the pattern
    expect(controller.regexError, isNull);
    expect(controller.automaton.states.isNotEmpty, isTrue);
  });

  testWidgets('Invalid syntax displays Syntax Error badge',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = StudioController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegexSyncBar(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter invalid syntax
    final inputFinder = find.byType(TextField);
    await tester.enterText(inputFinder, '(a|b*');
    await tester.tap(find.text('Regex → Graph'));
    await tester.pumpAndSettle();

    // Status badge should show Syntax Error
    expect(find.text('Syntax Error'), findsOneWidget);
    expect(controller.regexError, isNotNull);
  });
}
