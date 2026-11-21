import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/ui/widgets/pickup_pass.dart';

import 'app_harness.dart';

/// US-18: the nursery's location and directions after reserving.
void main() {
  testWidgets('AC-01/02 an accepted reservation shows address, hours and directions', (tester) async {
    final opened = <Uri>[];
    openExternal = (uri) async {
      opened.add(uri);
      return true;
    };
    final app = await pumpMashtal(tester);
    late String accepted, pending;
    await tester.runAsync(() async {
      final b = app.backend;
      Future<void> as(String phone) async {
        await b.signOut();
        final otp = await b.sendCode(phone);
        await b.verifyCode(phone, otp.demoCode!);
      }

      await as('0500000005');
      accepted = (await b.reserve({'l1': 1})).single.id;
      pending = (await b.reserve({'l2': 1})).single.id;
      await as('0500000002');
      await b.acceptReservation(accepted);
      await b.signOut();
    });
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    go(tester, '/reservations');
    await tester.pumpAndSettle();

    expect(find.byKey(Key('pickupPass-$pending')), findsNothing, reason: 'only once the nursery accepts');
    expect(find.byKey(Key('pickupPass-$accepted')), findsOneWidget);
    expect(find.descendant(of: find.byKey(Key('pickupAddress-$accepted')), matching: find.textContaining('الروضة · Riyadh')), findsOneWidget);
    expect(find.descendant(of: find.byKey(Key('pickupHours-$accepted')), matching: find.textContaining('8:00–22:00')), findsOneWidget);
    expect(find.text('48 h left'), findsOneWidget);

    await tester.tap(find.byKey(Key('directions-$accepted')));
    await tester.pumpAndSettle();
    expect(opened.single.path, '/maps/dir/');
    expect(opened.single.queryParameters['destination'], '24.7376,46.7725');

    await tester.tap(find.byKey(Key('call-$accepted')));
    expect(opened.last.toString(), 'tel:0500000101');
  });

  testWidgets('the admin sets a nursery\'s map location by pasting a link', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000001');
    go(tester, '/admin/nurseries/edit/n2');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nurseryLocation')), 'not a place');
    await tester.tap(find.byKey(const Key('savePartner')));
    await tester.pumpAndSettle();
    expect(find.text('No coordinates found in this text'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('nurseryLocation')), 'https://www.google.com/maps/@24.81,46.62,17z');
    await tester.tap(find.byKey(const Key('savePartner')));
    await tester.pumpAndSettle();
    final n2 = app.backend.nurseryById('n2')!;
    expect((n2.lat, n2.lng), (24.81, 46.62));
  });
}
