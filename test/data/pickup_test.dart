import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/local_backend.dart';
import 'package:mashtal/data/repositories.dart';
import 'package:mashtal/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// US-20: picked-up plants go to My Garden.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late DateTime now;
  late LocalBackend b;

  Future<void> as(String phone) async {
    await b.signOut();
    final otp = await b.sendCode(phone);
    await b.verifyCode(phone, otp.demoCode!);
  }

  /// The demo customer reserves l1 ×2 and l2 at Al Rawdah (n1).
  Future<String> reserved() async {
    now = DateTime(2026, 11, 20, 10);
    b = await LocalBackend.open(random: Random(4), clock: () => now);
    await as('0500000005');
    final id = (await b.reserve({'l1': 2, 'l2': 1})).single.id;
    await as('0500000002');
    return id;
  }

  test('AC-01 once the nursery marks it picked up, each plant is in the garden', () async {
    final id = await reserved();
    await b.acceptReservation(id);
    now = now.add(const Duration(hours: 5));
    await b.markPickedUp(id);
    expect(b.reservations.single.status, ReservationStatus.pickedUp);
    expect(b.reservations.single.pickedUpAt, now);

    await as('0500000005');
    final garden = b.garden;
    expect(garden.map((g) => g.plantId), unorderedEquals(['p01', 'p03']));
    expect(garden.firstWhere((g) => g.plantId == 'p01').quantity, 2);
    expect(garden.every((g) => g.source == GardenSource.pickup && g.nurseryId == 'n1' && g.reservationId == id), isTrue);

    // Signing in again adds nothing twice.
    await as('0500000005');
    expect(b.garden, hasLength(2));
  });

  test('AC-02 a reservation that was not accepted cannot be marked picked up', () async {
    final id = await reserved();
    await expectLater(b.markPickedUp(id), throwsStateError, reason: 'still pending');
    await b.rejectReservation(id, RejectReason.other);
    await expectLater(b.markPickedUp(id), throwsStateError, reason: 'rejected');
    expect(b.reservations.single.status, ReservationStatus.rejected);
  });

  test('AC-02 an accepted reservation whose 48-hour hold ran out cannot be either', () async {
    final id = await reserved();
    await b.acceptReservation(id);
    now = now.add(const Duration(hours: 49));
    await expectLater(b.markPickedUp(id), throwsStateError);
  });

  test('only that nursery marks it, and only once', () async {
    final id = await reserved();
    await b.acceptReservation(id);
    await as('0500000003'); // the other nursery
    await expectLater(b.markPickedUp(id), throwsA(isA<PermissionDenied>()));
    await as('0500000005');
    await expectLater(b.markPickedUp(id), throwsA(isA<PermissionDenied>()));
    await as('0500000002');
    await b.markPickedUp(id);
    await expectLater(b.markPickedUp(id), throwsStateError);
  });

  test('a picked-up plant the customer removes does not come back', () async {
    final id = await reserved();
    await b.acceptReservation(id);
    await b.markPickedUp(id);
    await as('0500000005');
    await b.removeFromGarden(b.garden.first.id);
    expect(b.garden, hasLength(1));
    await as('0500000005');
    expect(b.garden, hasLength(1));
  });
}
