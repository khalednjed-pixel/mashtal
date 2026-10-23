import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_backend.dart';
import '../models/models.dart';

/// App-wide UI state: language, the guest/customer cart and one-off notices.
///
/// The cart lives here, not on the account, so a guest keeps it through
/// sign-in (US-01 AC-02).
class AppState extends ChangeNotifier {
  AppState._(this.backend, this._prefs) {
    _lang = _prefs.getString(_langKey) ?? 'ar';
    final rawCart = _prefs.getString(_cartKey);
    if (rawCart != null) {
      _cart.addAll(Map<String, int>.from(jsonDecode(rawCart) as Map));
    }
    backend.addListener(notifyListeners);
  }

  static const _langKey = 'mashtal.lang';
  static const _cartKey = 'mashtal.cart';

  static Future<AppState> create(LocalBackend backend) async =>
      AppState._(backend, await SharedPreferences.getInstance());

  final LocalBackend backend;
  final SharedPreferences _prefs;

  late String _lang;
  final Map<String, int> _cart = {};

  String get lang => _lang;
  bool get isArabic => _lang == 'ar';

  AppUser? get user => backend.currentUser;
  Role? get role => user?.role;

  Future<void> toggleLanguage() async {
    _lang = isArabic ? 'en' : 'ar';
    await _prefs.setString(_langKey, _lang);
    notifyListeners();
  }

  // ---------------------------------------------------------------- Cart

  Map<String, int> get cart => Map.unmodifiable(_cart);
  int get cartCount => _cart.values.fold(0, (a, b) => a + b);

  void addToCart(String listingId) {
    _cart.update(listingId, (q) => q + 1, ifAbsent: () => 1);
    _saveCart();
  }

  void removeFromCart(String listingId) {
    final q = _cart[listingId];
    if (q == null) return;
    if (q <= 1) {
      _cart.remove(listingId);
    } else {
      _cart[listingId] = q - 1;
    }
    _saveCart();
  }

  void _saveCart() {
    _prefs.setString(_cartKey, jsonEncode(_cart));
    notifyListeners();
  }

  Future<void> resetDemo() async {
    _cart.clear();
    await _prefs.remove(_cartKey);
    await backend.resetDemoData();
  }

  // -------------------------------------------------------------- Notices

  /// A message key to show once as a snackbar, e.g. 'accessDenied'. Kept
  /// apart from [notifyListeners] so posting it does not re-run the router.
  final ValueNotifier<String?> notice = ValueNotifier(null);

  void postNotice(String key) => notice.value = key;
}
