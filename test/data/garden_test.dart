import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/local_backend.dart';
import 'package:mashtal/data/repositories.dart';
import 'package:mashtal/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LocalBackend> signedIn(String phone, {LocalBackend? reuse, DateTime Function()? clock}) async {
  final b = reuse ?? await LocalBackend.open(random: Random(2), clock: clock);
  final otp = await b.sendCode(phone);
  await b.verifyCode(phone, otp.demoCode!);
  return b;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('US-21 My Garden', () {
    test('a customer adds a plant bought elsewhere; it is theirs only', () async {
      final b = await signedIn('0500000005');
      expect(b.garden, isEmpty);
      final g = await b.addToGarden('p04');
      expect(g.source, GardenSource.manual);
      expect(b.garden.single.plantId, 'p04');

      await b.signOut();
      await signedIn('0551112222', reuse: b);
      expect(b.garden, isEmpty, reason: 'another customer does not see it');
      await expectLater(b.markWatered(g.id), throwsA(isA<PermissionDenied>()));
      await expectLater(b.removeFromGarden(g.id), throwsA(isA<PermissionDenied>()));
    });

    test('only customers have a garden', () async {
      final nursery = await signedIn('0500000002');
      await expectLater(nursery.addToGarden('p04'), throwsA(isA<PermissionDenied>()));
      expect(nursery.garden, isEmpty);
      final guest = await LocalBackend.open();
      await expectLater(guest.addToGarden('p04'), throwsA(isA<PermissionDenied>()));
    });

    test('watering is recorded and the garden survives a restart', () async {
      var now = DateTime(2026, 11, 16, 9);
      final b = await signedIn('0500000005', clock: () => now);
      final g = await b.addToGarden('p16');
      now = now.add(const Duration(days: 2));
      await b.markWatered(g.id);
      expect(b.garden.single.lastWateredAt, now);

      final again = await signedIn('0500000005');
      expect(again.garden.single.lastWateredAt!.isAtSameMomentAs(now), isTrue);
      await again.removeFromGarden(g.id);
      expect(again.garden, isEmpty);
    });

    test('unknown plants cannot be added', () async {
      final b = await signedIn('0500000005');
      await expectLater(b.addToGarden('nope'), throwsArgumentError);
    });
  });
}
