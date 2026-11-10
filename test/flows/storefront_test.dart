import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/ui/widgets/plant_photo.dart';

import 'app_harness.dart';

/// The "+" quick add on the shop's product boxes and the swipeable photo
/// gallery on the plant page.
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

  final quickAdds = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('quickAdd-'));

  testWidgets('the + on a shop box adds the cheapest in-stock offer, the one the "from" price shows', (tester) async {
    final app = await pumpMashtal(tester);
    final market = app.backend;
    // Date palm: several verified nurseries sell it at different prices.
    final offers = [
      for (final l in market.listings)
        if (l.plantId == 'p04' && l.isAvailable && (market.nurseryById(l.nurseryId)?.isVerified ?? false)) l,
    ]..sort((a, b) => a.price.compareTo(b.price));
    expect(offers.length, greaterThan(1));
    final cheapest = offers.first;

    final plus = find.byKey(Key('quickAdd-${cheapest.id}'));
    expect(plus, findsOneWidget);
    await tester.ensureVisible(plus);
    await tester.pumpAndSettle();
    await tester.tap(plus);
    await tester.pumpAndSettle();

    expect(app.cart[cheapest.id], 1);
    expect(app.cartCount, 1);
    // Opening the box still goes to the plant page, not the cart.
    expect(location(tester), '/shop');
  });

  testWidgets('accounts that cannot buy see no + on the shop boxes', (tester) async {
    await pumpMashtal(tester);
    expect(quickAdds, findsWidgets);

    await signIn(tester, '0500000001'); // admin, previewing the shop
    go(tester, '/shop');
    await tester.pumpAndSettle();
    expect(location(tester), '/shop');
    // The admin's city filter keeps the category shelves; its boxes are there, without the +.
    expect(find.text('Palms'), findsOneWidget);
    expect(find.text('Date palm'), findsOneWidget);
    expect(quickAdds, findsNothing);
  });

  testWidgets('filters keep the category shelves; only a typed search shows the grid', (tester) async {
    await pumpMashtal(tester);
    expect(find.text('Palms'), findsOneWidget);

    await tester.tap(find.byKey(const Key('filtersButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Riyadh'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Riyadh'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('applyFilters')));
    await tester.tap(find.byKey(const Key('applyFilters')));
    await tester.pumpAndSettle();
    expect(find.text('Clear filters'), findsOneWidget);
    expect(find.text('Palms'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('searchField')), 'palm');
    await tester.pumpAndSettle();
    expect(find.text('Palms'), findsNothing);
    expect(find.text('Date palm'), findsOneWidget);
  });

  testWidgets('a nursery photo makes the plant photo swipeable; the licence credit stays with the Commons photo', (tester) async {
    final app = await pumpMashtal(tester);
    final market = app.backend;

    // Without nursery photos there is a single photo and nothing to swipe.
    go(tester, '/shop/plant/p04');
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsNothing);

    // Nursery n1 adds its own photo to its date palm listing.
    await signIn(tester, '0500000002');
    final listing = market.listings.firstWhere((l) => l.nurseryId == 'n1' && l.plantId == 'p04');
    const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
    await tester.runAsync(() => market.updateListing(listing.copyWith(photo: () => png)));
    await signOut(tester);

    go(tester, '/shop/plant/p04');
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(PhotoCredit), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    // The nursery's photo is its own, so the Commons credit is not shown on it.
    expect(find.byType(PhotoCredit), findsNothing);
    expect(app.backend.listings.firstWhere((l) => l.id == listing.id).photo, png);
  });
}
