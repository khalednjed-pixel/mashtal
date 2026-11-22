import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/logic/care_plan.dart';
import 'package:mashtal/logic/watering.dart';
import 'package:mashtal/models/models.dart';
import 'package:mashtal/ui/widgets/home_picker.dart';

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
    // One question: where it lives, with our guess marked.
    expect(find.byKey(const Key('homePicker')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-bigPot')));
    await tester.pumpAndSettle();
    // Choosing a tile only selects it; the one button adds the plant.
    expect(app.backend.garden, isEmpty);
    await tester.tap(find.byKey(const Key('homeConfirm')));
    await tester.pumpAndSettle();

    expect(location(tester), '/garden');
    final g = app.backend.garden.single;
    expect(find.byKey(Key('garden-${g.id}')), findsOneWidget);
    expect(find.text('Bougainvillea'), findsOneWidget);
    expect(g.home, PlantHome.bigPot);
    // The care plan adjusts the plant's usual interval for a new plant in a
    // big pot and the season.
    final plan = CarePlan.of(g, app.backend.plantById('p16')!, DateTime.now());
    expect(tester.widget<Text>(find.byKey(Key('frequency-${g.id}'))).data, '${wateringEveryText('en', plan.everyDays)} now');
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

  testWidgets('the "where is it?" sheet adds nothing until its button is pressed', (tester) async {
    final app = await pumpMashtal(tester);
    await signIn(tester, '0500000005');
    go(tester, '/garden/add');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-p16')));
    await tester.pumpAndSettle();
    // Our pick is already selected and the button says what it does.
    expect(find.text('Our pick'), findsOneWidget);
    expect(find.text('Add to My Garden'), findsOneWidget);

    // Closing the sheet without the button adds nothing.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('homePicker')), findsNothing);
    expect(location(tester), '/garden/add');
    expect(app.backend.garden, isEmpty);
  });

  testWidgets('a save that fails keeps the sheet open and says so', (tester) async {
    await pumpMashtal(tester);
    final context = tester.element(find.byType(Scaffold).first);
    var tries = 0;
    PlantHome? result;
    pickHome(context, current: PlantHome.ground, guessed: true, onConfirm: (h) async {
      tries++;
      if (tries == 1) throw StateError('permission-denied');
    }).then((h) => result = h);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('homeConfirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('homePicker')), findsOneWidget);
    expect(find.text("Couldn't add it. Check your connection and try again."), findsOneWidget);
    expect(result, isNull);

    // Trying again works and closes the sheet with the answer.
    await tester.tap(find.byKey(const Key('homeConfirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('homePicker')), findsNothing);
    expect(result, PlantHome.ground);
  });
}
