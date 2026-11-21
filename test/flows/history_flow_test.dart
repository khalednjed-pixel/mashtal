import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

/// US-22: opening a garden plant shows its history.
void main() {
  testWidgets('a garden plant opens on its watering and its history, newest first', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    await tester.runAsync(() => app.backend.addToGarden('p16'));
    final g = app.backend.garden.single;
    go(tester, '/garden');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bougainvillea'));
    await tester.pumpAndSettle();
    expect(location(tester), '/garden/plant/${g.id}');
    expect(find.text('Plant history'), findsOneWidget);
    expect(find.text('Added to My Garden'), findsOneWidget);

    await holdToWater(tester);
    // The care tips sit above the history, so scroll down to it.
    await tester.ensureVisible(find.byKey(const Key('addNote')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addNote')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('noteField')), 'Moved it to the balcony');
    await tester.tap(find.byKey(const Key('saveNote')));
    await tester.pumpAndSettle();

    final titles = tester.widgetList<Text>(find.byWidgetPredicate((w) => w is Text && ['Note', 'Watered', 'Added to My Garden'].contains(w.data)));
    expect(titles.map((t) => t.data), ['Note', 'Watered', 'Added to My Garden']);
    expect(find.text('Moved it to the balcony'), findsOneWidget);
    expect(find.textContaining('You · '), findsNWidgets(3));
  });

  testWidgets('a plant can be removed from the garden after confirming', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    await tester.runAsync(() => app.backend.addToGarden('p16'));
    go(tester, '/garden/plant/${app.backend.garden.single.id}');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('removeFromGarden')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmRemoveFromGarden')));
    await tester.pumpAndSettle();
    expect(location(tester), '/garden');
    expect(app.backend.garden, isEmpty);
  });
}
