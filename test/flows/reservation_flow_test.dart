import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/models/models.dart';

import 'app_harness.dart';

void main() {
  testWidgets('US-16 a customer reserves a cart from two nurseries', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    app.addToCart('l1');
    app.addToCart('l11');
    go(tester, '/cart');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reserve')));
    await tester.pumpAndSettle();

    expect(location(tester), '/reservations');
    expect(app.cartCount, 0, reason: 'AC-01 the cart empties');
    expect(app.backend.reservations, hasLength(2));
    expect(find.text('Waiting for the nursery'), findsNWidgets(2));
  });

  testWidgets('US-16 My reservations is in Account for customers only', (tester) async {
    await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    go(tester, '/account');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('myReservations')));
    await tester.pumpAndSettle();
    expect(location(tester), '/reservations');
    expect(find.text('No reservations yet'), findsOneWidget);
  });

  testWidgets('US-16 a nursery cannot open the customer reservations page', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000002');
    expect(app.role, Role.nursery);
    go(tester, '/reservations');
    await tester.pumpAndSettle();
    expect(location(tester), '/nursery');
  });

  testWidgets('US-17 the nursery accepts one request and rejects another with a reason', (tester) async {
    final app = await pumpMashtal(tester);
    late String first, second;
    await tester.runAsync(() async {
      final b = app.backend;
      final otp = await b.sendCode('0500000005');
      await b.verifyCode('0500000005', otp.demoCode!);
      first = (await b.reserve({'l1': 1})).single.id;
      second = (await b.reserve({'l2': 1})).single.id;
      await b.signOut();
    });
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000002');
    await tester.tap(find.text('Reservations'));
    await tester.pumpAndSettle();
    expect(location(tester), '/nursery/reservations');
    expect(find.text('Waiting for the nursery'), findsNWidgets(2));

    await tester.tap(find.byKey(Key('accept-$first')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('heldUntil-$first')), findsOneWidget);

    await tester.tap(find.byKey(Key('reject-$second')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reason-outOfStock')));
    await tester.pumpAndSettle();
    expect(find.text('Reason: Out of stock'), findsOneWidget);
    expect(find.byKey(Key('accept-$second')), findsNothing);
  });
}
