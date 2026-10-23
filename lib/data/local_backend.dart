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
  }

  Future<void> _save() async {
    await _prefs.setString(
      _dbKey,
      jsonEncode({
        'users': _users.map((e) => e.toJson()).toList(),
        'nurseries': _nurseries.map((e) => e.toJson()).toList(),
        'professionals': _professionals.map((e) => e.toJson()).toList(),
        'listings': _listings.map((e) => e.toJson()).toList(),
        'priceRanges': _priceRanges.map((e) => e.toJson()).toList(),
      }),
    );
    notifyListeners();
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

  // -------------------------------------------------------------- Market

  @override
  List<Plant> get plants => seedPlants;
  @override
  List<Nursery> get nurseries => List.unmodifiable(_nurseries);
  @override
  List<Professional> get professionals => List.unmodifiable(_professionals);
  @override
  List<Listing> get listings => List.unmodifiable(_listings);
  @override
  List<PriceRange> get priceRanges => List.unmodifiable(_priceRanges);

  @override
  Plant? plantById(String id) => seedPlants.where((p) => p.id == id).firstOrNull;
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
  Future<void> setProfessionalStatus(String professionalId, PartnerStatus status) async {
    _require(Role.admin, 'setProfessionalStatus');
    final i = _professionals.indexWhere((p) => p.id == professionalId);
    if (i < 0) return;
    _professionals[i] = _professionals[i].copyWith(status: status);
    await _save();
  }

  @override
  Future<Listing> addListing({required String plantId, required double price, required int quantity}) async {
    _require(Role.nursery, 'addListing');
    final nurseryId = _currentUser!.partnerId!;
    if (plantById(plantId) == null) throw ArgumentError('Unknown plant $plantId');
    _validateListing(price, quantity);
    final l = Listing(id: _newId('l'), nurseryId: nurseryId, plantId: plantId, price: price, quantity: quantity);
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
