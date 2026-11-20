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
}
