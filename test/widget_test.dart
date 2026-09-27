import 'dart:ui';
import 'package:infinite_state/main.dart';
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
}
