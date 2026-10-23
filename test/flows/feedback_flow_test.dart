import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/models/models.dart';
import 'package:mashtal/ui/nursery/new_plant_screen.dart';

import 'app_harness.dart';

/// Changes requested in the Sprint 1 review.
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

  testWidgets('the language button names the other language', (tester) async {
    await pumpMashtal(tester);
    expect(find.descendant(of: find.byKey(const Key('languageButton')), matching: find.text('العربية')), findsOneWidget);
    await tester.tap(find.byKey(const Key('languageButton')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('languageButton')), matching: find.text('English')), findsOneWidget);
  });

  testWidgets('the phone field accepts at most 10 digits', (tester) async {
    await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('phoneField')), '0500000005123');
    await tester.pump();
    expect(tester.widget<TextField>(find.byKey(const Key('phoneField'))).controller!.text, '0500000005');
  });

  testWidgets('each account keeps its own cart', (tester) async {
    final app = await pumpMashtal(tester);
    await signIn(tester, '0500000005');
    app.addToCart('l1');
    expect(app.cartCount, 1);
    await signOut(tester);
    expect(app.cartCount, 0);
    await signIn(tester, '0500000005');
    expect(app.cartCount, 1);
  });

  testWidgets('the admin opens Buy Plants and edits a price range', (tester) async {
    final app = await pumpMashtal(tester);
    await signIn(tester, '0500000001');
    go(tester, '/shop');
    await tester.pumpAndSettle();
    expect(location(tester), '/shop');
    expect(find.byKey(const Key('searchField')), findsOneWidget);

    go(tester, '/admin/professionals');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('range-planting')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rangeMin')), '120');
    await tester.enterText(find.byKey(const Key('rangeMax')), '350');
    await tester.tap(find.byKey(const Key('saveRange')));
    await tester.pumpAndSettle();
    final r = app.backend.priceRanges.firstWhere((r) => r.service == ServiceType.planting);
    expect([r.min, r.max], [120, 350]);
  });

  testWidgets('a nursery deletes a listing', (tester) async {
    final app = await pumpMashtal(tester);
    await signIn(tester, '0500000002');
    final listing = app.backend.listings.firstWhere((l) => l.nurseryId == 'n1');
    go(tester, '/nursery/listing/${listing.id}');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteListing')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDelete')));
    await tester.pumpAndSettle();
    expect(location(tester), '/nursery');
    expect(app.backend.listings.where((l) => l.id == listing.id), isEmpty);
  });

  testWidgets('a nursery adds a plant that is not in the list and lists it', (tester) async {
    final app = await pumpMashtal(tester);
    await signIn(tester, '0500000002');
    go(tester, '/nursery/listing/new');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickPlant')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addNewPlant')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('newPlantNameEn')), 'Test Fern');
    final form = find.byType(Scrollable).last;
    Future<void> tapKey(String key) async {
      await tester.scrollUntilVisible(find.byKey(Key(key)), 200, scrollable: form);
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    // Nothing is chosen by default, so saving straight away is refused.
    for (final key in ['category-shrub', 'placement-outdoor', 'sun-full', 'water-low']) {
      expect(tester.widget<FilterChip>(find.byKey(Key(key), skipOffstage: false)).selected, isFalse, reason: key);
    }
    await tapKey('saveNewPlant');
    expect(find.text('Complete the required fields'), findsOneWidget);
    expect(app.backend.plants.where((p) => p.nameEn == 'Test Fern'), isEmpty);
    ScaffoldMessenger.of(tester.element(find.byType(NewPlantScreen))).removeCurrentSnackBar();
    await tester.pumpAndSettle();

    for (final key in ['category-shrub', 'placement-outdoor', 'sun-full', 'water-low']) {
      await tapKey(key);
    }
    await tester.scrollUntilVisible(find.byKey(const Key('newPlantDays')), 200, scrollable: form);
    await tester.enterText(find.byKey(const Key('newPlantDays')), '7');
    await tapKey('saveNewPlant');
    expect(find.text('Test Fern'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('priceField')), '30');
    final listingForm = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.byKey(const Key('quantityField')), 200, scrollable: listingForm);
    await tester.enterText(find.byKey(const Key('quantityField')), '4');
    await tester.scrollUntilVisible(find.byKey(const Key('saveListing')), 200, scrollable: listingForm);
    await tester.tap(find.byKey(const Key('saveListing')));
    await tester.pumpAndSettle();
    final plant = app.backend.plants.firstWhere((p) => p.nameEn == 'Test Fern');
    expect(plant.guideBacked, isFalse);
    expect(app.backend.listings.where((l) => l.plantId == plant.id && l.nurseryId == 'n1'), hasLength(1));
  });

  testWidgets('a professional changes the services they offer', (tester) async {
    final app = await pumpMashtal(tester);
    await signIn(tester, '0500000004');
    expect(location(tester), '/pro');
    await tester.tap(find.byKey(const Key('service-treatment')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('saveProProfile')));
    await tester.tap(find.byKey(const Key('saveProProfile')));
    await tester.pumpAndSettle();
    expect(app.backend.professionals.firstWhere((p) => p.id == 'pr1').services, contains(ServiceType.treatment));
  });
}
