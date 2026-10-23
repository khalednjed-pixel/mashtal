import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/models/models.dart';

import 'app_harness.dart';

void main() {
  testWidgets('US-04 a nursery lands on its home and customer tabs are hidden', (tester) async {
    await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000002');
    expect(location(tester), '/nursery');
    expect(find.text('My listings'), findsWidgets);
    expect(find.text('Buy Plants'), findsNothing);
    expect(find.text('My Garden'), findsNothing);
  });

  testWidgets('US-04 a customer opening an admin route is denied and sent home', (tester) async {
    await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    go(tester, '/admin/nurseries');
    await tester.pumpAndSettle();
    expect(location(tester), '/shop');
    expect(find.text('You do not have access to that page'), findsOneWidget);
  });

  testWidgets('US-03 a pending nursery appears to customers only after the admin verifies it', (tester) async {
    final app = await pumpMashtal(tester);
    await tester.enterText(find.byKey(const Key('searchField')), 'Fajr');
    await tester.pumpAndSettle();
    expect(find.text('Al Fajr Nursery'), findsNothing);

    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000001');
    expect(location(tester), '/admin/nurseries');
    await tester.tap(find.byKey(const Key('verify-n5')));
    await tester.pumpAndSettle();
    expect(app.backend.nurseryById('n5')!.status, PartnerStatus.verified);

    go(tester, '/account');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signOut')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('searchField')), 'Fajr');
    await tester.pumpAndSettle();
    expect(find.text('Al Fajr Nursery'), findsOneWidget);
  });

  testWidgets('US-03 an admin adds a nursery and it starts as pending', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000001');
    await tester.tap(find.byKey(const Key('addPartner')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameAr')), 'مشتل التجربة');
    await tester.enterText(find.byKey(const Key('nameEn')), 'Trial Nursery');
    await tester.enterText(find.byKey(const Key('district')), 'العليا');
    await tester.enterText(find.byKey(const Key('partnerPhone')), '0557778888');
    await tester.tap(find.byKey(const Key('savePartner')));
    await tester.pumpAndSettle();
    expect(location(tester), '/admin/nurseries');
    final created = app.backend.nurseries.firstWhere((n) => n.nameEn == 'Trial Nursery');
    expect(created.status, PartnerStatus.pending);
  });

  testWidgets('US-06 a nursery adds a listing and customers can find it', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000002');

    await tester.tap(find.byKey(const Key('addListing')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickPlant')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plantPickerSearch')), 'athel');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Athel tamarisk'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('priceField')), '140');
    await tester.enterText(find.byKey(const Key('quantityField')), '6');
    await tester.tap(find.byKey(const Key('saveListing')));
    await tester.pumpAndSettle();

    expect(location(tester), '/nursery');
    final listing = app.backend.listings.firstWhere((l) => l.nurseryId == 'n1' && l.plantId == 'p05');
    expect(listing.price, 140);
    expect(listing.quantity, 6);
  });

  testWidgets('US-06 setting quantity to 0 shows the plant as not available', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000002');
    // n1 is the only nursery selling rosemary (p32, listing l9).
    go(tester, '/nursery/listing/l9');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quantityField')), '0');
    await tester.tap(find.byKey(const Key('saveListing')));
    await tester.pumpAndSettle();
    expect(app.backend.listings.firstWhere((l) => l.id == 'l9').quantity, 0);

    go(tester, '/account');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signOut')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('searchField')), 'rosemary');
    await tester.pumpAndSettle();
    expect(find.text('Rosemary'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
  });
}
