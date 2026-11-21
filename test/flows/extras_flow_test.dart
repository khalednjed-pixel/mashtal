import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
