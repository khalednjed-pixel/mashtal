import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/care_plan.dart' show paceStep, maxPace;
import '../logic/phone.dart';
import '../models/models.dart';
import 'accounts.dart';
import 'remote_store.dart';
import 'repositories.dart';
import 'seed/plants_seed.dart';
import 'seed/seed_data.dart';

/// Demo backend that keeps all data on the device (browser storage on the
/// web build). It enforces the same permissions as firestore.rules so the
/// app behaves the same once Firebase replaces it.
///
/// With an [AccountService] and a [RemoteStore] (TF-03), sign-in, profiles
/// and all shop data live in Firebase instead, shared by every device. The
/// rules below still run here first, and firestore.rules checks them again
/// on the server.
class LocalBackend extends ChangeNotifier implements AuthRepository, MarketRepository, ReservationRepository, GardenRepository {
  LocalBackend._(this._prefs, this._now, this._random, this._accounts, this._remote);

  static const _dbKey = 'mashtal.db.v1';
  static const _sessionKey = 'mashtal.session.v1';

  final SharedPreferences _prefs;
  final DateTime Function() _now;
  final Random _random;
  final AccountService? _accounts;
  final RemoteStore? _remote;

  /// True when data and accounts live in Firebase (shared by all devices).
  bool get isOnline => _remote != null;

  /// False until the online data has arrived once. Always true offline.
  bool get loaded => _remote == null || _listingsLoaded;
  bool _listingsLoaded = false;

  late List<AppUser> _users;
  late List<Nursery> _nurseries;
  late List<Professional> _professionals;
  late List<Listing> _listings;
  late List<PriceRange> _priceRanges;
  late List<Plant> _customPlants;

  /// Admin edits to knowledge-base plants, by plant id (US-14).
  late Map<String, Plant> _plantOverrides;
  late List<PlantEdit> _plantEdits;
  late List<Reservation> _reservations;
  late List<GardenPlant> _garden;
  late List<HistoryEntry> _history;
  AppUser? _currentUser;

  final Map<String, _PendingCode> _pending = {};

  static Future<LocalBackend> open({
    DateTime Function()? clock,
    Random? random,
    AccountService? accounts,
    RemoteStore? remote,
  }) async {
    assert(remote == null || accounts != null, 'Online data needs online accounts');
    final prefs = await SharedPreferences.getInstance();
    final backend = LocalBackend._(prefs, clock ?? DateTime.now, random ?? Random.secure(), accounts, remote);
    if (remote != null) {
      backend._clear();
    } else {
      backend._load();
    }
    if (accounts != null) {
      final user = await accounts.restore();
      if (user != null) backend._remember(user);
      backend._currentUser = user;
    }
    backend._watch();
    await backend._syncGarden();
    return backend;
  }

  @override
  void dispose() {
    _remote?.dispose();
    super.dispose();
  }

  /// Online mode starts empty and fills from the server.
  void _clear() {
    _users = [];
    _nurseries = [];
    _professionals = [];
    _listings = [];
    _priceRanges = [];
    _customPlants = [];
    _plantOverrides = {};
    _plantEdits = [];
    _reservations = [];
    _garden = [];
    _history = [];
  }

  void _watch() {
    _gardenLoaded = false;
    _reservationsLoaded = false;
    _remote?.watch(_currentUser, _onRemote);
  }

  static final _seedPlantIds = {for (final p in seedPlants) p.id};
  static final _seedById = {for (final p in seedPlants) p.id: p};

  /// The built-in record of knowledge-base plant [p] with the admin's edits
  /// (US-14) from [p] applied; null if [p] is not a knowledge-base plant.
  static Plant? _withSeed(Plant p) => _seedById[p.id]?.copyWith(
        placements: p.placements,
        sun: p.sun,
        water: p.water,
        wateringEveryDays: p.wateringEveryDays,
        toxic: p.toxic,
      );

  void _onRemote(String collection, List<Map<String, dynamic>> docs) {
    List<T> parse<T>(T Function(Map<String, dynamic>) fromJson) {
      final out = <T>[];
      for (final d in docs) {
        try {
          out.add(fromJson(d));
        } catch (e) {
          debugPrint('Skipped bad $collection/${d['id']}: $e');
        }
      }
      return out;
    }

    switch (collection) {
      case 'nurseries':
        _nurseries = parse(Nursery.fromJson);
      case 'professionals':
        _professionals = parse(Professional.fromJson);
      case 'listings':
        _listings = parse(Listing.fromJson);
        _listingsLoaded = true;
      case 'priceRanges':
        _priceRanges = parse(PriceRange.fromJson);
      case 'plants':
        final all = parse(Plant.fromJson);
        // A knowledge-base plant takes only the admin-editable fields from the
        // server (US-14); names, descriptions and its guide citation come from
        // the app, so a newer release corrects them without a data migration.
        _plantOverrides = {for (final p in all) p.id: ?_withSeed(p)};
        _customPlants = [for (final p in all) if (!_seedPlantIds.contains(p.id)) p];
      case 'reservations':
        _reservations = parse(Reservation.fromJson);
        _reservationsLoaded = true;
      case 'history':
        _history = parse(HistoryEntry.fromJson);
      case 'garden':
        _garden = parse(GardenPlant.fromJson);
        _gardenLoaded = true;
      case 'plantEdits':
        _plantEdits = parse(PlantEdit.fromJson)..sort((a, b) => a.at.compareTo(b.at));
      case 'users':
        final me = _currentUser;
        _users = parse((j) => AppUser.fromJson({...j, 'phone': localPhone(j['phone'] as String)}));
        if (me != null) _remember(me);
      default:
        return;
    }
    notifyListeners();
    if (collection == 'garden' || collection == 'reservations') _syncGarden();
  }

