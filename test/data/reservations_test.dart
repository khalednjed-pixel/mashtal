import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/local_backend.dart';
import 'package:mashtal/data/repositories.dart';
import 'package:mashtal/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LocalBackend> signedIn(String phone, {LocalBackend? reuse}) async {
  final b = reuse ?? await LocalBackend.open(random: Random(2));
  final otp = await b.sendCode(phone);
  await b.verifyCode(phone, otp.demoCode!);
  return b;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('US-16 reserve the cart', () {
    test('AC-01 one pending reservation per nursery, at the listed prices', () async {
      final b = await signedIn('0500000005');
      final made = await b.reserve({'l1': 2, 'l2': 1, 'l11': 1});
      expect(made, hasLength(2));
      final n1 = made.firstWhere((r) => r.nurseryId == 'n1');
      final n2 = made.firstWhere((r) => r.nurseryId == 'n2');
      expect(n1.items.map((i) => i.listingId), ['l1', 'l2']);
      expect(n1.total, 180 * 2 + 220);
      expect(n2.items.single.plantId, 'p04');
      expect(made.every((r) => r.status == ReservationStatus.pending), isTrue);
      expect(n1.customerPhone, '0500000005');
      expect(b.reservations, hasLength(2));
    });

    test('unavailable lines are left out; an empty result makes nothing', () async {
      final b = await signedIn('0500000005');
      // l7 is sold out (quantity 0).
      expect(await b.reserve({'l7': 1}), isEmpty);
      expect(await b.reserve({'l7': 1, 'l1': 1}), hasLength(1));
    });

    test('only customers reserve, and not more than the stock', () async {
      final nursery = await signedIn('0500000002');
      await expectLater(nursery.reserve({'l11': 1}), throwsA(isA<PermissionDenied>()));
      final guest = await LocalBackend.open();
      await expectLater(guest.reserve({'l1': 1}), throwsA(isA<PermissionDenied>()));
      final customer = await signedIn('0500000005');
      await expectLater(customer.reserve({'l1': 13}), throwsArgumentError);
    });

    test('each customer sees only their own reservations; they survive a restart', () async {
      final b = await signedIn('0500000005');
      await b.reserve({'l1': 1});
      await b.signOut();
      await signedIn('0551112222', reuse: b);
      expect(b.reservations, isEmpty);

      final again = await signedIn('0500000005');
      expect(again.reservations, hasLength(1));
    });

    test('AC-02 an accepted reservation is held for 48 hours from acceptance', () {
      final accepted = DateTime.utc(2026, 11, 20, 10);
      final r = Reservation(
        id: 'r1', customerId: 'u', customerName: 'S', customerPhone: '0500000005', nurseryId: 'n1',
        items: const [ReservationItem(listingId: 'l1', plantId: 'p01', quantity: 1, price: 180)],
        createdAt: DateTime.utc(2026, 11, 20, 9),
      ).copyWith(status: ReservationStatus.accepted, acceptedAt: accepted);
      expect(r.expiresAt, DateTime.utc(2026, 11, 22, 10));
      expect(r.isExpired(DateTime.utc(2026, 11, 22, 9)), isFalse);
      expect(r.isExpired(DateTime.utc(2026, 11, 22, 11)), isTrue);
      expect(Reservation.fromJson(r.toJson()).expiresAt, r.expiresAt);
    });
  });

  group('US-17 nursery accepts or rejects', () {
    Future<(LocalBackend, String)> pendingAtN1() async {
      final b = await signedIn('0500000005');
      final r = (await b.reserve({'l1': 1})).single;
      await b.signOut();
      await signedIn('0500000002', reuse: b);
      return (b, r.id);
    }

    test('the nursery sees reservations sent to it', () async {
      final (b, id) = await pendingAtN1();
      expect(b.reservations.single.id, id);
      await b.signOut();
      await signedIn('0500000003', reuse: b);
      expect(b.reservations, isEmpty, reason: 'another nursery sees nothing');
    });

    test('AC-01 accepting starts the 48-hour hold', () async {
      final now = DateTime.utc(2026, 11, 17, 12);
      SharedPreferences.setMockInitialValues({});
      final b = await LocalBackend.open(clock: () => now, random: Random(2));
      await signedIn('0500000005', reuse: b);
      final r = (await b.reserve({'l1': 1})).single;
      await b.signOut();
      await signedIn('0500000002', reuse: b);
      await b.acceptReservation(r.id);
      final accepted = b.reservations.single;
      expect(accepted.status, ReservationStatus.accepted);
      expect(accepted.acceptedAt, now);
      expect(accepted.expiresAt, now.add(const Duration(hours: 48)));

      // The customer sees it accepted with its expiry (US-16 AC-02).
      await b.signOut();
      await signedIn('0500000005', reuse: b);
      expect(b.reservations.single.expiresAt, now.add(const Duration(hours: 48)));
    });

    test('AC-02 rejecting with a reason; the customer sees the reason', () async {
      final (b, id) = await pendingAtN1();
      await b.rejectReservation(id, RejectReason.outOfStock);
      await b.signOut();
      await signedIn('0500000005', reuse: b);
      final r = b.reservations.single;
      expect(r.status, ReservationStatus.rejected);
      expect(r.rejectReason, RejectReason.outOfStock);
    });

    test('only that nursery, and only while pending', () async {
      final (b, id) = await pendingAtN1();
      await b.acceptReservation(id);
      expect(() => b.rejectReservation(id, RejectReason.other), throwsStateError);
      await b.signOut();
      await signedIn('0500000003', reuse: b);
      expect(() => b.acceptReservation(id), throwsA(isA<PermissionDenied>()));
      await b.signOut();
      await signedIn('0500000005', reuse: b);
      expect(() => b.acceptReservation(id), throwsA(isA<PermissionDenied>()));
    });
  });
}
