import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/accounts.dart';
import 'package:mashtal/data/local_backend.dart';
import 'package:mashtal/data/remote_store.dart';
import 'package:mashtal/data/repositories.dart';
import 'package:mashtal/models/models.dart';
import 'package:mashtal/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for Firebase: accounts by phone and one shared
/// database, so several "devices" (backends) can use it at once.
class FakeFirebase {
  final Map<String, Map<String, Map<String, dynamic>>> db = {};
  final Map<String, String> uidByPhone = {};
  final Map<String, PartnerAccount> partners = {};
  final Map<String, AppUser> profiles = {};
  bool offline = false;

  Map<String, Map<String, dynamic>> col(String name) => db.putIfAbsent(name, () => {});
}

class FakeDevice implements AccountService, RemoteStore {
  FakeDevice(this.fb);
  final FakeFirebase fb;
  String? _uid;
  void Function(String, List<Map<String, dynamic>>)? _onData;
  final List<RemoteWrite> sent = [];

  void _check() {
    if (fb.offline) throw StateError('offline');
  }

  @override
  Future<AppUser?> restore() async => _uid == null ? null : fb.profiles[_uid];

  @override
  Future<String> signIn(String phone) async {
    _check();
    return _uid = fb.uidByPhone.putIfAbsent(phone, () => 'uid-$phone');
  }

  @override
  Future<AppUser?> loadProfile(String uid) async => fb.profiles[uid];

  @override
  Future<PartnerAccount?> partnerAccount(String phone) async => fb.partners[phone];

  @override
  Future<void> saveProfile(AppUser user) async => fb.profiles[user.id] = user;

  @override
  Future<void> updateProfile(String uid, {required String name, required String city}) async =>
      fb.profiles[uid] = fb.profiles[uid]!.copyWith(name: name, city: city);

  @override
  Future<void> setPartnerAccount(String phone, Role role, String? partnerId) async =>
      fb.partners[phone] = PartnerAccount(role, partnerId);

  @override
  Future<void> removePartnerAccount(String phone) async => fb.partners.remove(phone);

  @override
  Future<void> signOut() async => _uid = null;

  @override
  void watch(AppUser? viewer, void Function(String collection, List<Map<String, dynamic>> docs) onData) {
    _onData = onData;
    _deliver();
  }

  void _deliver() {
    for (final c in ['plants', 'nurseries', 'professionals', 'listings', 'priceRanges', 'plantEdits']) {
      _onData?.call(c, [for (final e in fb.col(c).entries) {...e.value, 'id': e.key}]);
    }
  }

  @override
  Future<void> commit(List<RemoteWrite> writes) async {
    _check();
    sent.addAll(writes);
    for (final w in writes) {
      final data = w.data;
      if (data == null) {
        fb.col(w.collection).remove(w.id);
      } else {
        fb.col(w.collection)[w.id] = data;
      }
    }
  }

  /// Lets this device see changes made by others (the real store listens).
  void refresh() => _deliver();

  @override
  Future<bool> isSeeded() async => fb.col('meta').containsKey('seed');

  @override
  Future<void> markSeeded() async => fb.col('meta')['seed'] = {};

  @override
  void dispose() {}
}

Future<LocalBackend> device(FakeDevice d) =>
    LocalBackend.open(random: Random(1), accounts: d, remote: d);

Future<void> signIn(LocalBackend b, String phone) async {
  final otp = await b.sendCode(phone);
  final r = await b.verifyCode(phone, otp.demoCode!);
  if (r is NeedsProfile) await b.completeProfile(phone: phone, name: 'Test', city: 'riyadh');
}