  bool _gardenLoaded = false;
  bool _reservationsLoaded = false;

  /// US-20: puts the plants of the signed-in customer's picked-up
  /// reservations into their garden. The nursery cannot write a customer's
  /// garden (firestore.rules), so the customer's own app adds them, with ids
  /// taken from the reservation line so that adding twice changes nothing.
  Future<void> _syncGarden() async {
    final me = _currentUser;
    if (me?.role != Role.customer) return;
    if (_remote != null && !(_gardenLoaded && _reservationsLoaded)) return;
    final have = {for (final g in _garden) g.id};
    final missing = [
      for (final r in _reservations)
        if (r.customerId == me!.id && r.status == ReservationStatus.pickedUp)
          for (final i in r.items)
            if (!have.contains(_pickupGardenId(r.id, i.listingId)))
              GardenPlant(
                id: _pickupGardenId(r.id, i.listingId),
                ownerId: me.id,
                plantId: i.plantId,
                addedAt: r.pickedUpAt ?? _now(),
                source: GardenSource.pickup,
                quantity: i.quantity,
                reservationId: r.id,
                nurseryId: r.nurseryId,
              ),
    ];
    if (missing.isEmpty) return;
    _garden.addAll(missing);
    try {
      await _push([for (final g in missing) _putGarden(g)]);
    } catch (e) {
      debugPrint('Could not add picked-up plants: $e');
    }
    await _save();
  }

  static String _pickupGardenId(String reservationId, String listingId) => 'g-$reservationId-$listingId';

  /// '+966500000001' or '0500000001' → '0500000001'.
  static String localPhone(String phone) => phone.startsWith('+966') ? '0${phone.substring(4)}' : phone;

  /// Sends changes to the server in online mode; does nothing offline.
  Future<void> _push(List<RemoteWrite> writes) async {
    final remote = _remote;
    if (remote == null || writes.isEmpty) return;
    await remote.commit(writes);
  }

  static Map<String, dynamic> _doc(Map<String, dynamic> json) => Map.of(json)..remove('id');

  RemoteWrite _putNursery(Nursery n) => RemoteWrite.put('nurseries', n.id, _doc(n.toJson()));
  RemoteWrite _putProfessional(Professional p) => RemoteWrite.put('professionals', p.id, _doc(p.toJson()));
  RemoteWrite _putPlant(Plant p) => RemoteWrite.put('plants', p.id, _doc(p.toJson()));

  /// `public` lets customers query listings without a join: shown when not
  /// hidden and the nursery is verified (see firestore.rules).
  RemoteWrite _putListing(Listing l, {List<Nursery>? nurseries}) {
    final nursery = (nurseries ?? _nurseries).where((n) => n.id == l.nurseryId).firstOrNull;
    return RemoteWrite.put('listings', l.id, {
      ..._doc(l.toJson()),
      'public': !l.hidden && nursery?.status == PartnerStatus.verified,
    });
  }

  /// Re-publishes a nursery's listings after its status changed.
  List<RemoteWrite> _listingsOf(String nurseryId) =>
      [for (final l in _listings) if (l.nurseryId == nurseryId) _putListing(l)];

  /// Uploads the demo data the first time the admin signs in online, so the
  /// shared database starts with the same nurseries, listings and accounts as
  /// the offline demo.
  Future<void> _seedOnline() async {
    final remote = _remote!;
    if (await remote.isSeeded()) return;
    // New partners must start pending (firestore.rules), so statuses follow.
    await remote.commit([
      for (final n in seedNurseries) _putNursery(n.copyWith(status: PartnerStatus.pending)),
      for (final p in seedProfessionals) _putProfessional(p.copyWith(status: PartnerStatus.pending)),
      for (final p in seedPlants) _putPlant(p),
      for (final r in seedPriceRanges) RemoteWrite.put('priceRanges', r.service.name, r.toJson()),
    ]);
    await remote.commit([
      for (final n in seedNurseries) if (n.status != PartnerStatus.pending) _putNursery(n),
      for (final p in seedProfessionals) if (p.status != PartnerStatus.pending) _putProfessional(p),
    ]);
    await remote.commit([for (final l in seedListings) _putListing(l, nurseries: seedNurseries)]);
    for (final u in seedUsers.where((u) => u.role == Role.nursery || u.role == Role.professional)) {
      await _accounts!.setPartnerAccount(u.phone, u.role, u.partnerId);
    }
    await remote.markSeeded();
  }

  /// Keeps the local copy of an account in step with the signed-in one, so
  /// partner look-ups by phone still work.
  void _remember(AppUser user) {
    _users.removeWhere((u) => u.phone == user.phone || u.id == user.id);
    _users.add(user);
  }

