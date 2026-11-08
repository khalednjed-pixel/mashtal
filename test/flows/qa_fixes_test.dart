import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/logic/phone.dart';
import 'package:mashtal/ui/widgets/common.dart';

import 'app_harness.dart';

/// Regression tests for the QA report of 2 Nov 2026 (BUG-1 to BUG-5, BUG-7).
void main() {
  Future<void> signIn(WidgetTester tester, String phone) async {
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, phone);
  }

  Future<void> signOut(WidgetTester tester) async {
    go(tester, '/account');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signOut')));
    await tester.pumpAndSettle();
  }

  // l15: Royal poinciana (p10) at the palm nursery (n2), price 240, stock 3.
  const listing = 'l15';

  testWidgets('BUG-1 the cart never holds more than the nursery has', (tester) async {
    final app = await pumpMashtal(tester);
    for (var i = 0; i < 5; i++) {
      app.addToCart(listing);
    }
    expect(app.cart[listing], 3);
    expect(app.addToCart(listing), isFalse);

    go(tester, '/cart');
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    final plus = tester.widget<IconButton>(find.byKey(const Key('increase-$listing')));
    expect(plus.onPressed, isNull);
    expect(find.text('720 \u20C1'), findsOneWidget); // Saudi riyal sign U+20C1
  });

  testWidgets('BUG-1 a cart line shrinks when the nursery lowers its stock', (tester) async {
    final app = await pumpMashtal(tester);
    await signIn(tester, '0500000005');
    for (var i = 0; i < 5; i++) {
      app.addToCart('l1');
    }
    app.addToCart('l2');
    await signOut(tester);

    // The nursery (n1) lowers l1 to 2 and sells out l2.
    await signIn(tester, '0500000002');
    final l1 = app.backend.listings.firstWhere((l) => l.id == 'l1');
    final l2 = app.backend.listings.firstWhere((l) => l.id == 'l2');
    await tester.runAsync(() async {
      await app.backend.updateListing(l1.copyWith(quantity: 2));
      await app.backend.updateListing(l2.copyWith(quantity: 0));
    });
    await signOut(tester);

    await signIn(tester, '0500000005');
    expect(app.cart, {'l1': 2});
  });

  testWidgets('BUG-2 the cart + and − buttons are named for screen readers', (tester) async {
    final app = await pumpMashtal(tester);
    app.addToCart('l1');
    go(tester, '/cart');
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(find.byKey(const Key('increase-l1'))).tooltip, 'Increase quantity');
    expect(tester.widget<IconButton>(find.byKey(const Key('decrease-l1'))).tooltip, 'Decrease quantity');
  });

  testWidgets('BUG-3 the search field keeps its name after typing', (tester) async {
    await pumpMashtal(tester);
    final handle = tester.ensureSemantics();
    await tester.enterText(find.byKey(const Key('searchField')), 'ZZ');
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('Search by plant or nursery name')),
      findsWidgets,
    );
    handle.dispose();
  });

  testWidgets('BUG-4 the Arabic plant page shows its source in Arabic', (tester) async {
    await pumpMashtal(tester, lang: 'ar');
    go(tester, '/shop/plant/p36');
    await tester.pumpAndSettle();
    expect(find.textContaining('Not in the Riyadh guide'), findsNothing);
    expect(find.textContaining('نبات منزلي شائع'), findsOneWidget);

    go(tester, '/shop/plant/p01');
    await tester.pumpAndSettle();
    expect(find.textContaining('الهيئة الملكية لمدينة الرياض'), findsOneWidget);
    expect(find.textContaining('RCRC'), findsNothing);
  });

  testWidgets('BUG-5 nursery and plant pages agree on a sold-out listing', (tester) async {
    await pumpMashtal(tester);
    // n3 × p36 (ZZ plant) has quantity 0: listed as not available on both.
    go(tester, '/shop/nursery/n3');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ZZ plant'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('ZZ plant'), findsOneWidget);
    expect(find.text('Not available'), findsWidgets);

    go(tester, '/shop/plant/p36');
    await tester.pumpAndSettle();
    expect(find.text('Not available'), findsWidgets);
    expect(find.byIcon(Icons.add_shopping_cart), findsNothing);
  });

  testWidgets('BUG-5 the shop card counts only nurseries that have the plant', (tester) async {
    await pumpMashtal(tester);
    await tester.enterText(find.byKey(const Key('searchField')), 'ZZ');
    await tester.pumpAndSettle();
    expect(find.textContaining('1 nursery'), findsNothing);
    expect(find.text('Not available'), findsOneWidget);
  });

  group('BUG-7 an international number can be pasted', () {
    String fmt(String s) =>
        SaudiPhoneInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: s)).text;

    test('formatter turns +966, 00966 and 966 into 05…', () {
      expect(fmt('+966500000005'), '0500000005');
      expect(fmt('00966 50 000 0005'), '0500000005');
      expect(fmt('966500000005'), '0500000005');
      expect(fmt('٠٥٠٠٠٠٠٠٠٥'), '0500000005');
      expect(fmt('05000000051234'), '0500000005');
      expect(SaudiPhone.normalize(fmt('+966500000005')), '0500000005');
    });

    testWidgets('pasting +966 in the sign-in field signs in', (tester) async {
      final app = await pumpMashtal(tester);
      go(tester, '/login');
      await tester.pumpAndSettle();
      await signInWithPhone(tester, '+966500000005');
      expect(app.user?.phone, '0500000005');
    });
  });
}
