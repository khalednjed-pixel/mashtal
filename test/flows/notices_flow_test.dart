import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/models/models.dart';

import 'app_harness.dart';

/// US-19: in-app notices when a reservation is accepted or rejected.
void main() {
  testWidgets('the customer sees a banner, a count on Account and the list in Arabic or English', (tester) async {
    final app = await pumpMashtal(tester);
    late String yes, no;
    await tester.runAsync(() async {
      final b = app.backend;
      Future<void> as(String phone) async {
        await b.signOut();
        final otp = await b.sendCode(phone);
        await b.verifyCode(phone, otp.demoCode!);
      }

      await as('0500000005');
      yes = (await b.reserve({'l1': 1})).single.id;
      no = (await b.reserve({'l2': 1})).single.id;
      await as('0500000002');
      await b.acceptReservation(yes);
      await b.rejectReservation(no, RejectReason.outOfStock);
      await b.signOut();
    });
    // Signing in as the nursery above, while on the shop, left an
    // "access denied" message queued; it is not part of this test.
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();

    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    await tester.pump();
    // One banner for the newest, not one per notice.
    expect(find.byKey(const Key('noticeBanner')), findsOneWidget);
    expect(find.text('Al Rawdah Nursery declined your reservation'), findsOneWidget);
    expect(app.unseenCount(DateTime.now()), 2);

    go(tester, '/account');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unseenCount')), findsOneWidget);
    await tester.tap(find.byKey(const Key('notifications')));
    await tester.pumpAndSettle();
    expect(location(tester), '/notifications');
    expect(find.byKey(Key('notice-$yes:accepted')), findsOneWidget);
    expect(find.byKey(Key('notice-$no:rejected')), findsOneWidget);
    expect(find.text('Reason: Out of stock'), findsOneWidget);
    expect(find.byKey(Key('unseen-$yes:accepted')), findsOneWidget, reason: 'still marked while open');
    expect(app.unseenCount(DateTime.now()), 0, reason: 'opening the list marks them seen');

    // Seen notices are not announced again after signing in again.
    go(tester, '/account');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unseenCount')), findsNothing);
    await tester.tap(find.byKey(const Key('signOut')));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000005');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('noticeBanner')), findsNothing);
  });

  testWidgets('the notices read in Arabic', (tester) async {
    final app = await pumpMashtal(tester, lang: 'ar');
    await tester.runAsync(() async {
      final b = app.backend;
      final otp = await b.sendCode('0500000005');
      await b.verifyCode('0500000005', otp.demoCode!);
      final id = (await b.reserve({'l1': 1})).single.id;
      await b.signOut();
      final n = await b.sendCode('0500000002');
      await b.verifyCode('0500000002', n.demoCode!);
      await b.acceptReservation(id);
      await b.signOut();
      final c = await b.sendCode('0500000005');
      await b.verifyCode('0500000005', c.demoCode!);
    });
    go(tester, '/notifications');
    await tester.pumpAndSettle();
    expect(find.text('مشتل الروضة قبِل حجزك'), findsOneWidget);
  });

  testWidgets('partners get no reservation notices', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, '0500000002');
    expect(app.noticesAt(DateTime.now()), isEmpty);
    go(tester, '/notifications');
    await tester.pumpAndSettle();
    expect(location(tester), '/nursery');
  });
}
