import 'dart:ui';
import 'package:automata_studio/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AutomataStudioApp loads and displays UI components',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const AutomataStudioApp());
    await tester.pumpAndSettle();

    // Verify Title & Toolbar
    expect(find.text('Automata Studio'), findsOneWidget);
    expect(find.text('Auto-Layout'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Transition'), findsOneWidget);

    // Verify Inspector & Matrix
    expect(find.text('INSPECTOR & MATRIX'), findsOneWidget);
    expect(find.text('Transition Function (δ)'), findsOneWidget);

    // Verify Simulation Bar
    expect(find.text('TAPE:'), findsOneWidget);
  });
}
