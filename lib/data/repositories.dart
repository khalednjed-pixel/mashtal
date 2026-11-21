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

/// The device ran out of storage (the browser keeps about 5 MB).
class StorageFull implements Exception {
  const StorageFull();
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

  /// Lets the signed-in user change their own name and city.
  Future<void> updateProfile({required String name, required String city});
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
  Future<void> updateNursery(Nursery nursery);
  Future<void> setNurseryStatus(String nurseryId, PartnerStatus status);

  /// Removes the nursery, its listings and its sign-in account.
  Future<void> deleteNursery(String nurseryId);
  Future<Professional> createProfessional(Professional draft);

  /// Admin edits any professional; a professional edits their own services
  /// and cities only.
  Future<void> updateProfessional(Professional professional);
  Future<void> setProfessionalStatus(String professionalId, PartnerStatus status);
  Future<void> deleteProfessional(String professionalId);
  Future<void> updatePriceRange(ServiceType service, {required double min, required double max});

  // Nursery only, for its own listings (US-06).
  Future<Listing> addListing({required String plantId, required double price, required int quantity, String? photo});
  Future<void> updateListing(Listing listing);
  Future<void> deleteListing(String listingId);

  /// A nursery adds a plant that is not in the knowledge base. It is labelled
  /// as not guide-backed.
  Future<Plant> addPlant(Plant draft);

  /// The admin, or the nursery that added it, removes a nursery-added plant
  /// together with its listings. Knowledge-base plants cannot be deleted.
  Future<void> deletePlant(String plantId);

  /// Admin only (US-14): changes where a plant can live, its sun and water
  /// needs, watering interval and toxicity. Each changed field is logged
  /// with the editor, time and previous value. Results use it at once, with
  /// no new app release.
  Future<void> updatePlant(Plant plant);

  /// Edit log of one plant, newest first.
  List<PlantEdit> plantEditsFor(String plantId);
}

/// Reservations (US-16): a customer reserves the cart, one reservation per
/// nursery.
abstract interface class ReservationRepository {
  /// What the signed-in user may see, newest first: a customer's own
  /// reservations, or those sent to the signed-in nursery.
  List<Reservation> get reservations;

  /// Customer only. Turns the cart (listing id → quantity) into one pending
  /// reservation per nursery. Lines whose listing is gone or not available
  /// are left out.
  Future<List<Reservation>> reserve(Map<String, int> cart);

  /// US-17, the reservation's nursery only, while it is pending: accepting
  /// starts the 48-hour hold.
  Future<void> acceptReservation(String id);

  /// US-17, the reservation's nursery only, while it is pending. The customer
  /// sees [reason].
  Future<void> rejectReservation(String id, RejectReason reason);

  /// US-20, the reservation's nursery only, while it is accepted and its hold
  /// has not run out. The plants then appear in the customer's My Garden.
  Future<void> markPickedUp(String id);
}

/// My Garden (US-21): the plants a customer owns.
abstract interface class GardenRepository {
  /// The signed-in customer's plants, newest first. Empty for anyone else.
  List<GardenPlant> get garden;

  /// Customer only: adds a plant bought outside the app.
  Future<GardenPlant> addToGarden(String plantId, {PlantHome? home});

  /// Customer only, own plants: records a watering now.
  Future<void> markWatered(String gardenPlantId);

  /// Customer only, own plants: the soil was still moist when checked, so
  /// the next check comes a little later and the plant's pace stretches.
  Future<void> markStillMoist(String gardenPlantId);

  /// Customer only, own plants: where the plant lives.
  Future<void> setHome(String gardenPlantId, PlantHome home);

  /// Customer only, own plants.
  Future<void> removeFromGarden(String gardenPlantId);

  /// US-22: the stored history of one of the customer's plants, newest
  /// first. How the plant arrived is not stored; see logic/history.dart.
  List<HistoryEntry> historyOf(String gardenPlantId);

  /// Customer only, own plants: a short note in the plant's history.
  Future<void> addNote(String gardenPlantId, String text);
}
