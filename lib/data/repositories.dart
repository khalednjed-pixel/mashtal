import '../models/models.dart';

/// Contracts between the app and its backend.
///
/// Sprint 1 ships [LocalBackend] (lib/data/local_backend.dart), which keeps
/// data on the device so the app runs without a Firebase project. A Firebase
/// implementation of the same interfaces replaces it once the project exists;
/// the screens do not change.

class OtpRequest {
  const OtpRequest({required this.phone, required this.sentAt, this.demoCode});

  final String phone;
  final DateTime sentAt;

  /// The code, returned only by the demo backend so it can be shown on screen
  /// in place of an SMS. Always null with a real SMS provider.
  final String? demoCode;
}

sealed class VerifyResult {
  const VerifyResult();
}

/// Known number: the user is signed in.
class SignedIn extends VerifyResult {
  const SignedIn(this.user);
  final AppUser user;
}

/// New number: the account needs a name and city (US-02 AC-01).
class NeedsProfile extends VerifyResult {
  const NeedsProfile(this.phone);
  final String phone;
}

class AuthException implements Exception {
  const AuthException(this.code, {this.retryAfter});

  /// One of: invalid-phone, wrong-code, code-expired, no-code, too-soon.
  final String code;
  final Duration? retryAfter;

  @override
  String toString() => 'AuthException($code)';
}

class PermissionDenied implements Exception {
  const PermissionDenied(this.action);
  final String action;

  @override
  String toString() => 'PermissionDenied($action)';
}

abstract interface class AuthRepository {
  static const resendDelay = Duration(seconds: 60);
  static const codeLifetime = Duration(minutes: 5);

  AppUser? get currentUser;

  /// Sends a 6-digit code. Throws [AuthException] `too-soon` when a code was
  /// sent to the same number less than [resendDelay] ago.
  Future<OtpRequest> sendCode(String phone);

  Future<VerifyResult> verifyCode(String phone, String code);

  /// Creates the customer account after a successful [verifyCode].
  Future<AppUser> completeProfile({required String phone, required String name, required String city});

  Future<void> signOut();
}

abstract interface class MarketRepository {
  List<Plant> get plants;
  List<Nursery> get nurseries;
  List<Professional> get professionals;
  List<Listing> get listings;
  List<PriceRange> get priceRanges;

  Plant? plantById(String id);
  Nursery? nurseryById(String id);

  // Admin only (US-03).
  Future<Nursery> createNursery(Nursery draft);
  Future<void> setNurseryStatus(String nurseryId, PartnerStatus status);
  Future<Professional> createProfessional(Professional draft);
  Future<void> setProfessionalStatus(String professionalId, PartnerStatus status);

  // Nursery only, for its own listings (US-06).
  Future<Listing> addListing({required String plantId, required double price, required int quantity});
  Future<void> updateListing(Listing listing);
}
