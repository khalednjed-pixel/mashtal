import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/phone.dart';
import '../models/models.dart';
import 'repositories.dart';
import 'seed/plants_seed.dart';
import 'seed/seed_data.dart';

/// Demo backend that keeps all data on the device (browser storage on the
/// web build). It enforces the same permissions as firestore.rules so the
/// app behaves the same once Firebase replaces it.
class LocalBackend extends ChangeNotifier implements AuthRepository, MarketRepository {
  LocalBackend._(this._prefs, this._now, this._random);

  static const _dbKey = 'mashtal.db.v1';
  static const _sessionKey = 'mashtal.session.v1';

  final SharedPreferences _prefs;
  final DateTime Function() _now;
  final Random _random;

  late List<AppUser> _users;
  late List<Nursery> _nurseries;
  late List<Professional> _professionals;
  late List<Listing> _listings;
  late List<PriceRange> _priceRanges;
  late List<Plant> _customPlants;
  AppUser? _currentUser;

  final Map<String, _PendingCode> _pending = {};

  static Future<LocalBackend> open({DateTime Function()? clock, Random? random}) async {
    final prefs = await SharedPreferences.getInstance();
    final backend = LocalBackend._(prefs, clock ?? DateTime.now, random ?? Random.secure());
    backend._load();
    return backend;
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
    }
    final sessionId = _prefs.getString(_sessionKey);
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
  }

  Future<void> _save() async {
    final ok = await _prefs.setString(
      _dbKey,
      jsonEncode({
        'users': _users.map((e) => e.toJson()).toList(),
        'nurseries': _nurseries.map((e) => e.toJson()).toList(),
        'professionals': _professionals.map((e) => e.toJson()).toList(),
        'listings': _listings.map((e) => e.toJson()).toList(),
        'priceRanges': _priceRanges.map((e) => e.toJson()).toList(),
        'customPlants': _customPlants.map((e) => e.toJson()).toList(),
      }),
    ).catchError((_) => false);
    notifyListeners();
    // Browser storage is about 5 MB; photos are what fill it.
    if (!ok) throw const StorageFull();
  }

  /// Restores the seed data and signs out. Used from the account screen.
  Future<void> resetDemoData() async {
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
    final user = AppUser(id: _newId('u'), phone: local!, name: name.trim(), city: city, role: Role.customer);
    _users.add(user);
    await _startSession(user);
    return user;
  }

  Future<void> _startSession(AppUser user) async {
    _pending.remove(user.phone);
    _currentUser = user;
    await _prefs.setString(_sessionKey, user.id);
    await _save();
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    await _prefs.remove(_sessionKey);
    notifyListeners();
  }

  @override
  Future<void> updateProfile({required String name, required String city}) async {
    final me = _currentUser;
    if (me == null) throw const PermissionDenied('updateProfile');
    if (name.trim().isEmpty) throw ArgumentError('name');
    final updated = me.copyWith(name: name.trim(), city: city);
    _users[_users.indexWhere((u) => u.id == me.id)] = updated;
    _currentUser = updated;
    await _save();
  }

  // -------------------------------------------------------------- Market

  @override
  List<Plant> get plants => [...seedPlants, ..._customPlants];
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
    );
    _nurseries.add(n);
    // Give the nursery a sign-in account on its phone number.
    if (!_users.any((u) => u.phone == n.phone)) {
      _users.add(AppUser(id: _newId('u'), phone: n.phone, name: n.nameAr, city: n.city, role: Role.nursery, partnerId: n.id));
    }
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
    await _save();
  }

  @override
  Future<void> deleteNursery(String nurseryId) async {
    _require(Role.admin, 'deleteNursery');
    _nurseries.removeWhere((n) => n.id == nurseryId);
    _listings.removeWhere((l) => l.nurseryId == nurseryId);
    _customPlants.removeWhere((p) => p.addedBy == nurseryId && !_listings.any((l) => l.plantId == p.id));
    _users.removeWhere((u) => u.partnerId == nurseryId);
    await _save();
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
    } else if (me?.role == Role.professional && me!.partnerId == professional.id) {
      // Professionals choose what they offer and where; the rest is the admin's.
      if (professional.services.isEmpty || professional.cities.isEmpty) throw ArgumentError('services');
      _professionals[i] = old.copyWith(services: professional.services, cities: professional.cities);
    } else {
      throw const PermissionDenied('updateProfessional');
    }
    await _save();
  }

  @override
  Future<void> deleteProfessional(String professionalId) async {
    _require(Role.admin, 'deleteProfessional');
    _professionals.removeWhere((p) => p.id == professionalId);
    _users.removeWhere((u) => u.partnerId == professionalId);
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
    await _save();
  }

  @override
  Future<void> setProfessionalStatus(String professionalId, PartnerStatus status) async {
    _require(Role.admin, 'setProfessionalStatus');
    final i = _professionals.indexWhere((p) => p.id == professionalId);
    if (i < 0) return;
    _professionals[i] = _professionals[i].copyWith(status: status);
    await _save();
  }

  @override
  Future<Listing> addListing({required String plantId, required double price, required int quantity, String? photo}) async {
    _require(Role.nursery, 'addListing');
    final nurseryId = _currentUser!.partnerId!;
    if (plantById(plantId) == null) throw ArgumentError('Unknown plant $plantId');
    _validateListing(price, quantity);
    final l = Listing(id: _newId('l'), nurseryId: nurseryId, plantId: plantId, price: price, quantity: quantity, photo: photo);
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
    _listings[i] = listing;
    await _save();
  }

  @override
  Future<void> deleteListing(String listingId) async {
    _require(Role.nursery, 'deleteListing');
    final i = _listings.indexWhere((l) => l.id == listingId);
    if (i < 0) return;
    if (_listings[i].nurseryId != _currentUser!.partnerId) throw const PermissionDenied('deleteListing');
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
    _customPlants.remove(plant);
    _listings.removeWhere((l) => l.plantId == plantId);
    await _save();
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
}