  void _load() {
    final raw = _prefs.getString(_dbKey);
    if (raw == null) {
      _seed();
    } else {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _users = _list(j['users'], AppUser.fromJson);
      _nurseries = _list(j['nurseries'], Nursery.fromJson);
      _professionals = _list(j['professionals'], Professional.fromJson);
      _listings = _list(j['listings'], Listing.fromJson);
      _priceRanges = _list(j['priceRanges'], PriceRange.fromJson);
      _customPlants = _list(j['customPlants'] ?? [], Plant.fromJson);
      _plantOverrides = {for (final p in _list(j['plantOverrides'] ?? [], Plant.fromJson)) p.id: ?_withSeed(p)};
      _plantEdits = _list(j['plantEdits'] ?? [], PlantEdit.fromJson);
      _reservations = _list(j['reservations'] ?? [], Reservation.fromJson);
      _garden = _list(j['garden'] ?? [], GardenPlant.fromJson);
      _history = _list(j['history'] ?? [], HistoryEntry.fromJson);
    }
    final sessionId = _accounts != null ? null : _prefs.getString(_sessionKey);
    _currentUser = sessionId == null ? null : _users.where((u) => u.id == sessionId).firstOrNull;
  }

  static List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) =>
      (raw as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();

  void _seed() {
    _users = [...seedUsers];
    _nurseries = [...seedNurseries];
    _professionals = [...seedProfessionals];
    _listings = [...seedListings];
    _priceRanges = [...seedPriceRanges];
    _customPlants = [];
    _plantOverrides = {};
    _plantEdits = [];
    _reservations = [];
    _garden = [];
    _history = [];
  }

  Future<void> _save() async {
    if (_remote != null) {
      notifyListeners();
      return;
    }
    final ok = await _prefs.setString(
      _dbKey,
      jsonEncode({
        'users': _users.map((e) => e.toJson()).toList(),
        'nurseries': _nurseries.map((e) => e.toJson()).toList(),
        'professionals': _professionals.map((e) => e.toJson()).toList(),
        'listings': _listings.map((e) => e.toJson()).toList(),
        'priceRanges': _priceRanges.map((e) => e.toJson()).toList(),
        'customPlants': _customPlants.map((e) => e.toJson()).toList(),
        'plantOverrides': _plantOverrides.values.map((e) => e.toJson()).toList(),
        'plantEdits': _plantEdits.map((e) => e.toJson()).toList(),
        'reservations': _reservations.map((e) => e.toJson()).toList(),
        'garden': _garden.map((e) => e.toJson()).toList(),
        'history': _history.map((e) => e.toJson()).toList(),
      }),
    ).catchError((_) => false);
    notifyListeners();
    // Browser storage is about 5 MB; photos are what fill it.
    if (!ok) throw const StorageFull();
  }

  /// Restores the seed data and signs out. Used from the account screen.
  /// Online, the shared data is left alone and only this device signs out.
  Future<void> resetDemoData() async {
    if (_remote != null) {
      _pending.clear();
      await signOut();
      return;
    }
    _seed();
    _pending.clear();
    await signOut();
    await _save();
  }

  String _newId(String prefix) => '$prefix${_now().microsecondsSinceEpoch}${_random.nextInt(1000)}';

  // ---------------------------------------------------------------- Auth

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<OtpRequest> sendCode(String phone) async {
    final local = SaudiPhone.normalize(phone);
    if (local == null) throw const AuthException('invalid-phone');
    final now = _now();
    final previous = _pending[local];
    if (previous != null) {
      final wait = AuthRepository.resendDelay - now.difference(previous.sentAt);
      if (wait > Duration.zero) throw AuthException('too-soon', retryAfter: wait);
    }
    final code = (_random.nextInt(900000) + 100000).toString();
    _pending[local] = _PendingCode(code, now);
    return OtpRequest(phone: local, sentAt: now, demoCode: code);
  }

  @override
  Future<VerifyResult> verifyCode(String phone, String code) async {
    final local = SaudiPhone.normalize(phone);
    final pending = local == null ? null : _pending[local];
    if (pending == null) throw const AuthException('no-code');
    if (_now().difference(pending.sentAt) > AuthRepository.codeLifetime) {
      throw const AuthException('code-expired');
    }
    if (pending.code != code.trim()) throw const AuthException('wrong-code');
    pending.verified = true;

    final accounts = _accounts;
    if (accounts != null) {
      final uid = await _online(() => accounts.signIn(local!));
      pending.uid = uid;
      var user = await _online(() => accounts.loadProfile(uid));
      final partner = await _online(() => accounts.partnerAccount(local!));
      if (user == null) {
        if (partner == null) return NeedsProfile(local!);
        // The admin made this number a partner (or the admin): no sign-up form.
        final known = _users.where((u) => u.phone == local).firstOrNull;
        user = AppUser(
          id: uid,
          phone: local!,
          name: known?.name ?? _partnerName(partner) ?? local,
          city: known?.city ?? 'riyadh',
          role: partner.role,
          partnerId: partner.partnerId,
        );
        await _online(() => accounts.saveProfile(user!));
      } else if (partner != null && (partner.role != user.role || partner.partnerId != user.partnerId)) {
        user = AppUser(id: uid, phone: user.phone, name: user.name, city: user.city, role: partner.role, partnerId: partner.partnerId);
        await _online(() => accounts.saveProfile(user!));
      }
      await _startSession(user);
      return SignedIn(user);
    }

    final existing = _users.where((u) => u.phone == local).firstOrNull;
    if (existing == null) return NeedsProfile(local!);
    await _startSession(existing);
    return SignedIn(existing);
  }

  @override
  Future<AppUser> completeProfile({required String phone, required String name, required String city}) async {
    final local = SaudiPhone.normalize(phone);
    final pending = local == null ? null : _pending[local];
    if (pending == null || !pending.verified) throw const AuthException('no-code');
    final accounts = _accounts;
    if (accounts != null) {
      final uid = pending.uid;
      if (uid == null) throw const AuthException('no-code');
      final user = AppUser(id: uid, phone: local!, name: name.trim(), city: city, role: Role.customer);
      await _online(() => accounts.saveProfile(user));
      await _startSession(user);
      return user;
    }
    final user = AppUser(id: _newId('u'), phone: local!, name: name.trim(), city: city, role: Role.customer);
    _users.add(user);
    await _startSession(user);
    return user;
  }

  Future<void> _startSession(AppUser user) async {
    _pending.remove(user.phone);
    _currentUser = user;
    if (_accounts != null) {
      _remember(user);
      if (user.role == Role.admin && _remote != null) await _online(_seedOnline);
      _watch();
    } else {
      await _prefs.setString(_sessionKey, user.id);
    }
    await _save();
    await _syncGarden();
  }

  String? _partnerName(PartnerAccount p) => switch (p.role) {
        Role.nursery => nurseryById(p.partnerId ?? '')?.nameAr,
        Role.professional => _professionals.where((x) => x.id == p.partnerId).firstOrNull?.nameAr,
        _ => null,
      };

  /// Runs a Firebase call, turning a failure into a message the sign-in
  /// screen can show.
  static Future<T> _online<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('Firebase: $e');
      throw const AuthException('network');
    }
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    if (_accounts != null) {
      await _accounts.signOut();
      _watch();
    } else {
      await _prefs.remove(_sessionKey);
    }
    notifyListeners();
  }

  @override
  Future<void> updateProfile({required String name, required String city}) async {
    final me = _currentUser;
    if (me == null) throw const PermissionDenied('updateProfile');
    if (name.trim().isEmpty) throw ArgumentError('name');
    final updated = me.copyWith(name: name.trim(), city: city);
    if (_accounts != null) await _accounts.updateProfile(me.id, name: updated.name, city: city);
    _users[_users.indexWhere((u) => u.id == me.id)] = updated;
    _currentUser = updated;
    await _save();
  }

  // -------------------------------------------------------------- Market

  @override
  List<Plant> get plants => [for (final p in seedPlants) _plantOverrides[p.id] ?? p, ..._customPlants];
  @override
  List<Nursery> get nurseries => List.unmodifiable(_nurseries);
  @override
  List<Professional> get professionals => List.unmodifiable(_professionals);
  @override
  List<Listing> get listings => List.unmodifiable(_listings);
  @override
  List<PriceRange> get priceRanges => List.unmodifiable(_priceRanges);

  @override
  Plant? plantById(String id) => plants.where((p) => p.id == id).firstOrNull;
  @override
  Nursery? nurseryById(String id) => _nurseries.where((n) => n.id == id).firstOrNull;

  void _require(Role role, String action) {
    if (_currentUser?.role != role) throw PermissionDenied(action);
  }

  @override
  Future<Nursery> createNursery(Nursery draft) async {
    _require(Role.admin, 'createNursery');
    // New partners always start as pending (US-03 AC-01).
    final n = Nursery(
      id: _newId('n'),
      nameAr: draft.nameAr,
      nameEn: draft.nameEn,
      city: draft.city,
      district: draft.district,
      phone: draft.phone,
      hours: draft.hours,
      status: PartnerStatus.pending,
      lat: draft.lat,
      lng: draft.lng,
    );
    _nurseries.add(n);
    // Give the nursery a sign-in account on its phone number.
    if (!_users.any((u) => u.phone == n.phone)) {
      _users.add(AppUser(id: _newId('u'), phone: n.phone, name: n.nameAr, city: n.city, role: Role.nursery, partnerId: n.id));
    }
    await _push([_putNursery(n)]);
    await _accounts?.setPartnerAccount(n.phone, Role.nursery, n.id);
    await _save();
    return n;
  }

  @override
  Future<void> updateNursery(Nursery nursery) async {
    _require(Role.admin, 'updateNursery');
    final i = _nurseries.indexWhere((n) => n.id == nursery.id);
    if (i < 0) return;
    final oldPhone = _nurseries[i].phone;
    _nurseries[i] = nursery;
    _relinkAccount(oldPhone, nursery.phone, nursery.id, Role.nursery, nursery.nameAr, nursery.city);
    await _push([_putNursery(nursery), ..._listingsOf(nursery.id)]);
    await _relinkOnline(oldPhone, nursery.phone, Role.nursery, nursery.id);
    await _save();
  }

  @override
  Future<void> deleteNursery(String nurseryId) async {
    _require(Role.admin, 'deleteNursery');
    final plantsBefore = _customPlants.map((p) => p.id).toSet();
    final listingsBefore = _listings.where((l) => l.nurseryId == nurseryId).map((l) => l.id).toList();
    final nurseryPhone = nurseryById(nurseryId)?.phone;
    _nurseries.removeWhere((n) => n.id == nurseryId);
    _listings.removeWhere((l) => l.nurseryId == nurseryId);
    _customPlants.removeWhere((p) => p.addedBy == nurseryId && !_listings.any((l) => l.plantId == p.id));
    final plantsAfter = _customPlants.map((p) => p.id).toSet();
    await _push([
      for (final id in listingsBefore) RemoteWrite.delete('listings', id),
      for (final id in plantsBefore.difference(plantsAfter)) RemoteWrite.delete('plants', id),
      RemoteWrite.delete('nurseries', nurseryId),
    ]);
    final phones = {
      ..._users.where((u) => u.partnerId == nurseryId).map((u) => u.phone),
      ?nurseryPhone,
    };
    _users.removeWhere((u) => u.partnerId == nurseryId);
    for (final p in phones) {
      await _accounts?.removePartnerAccount(p);
    }
    await _save();
  }

  Future<void> _relinkOnline(String oldPhone, String newPhone, Role role, String partnerId) async {
    final accounts = _accounts;
    if (accounts == null) return;
    if (oldPhone != newPhone) await accounts.removePartnerAccount(oldPhone);
    await accounts.setPartnerAccount(newPhone, role, partnerId);
  }

  /// Keeps the partner's sign-in account on the partner's phone number.
  void _relinkAccount(String oldPhone, String newPhone, String partnerId, Role role, String name, String city) {
    final i = _users.indexWhere((u) => u.partnerId == partnerId);
    if (i >= 0 && oldPhone != newPhone) {
      final u = _users[i];
      _users[i] = AppUser(id: u.id, phone: newPhone, name: u.name, city: city, role: role, partnerId: partnerId);
    } else if (i < 0 && !_users.any((u) => u.phone == newPhone)) {
      _users.add(AppUser(id: _newId('u'), phone: newPhone, name: name, city: city, role: role, partnerId: partnerId));
    }
  }

  @override
  Future<void> setNurseryStatus(String nurseryId, PartnerStatus status) async {
    _require(Role.admin, 'setNurseryStatus');
    final i = _nurseries.indexWhere((n) => n.id == nurseryId);
    if (i < 0) return;
    _nurseries[i] = _nurseries[i].copyWith(status: status);
    await _push([_putNursery(_nurseries[i]), ..._listingsOf(nurseryId)]);
    await _save();
  }

  @override
  Future<Professional> createProfessional(Professional draft) async {
    _require(Role.admin, 'createProfessional');
    final p = Professional(
      id: _newId('pr'),
      nameAr: draft.nameAr,
      nameEn: draft.nameEn,
      cities: draft.cities,
      services: draft.services,
      phone: draft.phone,
      status: PartnerStatus.pending,
    );
    _professionals.add(p);
    if (!_users.any((u) => u.phone == p.phone)) {
      _users.add(AppUser(id: _newId('u'), phone: p.phone, name: p.nameAr, city: p.cities.first, role: Role.professional, partnerId: p.id));
    }
    await _push([_putProfessional(p)]);
    await _accounts?.setPartnerAccount(p.phone, Role.professional, p.id);
    await _save();
    return p;
  }

  @override
  Future<void> updateProfessional(Professional professional) async {
    final me = _currentUser;
    final i = _professionals.indexWhere((p) => p.id == professional.id);
    if (i < 0) return;
    final old = _professionals[i];
    if (me?.role == Role.admin) {
      _professionals[i] = professional;
      _relinkAccount(old.phone, professional.phone, professional.id, Role.professional, professional.nameAr, professional.cities.first);
      await _relinkOnline(old.phone, professional.phone, Role.professional, professional.id);
    } else if (me?.role == Role.professional && me!.partnerId == professional.id) {
      // Professionals choose what they offer and where; the rest is the admin's.
      if (professional.services.isEmpty || professional.cities.isEmpty) throw ArgumentError('services');
      _professionals[i] = old.copyWith(services: professional.services, cities: professional.cities);
    } else {
      throw const PermissionDenied('updateProfessional');
    }
    await _push([_putProfessional(_professionals[i])]);
    await _save();
  }

  @override
  Future<void> deleteProfessional(String professionalId) async {
    _require(Role.admin, 'deleteProfessional');
    final proPhone = _professionals.where((p) => p.id == professionalId).firstOrNull?.phone;
    _professionals.removeWhere((p) => p.id == professionalId);
    await _push([RemoteWrite.delete('professionals', professionalId)]);
    final phones = {
      ..._users.where((u) => u.partnerId == professionalId).map((u) => u.phone),
      ?proPhone,
    };
    _users.removeWhere((u) => u.partnerId == professionalId);
    for (final p in phones) {
      await _accounts?.removePartnerAccount(p);
    }
    await _save();
  }

  @override
  Future<void> updatePriceRange(ServiceType service, {required double min, required double max}) async {
    _require(Role.admin, 'updatePriceRange');
    if (min <= 0 || min >= max) throw ArgumentError('range');
    final i = _priceRanges.indexWhere((r) => r.service == service);
    final range = PriceRange(service: service, min: min, max: max);
    if (i < 0) {
      _priceRanges.add(range);
    } else {
      _priceRanges[i] = range;
    }
    await _push([RemoteWrite.put('priceRanges', service.name, range.toJson())]);
    await _save();
  }

  @override
  Future<void> setProfessionalStatus(String professionalId, PartnerStatus status) async {
    _require(Role.admin, 'setProfessionalStatus');
    final i = _professionals.indexWhere((p) => p.id == professionalId);
    if (i < 0) return;
    _professionals[i] = _professionals[i].copyWith(status: status);
    await _push([_putProfessional(_professionals[i])]);
    await _save();
  }

  @override
  Future<Listing> addListing({required String plantId, required double price, required int quantity, String? photo}) async {
    _require(Role.nursery, 'addListing');
    final nurseryId = _currentUser!.partnerId!;
    if (plantById(plantId) == null) throw ArgumentError('Unknown plant $plantId');
    _validateListing(price, quantity);
    final l = Listing(id: _newId('l'), nurseryId: nurseryId, plantId: plantId, price: price, quantity: quantity, photo: photo);
    await _push([_putListing(l)]);
    _listings.add(l);
    await _save();
    return l;
  }

  @override
  Future<void> updateListing(Listing listing) async {
    _require(Role.nursery, 'updateListing');
    final i = _listings.indexWhere((l) => l.id == listing.id);
    // A nursery can only change its own listings, and not move them.
    if (i < 0 || _listings[i].nurseryId != _currentUser!.partnerId || listing.nurseryId != _currentUser!.partnerId) {
      throw const PermissionDenied('updateListing');
    }
    _validateListing(listing.price, listing.quantity);
    await _push([_putListing(listing)]);
    _listings[i] = listing;
    await _save();
  }

  @override
  Future<void> deleteListing(String listingId) async {
    _require(Role.nursery, 'deleteListing');
    final i = _listings.indexWhere((l) => l.id == listingId);
    if (i < 0) return;
    if (_listings[i].nurseryId != _currentUser!.partnerId) throw const PermissionDenied('deleteListing');
    await _push([RemoteWrite.delete('listings', listingId)]);
    _listings.removeAt(i);
    await _save();
  }

  @override
  Future<Plant> addPlant(Plant draft) async {
    _require(Role.nursery, 'addPlant');
    if (draft.nameAr.trim().isEmpty && draft.nameEn.trim().isEmpty) throw ArgumentError('name');
    final nursery = nurseryById(_currentUser!.partnerId!)!;
    final plant = Plant(
      id: _newId('c'),
      nameAr: draft.nameAr.trim().isEmpty ? draft.nameEn.trim() : draft.nameAr.trim(),
      nameEn: draft.nameEn.trim().isEmpty ? draft.nameAr.trim() : draft.nameEn.trim(),
      scientificName: draft.scientificName.trim(),
      category: draft.category,
      placements: draft.placements,
      sun: draft.sun,
      water: draft.water,
      wateringEveryDays: draft.wateringEveryDays,
      toxic: draft.toxic,
      descriptionAr: draft.descriptionAr.trim(),
      descriptionEn: draft.descriptionEn.trim(),
      source: 'Added by ${nursery.nameEn} — ${nursery.nameAr}',
      guideBacked: false,
      addedBy: nursery.id,
      photo: draft.photo,
    );
    await _push([_putPlant(plant)]);
    _customPlants.add(plant);
    await _save();
    return plant;
  }

  @override
  Future<void> deletePlant(String plantId) async {
    final plant = _customPlants.where((p) => p.id == plantId).firstOrNull;
    if (plant == null) throw const PermissionDenied('deletePlant');
    final me = _currentUser;
    final allowed = me?.role == Role.admin || (me?.role == Role.nursery && me!.partnerId == plant.addedBy);
    if (!allowed) throw const PermissionDenied('deletePlant');
    // A nursery can only remove its own listings; the admin removes all.
    await _push([
      for (final l in _listings)
        if (l.plantId == plantId && (me!.role == Role.admin || l.nurseryId == me.partnerId)) RemoteWrite.delete('listings', l.id),
      RemoteWrite.delete('plants', plantId),
    ]);
    _customPlants.remove(plant);
    _listings.removeWhere((l) => l.plantId == plantId);
    await _save();
  }

  @override
  Future<void> updatePlant(Plant plant) async {
    _require(Role.admin, 'updatePlant');
    final old = plantById(plant.id);
    if (old == null) throw ArgumentError('plant');
    if (plant.placements.isEmpty) throw ArgumentError('placements');
    if (plant.wateringEveryDays < 1 || plant.wateringEveryDays > 60) throw ArgumentError('wateringEveryDays');

    // Only the fields the admin may edit are taken from [plant].
    final updated = old.copyWith(
      placements: plant.placements,
      sun: plant.sun,
      water: plant.water,
      wateringEveryDays: plant.wateringEveryDays,
      toxic: plant.toxic,
    );
    String places(Plant p) => (p.placements.map((e) => e.name).toList()..sort()).join(', ');
    final changes = <(String, String, String)>[
      if (places(old) != places(updated)) ('placements', places(old), places(updated)),
      if (old.sun != updated.sun) ('sun', old.sun.name, updated.sun.name),
      if (old.water != updated.water) ('water', old.water.name, updated.water.name),
      if (old.wateringEveryDays != updated.wateringEveryDays)
        ('wateringEveryDays', '${old.wateringEveryDays}', '${updated.wateringEveryDays}'),
      if (old.toxic != updated.toxic) ('toxic', '${old.toxic}', '${updated.toxic}'),
    ];
    if (changes.isEmpty) return;

    final me = _currentUser!;
    final at = _now();
    final edits = <PlantEdit>[];
    for (final (field, before, after) in changes) {
      edits.add(PlantEdit(
        plantId: old.id,
        field: field,
        oldValue: before,
        newValue: after,
        editorId: me.id,
        editorName: me.name,
        at: at,
      ));
    }
    await _push([
      _putPlant(updated),
      for (final (n, e) in edits.indexed) RemoteWrite.put('plantEdits', '${_newId('e')}$n', e.toJson()),
    ]);
    _plantEdits.addAll(edits);
    final i = _customPlants.indexWhere((p) => p.id == old.id);
    if (i >= 0) {
      _customPlants[i] = updated;
    } else {
      _plantOverrides[old.id] = updated;
    }
    await _save();
  }

  @override
  List<PlantEdit> plantEditsFor(String plantId) =>
      _plantEdits.where((e) => e.plantId == plantId).toList().reversed.toList();

  // --------------------------------------------------------- Reservations

  @override
  List<Reservation> get reservations {
    final me = _currentUser;
    final mine = switch (me?.role) {
      Role.customer => _reservations.where((r) => r.customerId == me!.id),
      Role.nursery => _reservations.where((r) => r.nurseryId == me!.partnerId),
      Role.admin => _reservations,
      _ => const <Reservation>[],
    };
    return mine.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Reservation>> reserve(Map<String, int> cart) async {
    _require(Role.customer, 'reserve');
    final me = _currentUser!;
    final byNursery = <String, List<ReservationItem>>{};
    for (final MapEntry(key: listingId, value: qty) in cart.entries) {
      final l = _listings.where((l) => l.id == listingId).firstOrNull;
      if (l == null || !l.isAvailable || qty <= 0) continue;
      if (qty > l.quantity) throw ArgumentError('quantity');
      byNursery.putIfAbsent(l.nurseryId, () => []).add(
            ReservationItem(listingId: l.id, plantId: l.plantId, quantity: qty, price: l.price),
          );
    }
    final now = _now();
    final made = [
      for (final MapEntry(key: nurseryId, value: items) in byNursery.entries)
        Reservation(
          id: _newId('r'),
          customerId: me.id,
          customerName: me.name,
          customerPhone: me.phone,
          nurseryId: nurseryId,
          items: items,
          createdAt: now,
        ),
    ];
    await _push([for (final r in made) RemoteWrite.put('reservations', r.id, _doc(r.toJson()))]);
    _reservations.addAll(made);
    await _save();
    return made;
  }

  /// The signed-in nursery's own pending reservation [id].
  int _pendingFor(String id, String action) {
    _require(Role.nursery, action);
    final i = _reservations.indexWhere((r) => r.id == id);
    if (i < 0 || _reservations[i].nurseryId != _currentUser!.partnerId) throw PermissionDenied(action);
    if (_reservations[i].status != ReservationStatus.pending) throw StateError('Reservation is not pending');
    return i;
  }

  Future<void> _replaceReservation(int i, Reservation r) async {
    await _push([RemoteWrite.put('reservations', r.id, _doc(r.toJson()))]);
    _reservations[i] = r;
    await _save();
  }

  @override
  Future<void> acceptReservation(String id) async {
    final i = _pendingFor(id, 'acceptReservation');
    await _replaceReservation(i, _reservations[i].copyWith(status: ReservationStatus.accepted, acceptedAt: _now()));
  }

  @override
  Future<void> rejectReservation(String id, RejectReason reason) async {
    final i = _pendingFor(id, 'rejectReservation');
    await _replaceReservation(i, _reservations[i].copyWith(status: ReservationStatus.rejected, rejectReason: reason, rejectedAt: _now()));
  }

  // --------------------------------------------------------------- Garden

  @override
  List<GardenPlant> get garden {
    final me = _currentUser;
    if (me?.role != Role.customer) return const [];
    return _garden.where((g) => g.ownerId == me!.id && g.removedAt == null).toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  RemoteWrite _putGarden(GardenPlant g) => RemoteWrite.put('garden', g.id, _doc(g.toJson()));

  @override
  Future<GardenPlant> addToGarden(String plantId, {PlantHome? home}) async {
    _require(Role.customer, 'addToGarden');
    if (plantById(plantId) == null) throw ArgumentError('Unknown plant $plantId');
    final g = GardenPlant(
      id: _newId('g'),
      ownerId: _currentUser!.id,
      plantId: plantId,
      addedAt: _now(),
      source: GardenSource.manual,
      home: home,
    );
    await _push([_putGarden(g)]);
    _garden.add(g);
    await _save();
    return g;
  }

  /// Index of the signed-in customer's own garden plant [id].
  int _ownGarden(String id, String action) {
    _require(Role.customer, action);
    final i = _garden.indexWhere((g) => g.id == id);
    if (i < 0 || _garden[i].ownerId != _currentUser!.id) throw PermissionDenied(action);
    return i;
  }

  @override
  Future<void> markWatered(String gardenPlantId) async {
    final i = _ownGarden(gardenPlantId, 'markWatered');
    final g = _garden[i].copyWith(lastWateredAt: _now());
    final e = _entry(gardenPlantId, HistoryKind.watered);
    await _push([_putGarden(g), _putHistory(e)]);
    _garden[i] = g;
    _history.add(e);
    await _save();
  }

  @override
  Future<void> markStillMoist(String gardenPlantId) async {
    final i = _ownGarden(gardenPlantId, 'markStillMoist');
    final old = _garden[i];
    final g = old.copyWith(lastCheckedAt: _now(), pace: (old.pace * paceStep).clamp(1.0, maxPace));
    await _push([_putGarden(g)]);
    _garden[i] = g;
    await _save();
  }

  @override
  Future<void> setHome(String gardenPlantId, PlantHome home) async {
    final i = _ownGarden(gardenPlantId, 'setHome');
    final g = _garden[i].copyWith(home: home);
    await _push([_putGarden(g)]);
    _garden[i] = g;
    await _save();
  }

  RemoteWrite _putHistory(HistoryEntry e) => RemoteWrite.put('history', e.id, _doc(e.toJson()));

  HistoryEntry _entry(String gardenPlantId, HistoryKind kind, {String? text, String? photo}) => HistoryEntry(
        id: _newId('h'),
        ownerId: _currentUser!.id,
        gardenPlantId: gardenPlantId,
        kind: kind,
        at: _now(),
        text: text,
        photo: photo,
      );

  @override
  List<HistoryEntry> historyOf(String gardenPlantId) {
    final me = _currentUser;
    if (me == null) return const [];
    return _history.where((e) => e.gardenPlantId == gardenPlantId && e.ownerId == me.id).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
  }

  static const noteMaxLength = 280;

  @override
  Future<void> addNote(String gardenPlantId, String text) async {
    _ownGarden(gardenPlantId, 'addNote');
    final t = text.trim();
    if (t.isEmpty || t.length > noteMaxLength) throw ArgumentError('text');
    final e = _entry(gardenPlantId, HistoryKind.note, text: t);
    await _push([_putHistory(e)]);
    _history.add(e);
    await _save();
  }

  /// Largest growth photo kept, in base64 characters (well inside a
  /// Firestore document); the picker shrinks photos far below this.
  static const photoMaxLength = 400000;

  @override
  Future<void> addGrowthPhoto(String gardenPlantId, String photo) async {
    _ownGarden(gardenPlantId, 'addGrowthPhoto');
    if (photo.isEmpty || photo.length > photoMaxLength) throw ArgumentError('photo');
    final e = _entry(gardenPlantId, HistoryKind.photo, photo: photo);
    await _push([_putHistory(e)]);
    _history.add(e);
    await _save();
  }

  @override
  Future<void> removeFromGarden(String gardenPlantId) async {
    final i = _ownGarden(gardenPlantId, 'removeFromGarden');
    if (_garden[i].source == GardenSource.pickup) {
      final g = _garden[i].copyWith(removedAt: _now());
      await _push([_putGarden(g)]);
      _garden[i] = g;
    } else {
      await _push([RemoteWrite.delete('garden', gardenPlantId)]);
      _garden.removeAt(i);
    }
    await _save();
  }

  @override
  Future<void> markPickedUp(String id) async {
    _require(Role.nursery, 'markPickedUp');
    final i = _reservations.indexWhere((r) => r.id == id);
    if (i < 0 || _reservations[i].nurseryId != _currentUser!.partnerId) throw const PermissionDenied('markPickedUp');
    final r = _reservations[i];
    // AC-02: only a reservation the nursery accepted, still inside its hold.
    if (r.status != ReservationStatus.accepted) throw StateError('Reservation is not accepted');
    if (r.isExpired(_now())) throw StateError('Reservation hold has expired');
    await _replaceReservation(i, r.copyWith(status: ReservationStatus.pickedUp, pickedUpAt: _now()));
  }

  static void _validateListing(double price, int quantity) {
    if (price <= 0 || price > 100000) throw ArgumentError('price');
    if (quantity < 0 || quantity > 100000) throw ArgumentError('quantity');
  }
}

class _PendingCode {
  _PendingCode(this.code, this.sentAt);
  final String code;
  final DateTime sentAt;
  bool verified = false;

  /// The Firebase account the code unlocked, when accounts are online.
  String? uid;
}
