import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/models/models.dart';

import 'app_harness.dart';

/// US-20: the nursery marks a reservation picked up and the plants appear in
/// the customer's My Garden.
void main() {
  testWidgets('picked-up plants appear as cards in My Garden', (tester) async {
    final app = await pumpMashtal(tester);
    late String id;
    await tester.runAsync(() async {
      final b = app.backend;
      final otp = await b.sendCode('0500000005');
      await b.verifyCode('0500000005', otp.demoCode!);
      id = (await b.reserve({'l4': 1})).single.id; // l4: p12 at Al Rawdah
      await b.signOut();
    });
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000002');
    go(tester, '/nursery/reservations');
    await tester.pumpAndSettle();

    expect(find.byKey(Key('pickedUp-$id')), findsNothing, reason: 'not before it is accepted');
    await tester.tap(find.byKey(Key('accept-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('pickedUp-$id')));
    await tester.pumpAndSettle();
    expect(find.text('Has the customer collected the plants?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmPickedUp')));
    await tester.pumpAndSettle();
    expect(app.backend.reservations.single.status, ReservationStatus.pickedUp);
    expect(find.byKey(Key('pickedUp-$id')), findsNothing);

    go(tester, '/account');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signOut')));
    await tester.pumpAndSettle();
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');

    go(tester, '/reservations');
    await tester.pumpAndSettle();
    expect(find.byKey(Key('inGarden-$id')), findsOneWidget);
    await tester.tap(find.byKey(Key('openGarden-$id')));
    await tester.pumpAndSettle();
    expect(location(tester), '/garden');
    final g = app.backend.garden.single;
    expect(g.plantId, 'p12');
    expect(find.byKey(Key('garden-${g.id}')), findsOneWidget);
  });
}
