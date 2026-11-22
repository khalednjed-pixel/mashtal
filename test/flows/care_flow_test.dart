import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

/// US-24: professionals with ratings and price ranges.
void main() {
  testWidgets('AC-01 the list for my city and a service shows rating, jobs and the admin range', (tester) async {
    await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    go(tester, '/garden');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('findProfessionals')));
    await tester.pumpAndSettle();
    expect(location(tester), '/garden/care');

    await tester.tap(find.byKey(const Key('service-pruning')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pro-pr1')), findsOneWidget);
    expect(find.byKey(const Key('pro-pr2')), findsOneWidget);
    expect(find.byKey(const Key('pro-pr5')), findsNothing, reason: 'pending');
    expect(find.byKey(const Key('pro-pr4')), findsNothing, reason: 'does not prune');
    expect(tester.widget<Text>(find.byKey(const Key('jobs-pr1'))).data, ' · 41 jobs done');
    expect(find.descendant(of: find.byKey(const Key('pro-pr1')), matching: find.text('4.7')), findsOneWidget);
    // The pruning range the admin set: 150–400.
    expect(tester.widget<Text>(find.byKey(const Key('range-pr1'))).data, '150 ⃁ – 400 ⃁');
    expect(find.byKey(const Key('priceBand')), findsOneWidget);
  });

  testWidgets('AC-02 a city nobody covers says so', (tester) async {
    await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    go(tester, '/garden/care?service=treatment&city=dammam');
    await tester.pumpAndSettle();
    expect(find.text('No professionals in your area yet'), findsOneWidget);
    expect(find.byKey(const Key('pro-pr4')), findsNothing);
  });

  testWidgets('the admin\'s new range shows at once', (tester) async {
    final app = await pumpMashtal(tester);
    await tester.runAsync(() async {
      final b = app.backend;
      final otp = await b.sendCode('0500000001');
      await b.verifyCode('0500000001', otp.demoCode!);
      await b.updatePriceRange(app.backend.priceRanges.first.service, min: 120, max: 350);
      await b.signOut();
    });
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    go(tester, '/garden/care?service=planting');
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('range-pr1'))).data, '120 ⃁ – 350 ⃁');
  });
}
