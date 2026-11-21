import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

/// US-23: a Book Plant Care button on each plant.
void main() {
  testWidgets('AC-01 a plant card asks for the service and opens the list filtered by it', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    await tester.runAsync(() => app.backend.addToGarden('p04'));
    final g = app.backend.garden.single;
    go(tester, '/garden');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('bookCare-${g.id}')));
    await tester.pumpAndSettle();
    expect(find.text('What does Date palm need?'), findsOneWidget);
    // The three care services, and no planting for a plant already planted.
    expect(find.byKey(const Key('care-pruning')), findsOneWidget);
    expect(find.byKey(const Key('care-periodicCare')), findsOneWidget);
    expect(find.byKey(const Key('care-treatment')), findsOneWidget);
    expect(find.byKey(const Key('care-planting')), findsNothing);

    await tester.tap(find.byKey(const Key('care-treatment')));
    await tester.pumpAndSettle();
    expect(location(tester), '/garden/care?service=treatment&plant=${g.id}');
    expect(find.text('Care for Date palm'), findsOneWidget);
    expect(find.byKey(const Key('pro-pr4')), findsOneWidget);
    expect(find.byKey(const Key('pro-pr2')), findsOneWidget);
    expect(find.byKey(const Key('pro-pr1')), findsNothing, reason: 'pr1 does not treat');
  });

  testWidgets('the plant page has the button too, and closing the sheet stays put', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    await tester.runAsync(() => app.backend.addToGarden('p16'));
    final g = app.backend.garden.single;
    go(tester, '/garden/plant/${g.id}');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bookCare')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // outside the sheet
    await tester.pumpAndSettle();
    expect(location(tester), '/garden/plant/${g.id}');

    await tester.tap(find.byKey(const Key('bookCare')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('care-pruning')));
    await tester.pumpAndSettle();
    expect(location(tester), '/garden/care?service=pruning&plant=${g.id}');
    expect(find.byKey(const Key('pro-pr1')), findsOneWidget);
  });
}
