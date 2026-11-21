import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

/// US-21: My Garden with watering frequency.
void main() {
  Future<void> signIn(WidgetTester tester, String phone) async {
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, phone);
  }

  testWidgets('AC-02 the empty garden offers Buy Plants and Add a plant manually', (tester) async {
    await pumpMashtal(tester);
    await signIn(tester, '0500000005');
    go(tester, '/garden');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gardenBuyPlants')), findsOneWidget);
    expect(find.text('Add a plant manually'), findsOneWidget);

    await tester.tap(find.byKey(const Key('gardenBuyPlants')));
    await tester.pumpAndSettle();
    expect(location(tester), '/shop');
  });

  testWidgets('AC-01 each plant has a card with name, photo and watering frequency', (tester) async {
    final app = await pumpMashtal(tester);
    await signIn(tester, '0500000005');
    go(tester, '/garden');
    await tester.pumpAndSettle();

    // Add a plant by hand through the empty state.
    await tester.tap(find.byKey(const Key('addManually')));
    await tester.pumpAndSettle();
    expect(location(tester), '/garden/add');
    await tester.enterText(find.byKey(const Key('gardenSearch')), 'bougain');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-p16')));
    await tester.pumpAndSettle();

    expect(location(tester), '/garden');
    final g = app.backend.garden.single;
    expect(find.byKey(Key('garden-${g.id}')), findsOneWidget);
    expect(find.text('Bougainvillea'), findsOneWidget);
    // Bougainvillea is watered every 5 days in the guide data.
    expect(tester.widget<Text>(find.byKey(Key('frequency-${g.id}'))).data, 'Every 5 days');
    expect(find.text('Nothing to water today'), findsOneWidget);
  });

  testWidgets('the drop records a watering', (tester) async {
    final app = await pumpMashtal(tester);
    await signIn(tester, '0500000005');
    await tester.runAsync(() => app.backend.addToGarden('p04'));
    go(tester, '/garden');
    await tester.pumpAndSettle();
    final g = app.backend.garden.single;
    expect(g.lastWateredAt, isNull);
    await tester.tap(find.byKey(Key('water-${g.id}')));
    await tester.pumpAndSettle();
    expect(app.backend.garden.single.lastWateredAt, isNotNull);
    expect(find.textContaining('Watering recorded'), findsOneWidget);
  });
}
