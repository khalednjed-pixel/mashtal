import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_backend.dart';
import '../logic/notices.dart';
import '../models/models.dart';

/// App-wide UI state: language, carts and one-off notices.
///
/// Each account has its own cart. A guest's cart is moved into the account
/// they sign in to, so it survives sign-in (US-01 AC-02); signing out shows
/// an empty guest cart again.
class AppState extends ChangeNotifier {
  AppState._(this.backend, this._prefs) {
    _lang = _prefs.getString(_langKey) ?? 'ar';
    final raw = _prefs.getString(_cartsKey);
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in j.entries) {
        _carts[e.key] = Map<String, int>.from(e.value as Map);
      }
    }
    final seen = _prefs.getString(_seenKey);
    if (seen != null) {
      for (final e in (jsonDecode(seen) as Map<String, dynamic>).entries) {
        _seen[e.key] = {...List<String>.from(e.value as List)};
      }
    }
    _owner = _ownerFor(backend.currentUser);
    if (backend.loaded) _fitCartsToStock();
    backend.addListener(_onBackendChanged);
  }

  static const _langKey = 'mashtal.lang';
  static const _seenKey = 'mashtal.seenNotices.v1';
  static const _cartsKey = 'mashtal.carts.v2';
  static const _guest = 'guest';

  static Future<AppState> create(LocalBackend backend) async =>
      AppState._(backend, await SharedPreferences.getInstance());

  final LocalBackend backend;
  final SharedPreferences _prefs;

  late String _lang;
  final Map<String, Map<String, int>> _carts = {};
  late String _owner;

  String get lang => _lang;
  bool get isArabic => _lang == 'ar';

  AppUser? get user => backend.currentUser;
  Role? get role => user?.role;

  /// Guests and customers shop; partners and the admin do not have a cart.
  bool get canShop => role == null || role == Role.customer;

  static String _ownerFor(AppUser? u) => u?.id ?? _guest;

  /// Cart lines never ask for more than the nursery has (QA BUG-1): a line
  /// whose listing was deleted is dropped, and a line is capped at the
  /// listing's quantity. A line whose listing is hidden or sold out stays in
  /// the cart, flagged as unavailable and left out of the reservation
  /// (US-15 AC-02). Returns true if anything changed.
  bool _fitCartsToStock() {
    final byId = {for (final l in backend.listings) l.id: l};
    var changed = false;
    for (final c in _carts.values) {
      for (final id in c.keys.toList()) {
        final listing = byId[id];
        if (listing == null) {
          c.remove(id);
          changed = true;
        } else if (listing.isAvailable && c[id]! > listing.quantity) {
          c[id] = listing.quantity;
          changed = true;
        }
      }
    }
    return changed;
  }

  void _onBackendChanged() {
    final owner = _ownerFor(user);
    if (owner != _owner) {
      final guestCart = _carts.remove(_guest);
      if (_owner == _guest && owner != _guest && guestCart != null && user?.role == Role.customer) {
        final mine = _carts.putIfAbsent(owner, () => {});
        guestCart.forEach((id, q) => mine.update(id, (v) => v + q, ifAbsent: () => q));
      }
      _owner = owner;
    }
    // Online, stock is unknown until the first data arrives; carts wait.
    if (backend.loaded && _fitCartsToStock() && cart.isNotEmpty) cartAdjusted = true;
    _saveCarts(notify: false);
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    _lang = isArabic ? 'en' : 'ar';
    await _prefs.setString(_langKey, _lang);
    notifyListeners();
  }

  // ---------------------------------------------------------------- Cart

  Map<String, int> get _cart => _carts.putIfAbsent(_owner, () => {});
  Map<String, int> get cart => Map.unmodifiable(_carts[_owner] ?? const {});
  int get cartCount => cart.values.fold(0, (a, b) => a + b);

  /// Set when stock changes forced a cart line down; the cart screen shows
  /// it once and clears it.
  bool cartAdjusted = false;

  /// How many more of [listingId] can go in the cart (0 if none).
  int roomFor(String listingId) {
    final l = backend.listings.where((l) => l.id == listingId).firstOrNull;
    if (l == null || !l.isAvailable) return 0;
    return l.quantity - (_carts[_owner]?[listingId] ?? 0);
  }

  /// Adds one unit, up to the listing's quantity (QA BUG-1). Returns false
  /// and changes nothing when the cart already holds all the stock.
  bool addToCart(String listingId) {
    if (roomFor(listingId) <= 0) return false;
    _cart.update(listingId, (q) => q + 1, ifAbsent: () => 1);
    _saveCarts();
    return true;
  }

  void removeFromCart(String listingId, {bool all = false}) {
    final q = _cart[listingId];
    if (q == null) return;
    if (all || q <= 1) {
      _cart.remove(listingId);
    } else {
      _cart[listingId] = q - 1;
    }
    _saveCarts();
  }

  /// Whether the cart line [listingId] can be reserved now (US-15 AC-02).
  bool isReservable(String listingId) =>
      backend.listings.where((l) => l.id == listingId).firstOrNull?.isAvailable ?? false;

  /// The cart lines that can be reserved now: unavailable lines are left out.
  Map<String, int> get reservableCart => {
        for (final MapEntry(key: id, value: qty) in cart.entries)
          if (isReservable(id)) id: qty,
      };

  /// US-16: sends the reservable lines to the nurseries (one reservation
  /// each) and takes them out of the cart. Unavailable lines stay, flagged.
  /// Returns how many reservations were made.
  Future<int> reserveCart() async {
    final lines = reservableCart;
    if (lines.isEmpty) return 0;
    final made = await backend.reserve(lines);
    if (made.isNotEmpty) {
      lines.keys.forEach(_cart.remove);
      _saveCarts();
    }
    return made.length;
  }

  void _saveCarts({bool notify = true}) {
    _carts.removeWhere((_, c) => c.isEmpty);
    _prefs.setString(_cartsKey, jsonEncode(_carts));
    if (notify) notifyListeners();
  }

  Future<void> resetDemo() async {
    _carts.clear();
    await _prefs.remove(_cartsKey);
    await backend.resetDemoData();
  }

  // ------------------------------------------------- Reservation notices

  /// Notice ids each account has seen (US-19), kept on the device.
  final Map<String, Set<String>> _seen = {};

  /// The signed-in customer's reservation notices at [now], newest first.
  List<ReservationNotice> noticesAt(DateTime now) =>
      role == Role.customer ? reservationNotices(backend.reservations, now) : const [];

  bool isSeen(ReservationNotice n) => _seen[_owner]?.contains(n.id) ?? false;

  int unseenCount(DateTime now) => noticesAt(now).where((n) => !isSeen(n)).length;

  void markSeen(Iterable<ReservationNotice> notices) {
    final mine = _seen.putIfAbsent(_owner, () => {});
    if (!notices.any((n) => mine.add(n.id))) return;
    _prefs.setString(_seenKey, jsonEncode({for (final e in _seen.entries) e.key: e.value.toList()}));
    notifyListeners();
  }

  // -------------------------------------------------------------- Notices

  /// A message key to show once as a snackbar, e.g. 'accessDenied'. Kept
  /// apart from [notifyListeners] so posting it does not re-run the router.
  final ValueNotifier<String?> notice = ValueNotifier(null);

  void postNotice(String key) => notice.value = key;
}
