import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_backend.dart';
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
    _owner = _ownerFor(backend.currentUser);
    backend.addListener(_onBackendChanged);
  }

  static const _langKey = 'mashtal.lang';
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

  void _onBackendChanged() {
    // Drop cart lines whose listing was deleted.
    final ids = {for (final l in backend.listings) l.id};
    for (final c in _carts.values) {
      c.removeWhere((id, _) => !ids.contains(id));
    }
    final owner = _ownerFor(user);
    if (owner != _owner) {
      final guestCart = _carts.remove(_guest);
      if (_owner == _guest && owner != _guest && guestCart != null && user?.role == Role.customer) {
        final mine = _carts.putIfAbsent(owner, () => {});
        guestCart.forEach((id, q) => mine.update(id, (v) => v + q, ifAbsent: () => q));
      }
      _owner = owner;
      _saveCarts(notify: false);
    }
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

  void addToCart(String listingId) {
    _cart.update(listingId, (q) => q + 1, ifAbsent: () => 1);
    _saveCarts();
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

  // -------------------------------------------------------------- Notices

  /// A message key to show once as a snackbar, e.g. 'accessDenied'. Kept
  /// apart from [notifyListeners] so posting it does not re-run the router.
  final ValueNotifier<String?> notice = ValueNotifier(null);

  void postNotice(String key) => notice.value = key;
}
