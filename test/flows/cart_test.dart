import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/models/models.dart';

import 'app_harness.dart';

/// US-15: a cart across nurseries.
void main() {
  Future<void> signIn(WidgetTester tester, String phone) async {
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, phone);
  }

  // l1 and l2 are at Al Rawdah (n1): 180 and 220. l11 is at Green Palms (n2): 420.

  testWidgets('AC-01 items are grouped by nursery with subtotals and a separate-pickup note', (tester) async {
    final app = await pumpMashtal(tester);
    app.addToCart('l1');
    app.addToCart('l11');
    app.addToCart('l2');
    go(tester, '/cart');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stop-n1')), findsOneWidget);
    expect(find.byKey(const Key('stop-n2')), findsOneWidget);
    // Both Al Rawdah lines sit under its stop, though added apart.
    expect(find.descendant(of: find.byKey(const Key('stop-n1')), matching: find.byKey(const Key('cartLine-l2'))), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('stop-n2')), matching: find.byKey(const Key('cartLine-l11'))), findsOneWidget);
    expect(find.text('Pickup 1'), findsOneWidget);
    expect(find.text('Pickup 2'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('subtotal-n1'))).data, '400 ⃁');
    expect(tester.widget<Text>(find.byKey(const Key('subtotal-n2'))).data, '420 ⃁');
    expect(tester.widget<Text>(find.byKey(const Key('cartTotal'))).data, '820 ⃁');
    expect(find.textContaining('Each nursery is a separate pickup'), findsOneWidget);
  });

  testWidgets('a cart from one nursery shows the total once, with no pickup note', (tester) async {
    final app = await pumpMashtal(tester);
    app.addToCart('l1');
    go(tester, '/cart');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('subtotal-n1')), findsNothing);
    expect(find.byKey(const Key('separatePickups')), findsNothing);
    expect(find.text('180 ⃁'), findsOneWidget);
  });

  testWidgets('AC-02 an item that became unavailable is flagged and not reserved', (tester) async {
    final app = await pumpMashtal(tester);
    await signIn(tester, '0500000005');
    app.addToCart('l1');
    app.addToCart('l2');
    app.addToCart('l11');

    // Al Rawdah sells out l2 meanwhile.
    await tester.runAsync(() async {
      final b = app.backend;
      final me = b.currentUser!;
      await b.signOut();
      final otp = await b.sendCode('0500000002');
      await b.verifyCode('0500000002', otp.demoCode!);
      await b.updateListing(b.listings.firstWhere((l) => l.id == 'l2').copyWith(quantity: 0));
      await b.signOut();
      final again = await b.sendCode(me.phone);
      await b.verifyCode(me.phone, again.demoCode!);
    });
    go(tester, '/cart');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unavailable-l2')), findsOneWidget);
    expect(find.byKey(const Key('increase-l2')), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('subtotal-n1'))).data, '180 ⃁');
    expect(tester.widget<Text>(find.byKey(const Key('cartTotal'))).data, '600 ⃁');

    await tester.tap(find.byKey(const Key('reserve')));
    await tester.pumpAndSettle();
    final made = app.backend.reservations;
    expect(made, hasLength(2));
    expect(made.expand((r) => r.items).map((i) => i.listingId), isNot(contains('l2')));
    expect(made.every((r) => r.status == ReservationStatus.pending), isTrue);
    // The flagged line waits in the cart in case the nursery restocks.
    expect(app.cart, {'l2': 1});
  });

  testWidgets('a cart with only unavailable lines reserves nothing', (tester) async {
    final app = await pumpMashtal(tester);
    await signIn(tester, '0500000005');
    // l7 is listed but sold out, so it cannot be added at all.
    expect(app.addToCart('l7'), isFalse);
    expect(await app.reserveCart(), 0);
  });

  testWidgets('counts read naturally in Arabic, and an all-unavailable stop adds no subtotal', (tester) async {
    final app = await pumpMashtal(tester, lang: 'ar');
    app.addToCart('l1');
    app.addToCart('l11');
    go(tester, '/cart');
    await tester.pumpAndSettle();
    expect(find.textContaining('ستستلم من مشتلين'), findsOneWidget);
    expect(find.text('سيُرسل طلب حجز إلى كل من المشتلين'), findsOneWidget);
  });
}
