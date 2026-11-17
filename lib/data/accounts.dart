import '../models/models.dart';

/// Where sign-in accounts live (TF-03).
///
/// The sign-in screens are the same with or without it: the user enters a
/// phone number and the app shows the code on screen. When an
/// [AccountService] is given to the backend, a correct code then signs the
/// user in to Firebase and their profile (name, city, role) is kept in
/// Firestore instead of on the device.
///
/// Partner and admin roles come from `partnerAccounts/{phone}`, which only
/// the admin can write. A user can never give themselves a role.
abstract interface class AccountService {
  /// The account still signed in from a previous visit, if any.
  Future<AppUser?> restore();

  /// Signs in to the account for [phone] (05XXXXXXXX), creating it on the
  /// first visit. Returns the account id.
  Future<String> signIn(String phone);

  /// The saved profile of account [uid], or null for a new account.
  Future<AppUser?> loadProfile(String uid);

  /// The role the admin gave [phone], or null for a plain customer.
  Future<PartnerAccount?> partnerAccount(String phone);

  /// Creates the profile, or changes its role to match [partnerAccount].
  Future<void> saveProfile(AppUser user);

  Future<void> updateProfile(String uid, {required String name, required String city});

  /// Admin only: [phone] signs in as [role] for [partnerId].
  Future<void> setPartnerAccount(String phone, Role role, String? partnerId);

  /// Admin only.
  Future<void> removePartnerAccount(String phone);

  Future<void> signOut();
}

class PartnerAccount {
  const PartnerAccount(this.role, this.partnerId);
  final Role role;
  final String? partnerId;
}
