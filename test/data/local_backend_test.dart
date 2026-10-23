import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/local_backend.dart';
import 'package:mashtal/data/repositories.dart';
import 'package:mashtal/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  late LocalBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 20, 10);
    backend = await LocalBackend.open(clock: () => now, random: Random(7));
  });

  Future<AppUser> signInAs(String phone) async {
    final req = await backend.sendCode(phone);
    final result = await backend.verifyCode(phone, req.demoCode!);
    return (result as SignedIn).user;
  }

  group('US-02 phone sign-up', () {
    test('a new number with the right code asks for name and city, then creates a customer', () async {
      final req = await backend.sendCode('0551234567');
      expect(req.demoCode, matches(RegExp(r'^\d{6}$')));
      final result = await backend.verifyCode('0551234567', req.demoCode!);
      expect(result, isA<NeedsProfile>());
      final user = await backend.completeProfile(phone: '0551234567', name: 'Khaled', city: 'riyadh');
      expect(user.role, Role.customer);
      expect(backend.currentUser?.id, user.id);
    });

    test('a wrong code is rejected', () async {
      final req = await backend.sendCode('0551234567');
      final wrong = req.demoCode == '000000' ? '111111' : '000000';
      expect(() => backend.verifyCode('0551234567', wrong),
          throwsA(isA<AuthException>().having((e) => e.code, 'code', 'wrong-code')));
      expect(backend.currentUser, isNull);
    });

    test('a new code can only be requested after 60 seconds', () async {
      await backend.sendCode('0551234567');
      now = now.add(const Duration(seconds: 30));
      expect(() => backend.sendCode('0551234567'),
          throwsA(isA<AuthException>().having((e) => e.code, 'code', 'too-soon')));
      now = now.add(const Duration(seconds: 31));
      expect(await backend.sendCode('0551234567'), isA<OtpRequest>());
    });

    test('codes expire after 5 minutes', () async {
      final req = await backend.sendCode('0551234567');
      now = now.add(const Duration(minutes: 6));
      expect(() => backend.verifyCode('0551234567', req.demoCode!),
          throwsA(isA<AuthException>().having((e) => e.code, 'code', 'code-expired')));
    });

    test('invalid numbers are rejected before sending', () async {
      expect(() => backend.sendCode('12345'), throwsA(isA<AuthException>().having((e) => e.code, 'code', 'invalid-phone')));
    });

    test('a profile cannot be created without a verified code', () async {
      expect(() => backend.completeProfile(phone: '0551234567', name: 'x', city: 'riyadh'), throwsA(isA<AuthException>()));
    });

    test('an existing number signs straight in with its role', () async {
      final user = await signInAs('0500000002');
      expect(user.role, Role.nursery);
      expect(user.partnerId, 'n1');
    });

    test('the session survives a restart', () async {
      await signInAs('0500000001');
      final reopened = await LocalBackend.open(clock: () => now);
      expect(reopened.currentUser?.role, Role.admin);
    });
  });

  group('US-03 admin verification', () {
    test('new partners start pending and the admin can verify them', () async {
      await signInAs('0500000001');
      final n = await backend.createNursery(const Nursery(
        id: '', nameAr: 'مشتل', nameEn: 'Test', city: 'riyadh', district: 'x', phone: '0559999999', hours: '', status: PartnerStatus.verified,
      ));
      expect(n.status, PartnerStatus.pending);
      await backend.setNurseryStatus(n.id, PartnerStatus.verified);
      expect(backend.nurseryById(n.id)!.status, PartnerStatus.verified);
    });

    test('the new nursery gets a sign-in account', () async {
      await signInAs('0500000001');
      final n = await backend.createNursery(const Nursery(
        id: '', nameAr: 'مشتل', nameEn: 'Test', city: 'riyadh', district: 'x', phone: '0559999999', hours: '', status: PartnerStatus.pending,
      ));
      await backend.signOut();
      final user = await signInAs('0559999999');
      expect(user.role, Role.nursery);
      expect(user.partnerId, n.id);
    });

    test('only the admin can change a status (NFR-05)', () async {
      await signInAs('0500000005');
      expect(() => backend.setNurseryStatus('n5', PartnerStatus.verified), throwsA(isA<PermissionDenied>()));
      expect(() => backend.setProfessionalStatus('pr5', PartnerStatus.verified), throwsA(isA<PermissionDenied>()));
      expect(backend.nurseryById('n5')!.status, PartnerStatus.pending);
    });
  });

  group('US-06 nursery listings', () {
    test('a nursery adds a listing for a plant from the plant list', () async {
      await signInAs('0500000002');
      final l = await backend.addListing(plantId: 'p05', price: 99, quantity: 3);
      expect(l.nurseryId, 'n1');
      expect(backend.listings.where((x) => x.id == l.id), hasLength(1));
    });

    test('unknown plants and bad values are rejected', () async {
      await signInAs('0500000002');
      expect(() => backend.addListing(plantId: 'nope', price: 10, quantity: 1), throwsArgumentError);
      expect(() => backend.addListing(plantId: 'p05', price: 0, quantity: 1), throwsArgumentError);
      expect(() => backend.addListing(plantId: 'p05', price: 10, quantity: -1), throwsArgumentError);
    });

    test('a nursery cannot edit another nursery\'s listing (NFR-05)', () async {
      await signInAs('0500000002');
      final other = backend.listings.firstWhere((l) => l.nurseryId == 'n2');
      expect(() => backend.updateListing(other.copyWith(price: 1)), throwsA(isA<PermissionDenied>()));
    });

    test('customers cannot add listings', () async {
      await signInAs('0500000005');
      expect(() => backend.addListing(plantId: 'p05', price: 10, quantity: 1), throwsA(isA<PermissionDenied>()));
    });
  });

  group('review feedback: edit and delete', () {
    test('the admin edits and deletes a nursery with its listings and account', () async {
      await signInAs('0500000001');
      await backend.updateNursery(backend.nurseryById('n2')!.copyWith(nameEn: 'Renamed'));
      expect(backend.nurseryById('n2')!.nameEn, 'Renamed');
      await backend.deleteNursery('n2');
      expect(backend.nurseryById('n2'), isNull);
      expect(backend.listings.where((l) => l.nurseryId == 'n2'), isEmpty);
    });

    test('the admin edits and deletes a professional', () async {
      await signInAs('0500000001');
      final pro = backend.professionals.firstWhere((p) => p.id == 'pr2');
      await backend.updateProfessional(pro.copyWith(nameEn: 'New name'));
      expect(backend.professionals.firstWhere((p) => p.id == 'pr2').nameEn, 'New name');
      await backend.deleteProfessional('pr2');
      expect(backend.professionals.where((p) => p.id == 'pr2'), isEmpty);
    });

    test('the admin edits a price range and bad ranges are rejected', () async {
      await signInAs('0500000001');
      await backend.updatePriceRange(ServiceType.pruning, min: 60, max: 300);
      final r = backend.priceRanges.firstWhere((r) => r.service == ServiceType.pruning);
      expect([r.min, r.max], [60, 300]);
      expect(() => backend.updatePriceRange(ServiceType.pruning, min: 300, max: 60), throwsArgumentError);
    });

    test('only the admin edits price ranges or deletes partners (NFR-05)', () async {
      await signInAs('0500000002');
      expect(() => backend.updatePriceRange(ServiceType.pruning, min: 1, max: 2), throwsA(isA<PermissionDenied>()));
      expect(() => backend.deleteNursery('n2'), throwsA(isA<PermissionDenied>()));
    });

    test('a nursery deletes its own listing but not another nursery\'s', () async {
      await signInAs('0500000002');
      final mine = backend.listings.firstWhere((l) => l.nurseryId == 'n1');
      await backend.deleteListing(mine.id);
      expect(backend.listings.where((l) => l.id == mine.id), isEmpty);
      final other = backend.listings.firstWhere((l) => l.nurseryId == 'n2');
      expect(() => backend.deleteListing(other.id), throwsA(isA<PermissionDenied>()));
    });

    test('a nursery adds a new plant, lists it with its own photo, then deletes it', () async {
      await signInAs('0500000002');
      final plant = await backend.addPlant(const Plant(
        id: '', nameAr: 'نبتة تجربة', nameEn: '', scientificName: '', category: PlantCategory.shrub,
        placements: {Placement.outdoor}, sun: Sun.full, water: Water.low, wateringEveryDays: 5, toxic: false,
        descriptionAr: '', descriptionEn: '', source: '',
      ));
      expect(plant.guideBacked, isFalse);
      expect(plant.addedBy, 'n1');
      expect(plant.nameEn, 'نبتة تجربة');
      final l = await backend.addListing(plantId: plant.id, price: 20, quantity: 2, photo: 'abc');
      expect(l.photo, 'abc');
      await backend.deletePlant(plant.id);
      expect(backend.plantById(plant.id), isNull);
      expect(backend.listings.where((x) => x.id == l.id), isEmpty);
    });

    test('guide plants cannot be deleted', () async {
      await signInAs('0500000001');
      expect(() => backend.deletePlant('p01'), throwsA(isA<PermissionDenied>()));
    });

    test('a professional changes only their own services and cities', () async {
      await signInAs('0500000004');
      final me = backend.professionals.firstWhere((p) => p.id == 'pr1');
      await backend.updateProfessional(me.copyWith(services: {ServiceType.treatment}, nameEn: 'Hacked'));
      final after = backend.professionals.firstWhere((p) => p.id == 'pr1');
      expect(after.services, {ServiceType.treatment});
      expect(after.nameEn, me.nameEn);
      final other = backend.professionals.firstWhere((p) => p.id == 'pr2');
      expect(() => backend.updateProfessional(other.copyWith(services: {ServiceType.treatment})), throwsA(isA<PermissionDenied>()));
    });

    test('a user updates their own name and city', () async {
      await signInAs('0500000005');
      await backend.updateProfile(name: 'Sara', city: 'jeddah');
      expect(backend.currentUser!.city, 'jeddah');
      expect(backend.currentUser!.name, 'Sara');
    });
  });

  test('reset restores the seed data and signs out', () async {
    await signInAs('0500000001');
    await backend.setNurseryStatus('n5', PartnerStatus.verified);
    await backend.resetDemoData();
    expect(backend.nurseryById('n5')!.status, PartnerStatus.pending);
    expect(backend.currentUser, isNull);
  });
}
