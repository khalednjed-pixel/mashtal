import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/models/models.dart';
import 'package:mashtal/ui/widgets/photo_picker.dart' show choosePhoto;
import 'package:mashtal/ui/widgets/pickup_pass.dart';

import 'app_harness.dart';

/// Saved plants, sharing a plant and care tips on a garden plant.
void main() {
  testWidgets('a guest saves a plant from the shop, finds it under Saved and keeps it after signing in', (tester) async {
    final app = await pumpMashtal(tester);
    await tester.tap(find.byKey(const Key('save-p04')).first);
    await tester.pumpAndSettle();
    expect(app.savedPlantIds, ['p04']);
    expect(find.text('Saved for later'), findsOneWidget);

    await tester.tap(find.byKey(const Key('openSaved')));
    await tester.pumpAndSettle();
    expect(location(tester), '/saved');
    expect(find.byKey(const Key('saved-p04')), findsOneWidget);
    expect(find.text('Date palm'), findsOneWidget);

    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    expect(app.savedPlantIds, ['p04'], reason: 'moves into the account, like the cart');

    go(tester, '/saved');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-p04')));
    await tester.pumpAndSettle();
    expect(app.savedPlantIds, isEmpty);
    expect(find.text('No saved plants yet'), findsOneWidget);
  });

  testWidgets('the plant page shares the plant on WhatsApp or as a copied link', (tester) async {
    final opened = <Uri>[];
    openExternal = (uri) async {
      opened.add(uri);
      return true;
    };
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpMashtal(tester);
    go(tester, '/shop/plant/p04');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sharePlant')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('sharePreview')), matching: find.textContaining('Date palm — from SAR')), findsOneWidget);

    await tester.tap(find.byKey(const Key('shareWhatsApp')));
    await tester.pumpAndSettle();
    expect(opened.single.host, 'wa.me');
    expect(opened.single.queryParameters['text'], contains('#/shop/plant/p04'));

    await tester.tap(find.byKey(const Key('sharePlant')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copyLink')));
    await tester.pumpAndSettle();
    expect(copied, contains('#/shop/plant/p04'));
    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets('a garden plant shows care tips that fit it', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    await tester.runAsync(() => app.backend.addToGarden('p04'));
    go(tester, '/garden/plant/${app.backend.garden.single.id}');
    await tester.pumpAndSettle();
    expect(find.text('Care tips'), findsOneWidget);
    expect(find.byKey(const Key('tip-light')), findsOneWidget);
    expect(find.byKey(const Key('tip-heat')), findsOneWidget, reason: 'a date palm grows outdoors');
    expect(find.byKey(const Key('tip-indoor')), findsNothing);
  });

  testWidgets('partners have no saved plants', (tester) async {
    await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000002');
    go(tester, '/saved');
    await tester.pumpAndSettle();
    expect(location(tester), isNot('/saved'));
  });

  testWidgets('the plant page waters by press and hold, says where it lives, and learns from "still moist"', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    await tester.runAsync(() => app.backend.addToGarden('p23'));
    final g = app.backend.garden.single;
    go(tester, '/garden/plant/${g.id}');
    await tester.pumpAndSettle();

    // A quick tap does not water.
    await tester.tap(find.byKey(const Key('waterNow')));
    await tester.pumpAndSettle();
    expect(app.backend.garden.single.lastWateredAt, isNull);

    await holdToWater(tester);
    expect(app.backend.garden.single.lastWateredAt, isNotNull);
    expect(app.backend.historyOf(g.id).where((e) => e.kind == HistoryKind.watered), hasLength(1));

    // Where it lives: our guess, changed in one tap.
    expect(find.textContaining('Big pot (Our pick)'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('changeHome')));
    await tester.tap(find.byKey(const Key('changeHome')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-smallPot')));
    await tester.pumpAndSettle();
    expect(app.backend.garden.single.home, PlantHome.smallPot);
    expect(find.textContaining('Small pot'), findsWidgets);
  });

  testWidgets('a plant that is due offers "the soil is still moist"', (tester) async {
    // The plant was added ten days ago and never watered, so it is due.
    var now = DateTime.now().subtract(const Duration(days: 10));
    final app = await pumpMashtal(tester, clock: () => now);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    await tester.runAsync(() => app.backend.addToGarden('p24', home: PlantHome.smallPot));
    now = DateTime.now();
    final g = app.backend.garden.single;
    go(tester, '/garden/plant/${g.id}');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('stillMoist')));
    await tester.tap(find.byKey(const Key('stillMoist')));
    await tester.pumpAndSettle();
    expect(app.backend.garden.single.pace, greaterThan(1));
    expect(find.textContaining("We'll remind you"), findsOneWidget);
  });

  testWidgets('going away: a plan for whoever waters, or what to do when nobody will, then away mode', (tester) async {
    final opened = <Uri>[];
    openExternal = (uri) async {
      opened.add(uri);
      return true;
    };
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    await tester.runAsync(() async {
      await app.backend.addToGarden('p23', home: PlantHome.smallPot);
      await app.backend.addToGarden('p03', home: PlantHome.ground);
    });
    go(tester, '/garden');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goingAway')));
    await tester.pumpAndSettle();
    expect(location(tester), '/garden/away');

    await tester.tap(find.byKey(const Key('away-14')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('helper-yes')));
    await tester.pumpAndSettle();
    // The plan lists every plant; it can be sent in English for a maid.
    expect(find.descendant(of: find.byKey(const Key('awayMessage')), matching: find.textContaining('Arabian jasmine (small pot)')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const Key('awayLang')), matching: find.text('العربية')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('awayMessage')), matching: find.textContaining('الفل (حوض صغير)')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('awaySendPlan')));
    await tester.tap(find.byKey(const Key('awaySendPlan')));
    await tester.pumpAndSettle();
    expect(opened.single.host, 'wa.me');

    // Nobody at home: the jasmine in a small pot will not last two weeks.
    await tester.ensureVisible(find.byKey(const Key('helper-no')));
    await tester.tap(find.byKey(const Key('helper-no')));
    await tester.pumpAndSettle();
    final jasmine = app.backend.garden.firstWhere((g) => g.plantId == 'p23');
    expect(find.byKey(Key('atRisk-${jasmine.id}')), findsOneWidget);

    // Scroll it to the middle, clear of the floating navigation bar.
    await tester.runAsync(() => Scrollable.ensureVisible(tester.element(find.byKey(const Key('awayStart'))), alignment: 0.5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('awayStart')));
    await tester.pumpAndSettle();
    expect(location(tester), '/garden');
    expect(app.awayTrip?.helper, isFalse);
    expect(find.byKey(const Key('awayPanel')), findsOneWidget);
    expect(find.byKey(const Key('todayPanel')), findsNothing);

    await tester.tap(find.byKey(const Key('awayBack')));
    await tester.pumpAndSettle();
    expect(app.awayTrip, isNull);
    expect(find.byKey(const Key('todayPanel')), findsOneWidget);
    expect(find.text('Check the soil of every plant today and water the dry ones.'), findsOneWidget);
  });

  testWidgets('growth photos: add from the plant page, then and now with two, and a calendar reminder', (tester) async {
    const pixel = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    choosePhoto = (_) async => pixel;
    final opened = <Uri>[];
    openExternal = (uri) async {
      opened.add(uri);
      return true;
    };
    var now = DateTime.now().subtract(const Duration(days: 30));
    final app = await pumpMashtal(tester, clock: () => now);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    late GardenPlant g;
    await tester.runAsync(() async {
      g = await app.backend.addToGarden('p23', home: PlantHome.bigPot);
      await app.backend.addGrowthPhoto(g.id, pixel);
    });
    now = DateTime.now();
    go(tester, '/garden/plant/${g.id}');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendarReminder')));
    await tester.pumpAndSettle();
    expect(opened.single.host, 'calendar.google.com');
    expect(opened.single.queryParameters['recur'], startsWith('RRULE:FREQ=DAILY;INTERVAL='));

    expect(find.byKey(const Key('thenAndNow')), findsNothing, reason: 'one photo so far');
    await tester.ensureVisible(find.byKey(const Key('addGrowthPhoto')));
    await tester.tap(find.byKey(const Key('addGrowthPhoto')));
    await tester.pumpAndSettle();
    expect(app.backend.historyOf(g.id).where((e) => e.kind == HistoryKind.photo), hasLength(2));
    expect(find.byKey(const Key('thenAndNow')), findsOneWidget);
    expect(find.text('30 days later'), findsOneWidget);
  });

  testWidgets('a nursery filters its listings by stock', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000002');
    final mine = app.backend.listings.where((l) => l.nurseryId == app.user!.partnerId).toList();
    final low = mine.firstWhere((l) => !l.hidden && l.quantity > 0 && l.quantity <= 5);
    final plenty = mine.firstWhere((l) => !l.hidden && l.quantity > 5);
    expect(find.byKey(Key('stock-${plenty.id}')), findsOneWidget);
    expect(find.descendant(of: find.byKey(Key('stock-${low.id}')), matching: find.text('Only ${low.quantity} left')), findsOneWidget);

    await tester.tap(find.byKey(const Key('filter-low')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('listing-${low.id}')), findsOneWidget);
    expect(find.byKey(Key('listing-${plenty.id}')), findsNothing);
  });

  testWidgets("the account page shows the customer's garden, saved plants and reservations", (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    await tester.runAsync(() => app.backend.addToGarden('p23'));
    app.toggleSaved('p04');
    go(tester, '/account');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('myReservations')), findsOneWidget);
    expect(find.byKey(const Key('savedPlants')), findsOneWidget);
    await tester.tap(find.text('Saved').first);
    await tester.pumpAndSettle();
    expect(location(tester), '/saved');
  });
}