void main() {
  late FakeFirebase fb;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fb = FakeFirebase();
    // Added by hand in the Firebase console (README).
    fb.partners['0500000001'] = const PartnerAccount(Role.admin, null);
  });

  test('online mode starts empty until the shared data arrives', () async {
    final b = await device(FakeDevice(fb));
    expect(b.isOnline, isTrue);
    expect(b.nurseries, isEmpty);
    expect(b.plants, hasLength(37), reason: 'guide plants ship with the app');
  });

  test('the admin\'s first sign-in uploads the demo data once', () async {
    final d = FakeDevice(fb);
    final admin = await device(d);
    await signIn(admin, '0500000001');
    expect(admin.currentUser!.role, Role.admin);
    expect(fb.col('nurseries'), hasLength(5));
    expect(fb.col('listings'), hasLength(43));
    expect(fb.col('plants'), hasLength(37));
    expect(fb.partners['0500000002']!.partnerId, 'n1');
    expect(fb.col('nurseries')['n1']!['status'], 'verified');
    expect(admin.nurseries, hasLength(5));

    final writes = d.sent.length;
    await admin.signOut();
    await signIn(admin, '0500000001');
    expect(d.sent.length, writes, reason: 'seeding happens only once');
  });

  test('a new number signs up as a customer and stays signed in', () async {
    final d = FakeDevice(fb);
    final b = await device(d);
    final otp = await b.sendCode('0551112222');
    expect(otp.demoCode, isNotNull, reason: 'the code is still shown on screen');
    expect(await b.verifyCode('0551112222', otp.demoCode!), isA<NeedsProfile>());
    final user = await b.completeProfile(phone: '0551112222', name: 'Noura', city: 'jeddah');
    expect(fb.profiles[user.id]!.role, Role.customer);

    final again = await LocalBackend.open(accounts: d, remote: d);
    expect(again.currentUser?.name, 'Noura');
  });

  test('a seeded nursery number signs in as that nursery and its listing is shared', () async {
    final admin = await device(FakeDevice(fb));
    await signIn(admin, '0500000001');

    final d = FakeDevice(fb);
    final nursery = await device(d);
    await signIn(nursery, '0500000002');
    expect(nursery.currentUser!.role, Role.nursery);
    expect(nursery.currentUser!.partnerId, 'n1');

    final l = await nursery.addListing(plantId: 'p05', price: 40, quantity: 2, photo: 'abc');
    expect(fb.col('listings')[l.id]!['public'], isTrue);
    expect(fb.col('listings')[l.id]!['photo'], 'abc');
    expect(fb.col('listings')[l.id]!.containsKey('id'), isFalse);

    final customer = await device(FakeDevice(fb));
    expect(customer.listings.map((x) => x.id), contains(l.id));
  });

  test('suspending a nursery unpublishes its listings', () async {
    final d = FakeDevice(fb);
    final admin = await device(d);
    await signIn(admin, '0500000001');
    await admin.setNurseryStatus('n1', PartnerStatus.suspended);
    final n1 = fb.col('listings').values.where((l) => l['nurseryId'] == 'n1');
    expect(n1, isNotEmpty);
    expect(n1.every((l) => l['public'] == false), isTrue);
  });

  test('the admin creates a nursery; its number then signs in as that nursery', () async {
    final admin = await device(FakeDevice(fb));
    await signIn(admin, '0500000001');
    final n = await admin.createNursery(const Nursery(
      id: '', nameAr: 'مشتل جديد', nameEn: 'New', city: 'riyadh', district: 'x', phone: '0557778888', hours: '9-5',
      status: PartnerStatus.verified,
    ));
    expect(fb.col('nurseries')[n.id]!['status'], 'pending');
    expect(fb.partners['0557778888']!.partnerId, n.id);

    final owner = await device(FakeDevice(fb));
    await signIn(owner, '0557778888');
    expect(owner.currentUser!.role, Role.nursery);
    expect(owner.currentUser!.name, 'مشتل جديد');

    await admin.deleteNursery(n.id);
    expect(fb.partners.containsKey('0557778888'), isFalse);
    expect(fb.col('nurseries').containsKey(n.id), isFalse);
  });

  test('admin plant edits and their log are shared', () async {
    final admin = await device(FakeDevice(fb));
    await signIn(admin, '0500000001');
    final p = admin.plantById('p01')!;
    await admin.updatePlant(p.copyWith(wateringEveryDays: p.wateringEveryDays + 1));
    expect(fb.col('plants')['p01']!['wateringEveryDays'], p.wateringEveryDays + 1);
    expect(fb.col('plantEdits'), hasLength(1));

    final other = await device(FakeDevice(fb));
    expect(other.plantById('p01')!.wateringEveryDays, p.wateringEveryDays + 1);
  });

  test('no connection shows a clear error on the sign-in screen', () async {
    final b = await device(FakeDevice(fb));
    final otp = await b.sendCode('0551112222');
    fb.offline = true;
    await expectLater(b.verifyCode('0551112222', otp.demoCode!),
        throwsA(isA<AuthException>().having((e) => e.code, 'code', 'network')));
  });

  test('online, the shared data cannot be reset from one phone', () async {
    final admin = await device(FakeDevice(fb));
    await signIn(admin, '0500000001');
    await admin.resetDemoData();
    expect(admin.currentUser, isNull);
    expect(fb.col('nurseries'), hasLength(5));
  });

  test('a saved cart is kept until the online stock has loaded', () async {
    SharedPreferences.setMockInitialValues({'flutter.mashtal.carts.v2': '{"guest":{"l1":2}}'});
    final d = _SlowDevice(fb);
    final app = await AppState.create(await device(d));
    expect(app.cart, {'l1': 2});
  });
}

/// A device whose data has not arrived yet.
class _SlowDevice extends FakeDevice {
  _SlowDevice(super.fb);

  @override
  void watch(AppUser? viewer, void Function(String collection, List<Map<String, dynamic>> docs) onData) {}
}
