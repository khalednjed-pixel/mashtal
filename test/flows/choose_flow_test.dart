import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/ui/customer/choose_screen.dart';

import 'app_harness.dart';

Future<void> answer(WidgetTester tester, String option) async {
  await tester.tap(find.byKey(Key('option-$option')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(ChooseScreen.resetSaved);

  testWidgets('US-07 a guest answers one question per screen and gets ranked, cited results', (tester) async {
    await pumpMashtal(tester);
    await tester.tap(find.byKey(const Key('chooseBanner')));
    await tester.pumpAndSettle();
    expect(location(tester), '/choose');
    expect(find.byKey(const Key('chooseProgress')), findsOneWidget);
    expect(find.byKey(const Key('question-city')), findsOneWidget);

    await answer(tester, 'city-riyadh');
    await answer(tester, 'spot-inside');
    // AC-02: inside the house asks about the window.
    expect(find.byKey(const Key('question-window')), findsOneWidget);
    await answer(tester, 'window-little');
    await answer(tester, 'space-little');
    await answer(tester, 'watering-some');
    await answer(tester, 'kids-yes');

    // US-09: ranked with percentages; toxic plants left out (AC-02).
    expect(find.text('Best plants for your place'), findsOneWidget);
    expect(find.byKey(const Key('result-p37')), findsOneWidget);
    expect(find.byKey(const Key('result-p28')), findsOneWidget);
    expect(find.byKey(const Key('result-p34')), findsNothing);
    expect(find.text('82%'), findsOneWidget);

    // US-10: the citation opens the values used next to the answers.
    await tester.tap(find.byKey(const Key('citation-p28')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scoreExplanation')), findsOneWidget);
    expect(find.text('Your answer'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // US-12: tapping a result lists the nurseries that have it.
    await tester.tap(find.byKey(const Key('result-p28')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nurseryCompare')), findsOneWidget);
  });

  testWidgets('US-07 AC-02 outside the house asks about the sun, not the window', (tester) async {
    await pumpMashtal(tester);
    go(tester, '/choose');
    await tester.pumpAndSettle();
    await answer(tester, 'city-riyadh');
    await answer(tester, 'spot-garden');
    expect(find.byKey(const Key('question-sun')), findsOneWidget);
    expect(find.byKey(const Key('question-window')), findsNothing);
  });

  testWidgets('US-08 skip opens Buy Plants from any question', (tester) async {
    await pumpMashtal(tester);
    go(tester, '/choose');
    await tester.pumpAndSettle();
    await answer(tester, 'city-riyadh');
    await tester.tap(find.byKey(const Key('skipQuestions')));
    await tester.pumpAndSettle();
    expect(location(tester), '/shop');
  });

  testWidgets('US-11 AC-01 a city without guide data is told it is not covered', (tester) async {
    await pumpMashtal(tester);
    go(tester, '/choose');
    await tester.pumpAndSettle();
    await answer(tester, 'city-jeddah');
    await answer(tester, 'spot-garden');
    await answer(tester, 'sun-lots');
    await answer(tester, 'space-lots');
    await answer(tester, 'watering-some');
    await answer(tester, 'kids-no');
    expect(find.byKey(const Key('notCovered')), findsOneWidget);
    expect(find.text('Your city is not covered yet'), findsOneWidget);
  });

  testWidgets('US-12 the nurseries sheet adds a nursery offer to the cart', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/choose');
    await tester.pumpAndSettle();
    await answer(tester, 'city-riyadh');
    await answer(tester, 'spot-inside');
    await answer(tester, 'window-little');
    await answer(tester, 'space-little');
    await answer(tester, 'watering-some');
    await answer(tester, 'kids-yes');
    await tester.tap(find.byKey(const Key('result-p28')));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const Key('nurseryCompare'));
    final add = find.descendant(of: sheet, matching: find.byIcon(Icons.add_shopping_cart)).first;
    await tester.tap(add);
    await tester.pumpAndSettle();
    // Adding keeps the sheet open (no jump to the nursery) and shows the count.
    expect(app.cartCount, 1);
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('1')), findsOneWidget);
    expect(location(tester), '/choose');
  });
}
