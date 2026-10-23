/// Domain models shared by the UI and the repositories.
///
/// Every model can be written to and read from JSON so the same shapes can
/// later be stored as Firestore documents (see docs/data-model.md).
library;

enum Role { customer, nursery, professional, admin }

/// Verification state of a nursery or professional (US-03).
enum PartnerStatus { pending, verified, suspended }

enum Placement { indoor, outdoor }

enum Sun { full, partial, shade }

enum Water { low, medium, high }

enum PlantCategory { tree, palm, shrub, climber, succulent, groundcover, grass, herb, houseplant }

enum ServiceType { planting, pruning, periodicCare, treatment }

T _enumByName<T extends Enum>(List<T> values, String name) => values.firstWhere((v) => v.name == name);

/// One species in the plant knowledge base (TF-06).
class Plant {
  const Plant({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.scientificName,
    required this.category,
    required this.placements,
    required this.sun,
    required this.water,
    required this.wateringEveryDays,
    required this.toxic,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.source,
    this.guideBacked = true,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String scientificName;
  final PlantCategory category;
  final Set<Placement> placements;
  final Sun sun;
  final Water water;
  final int wateringEveryDays;

  /// Toxic to children or pets (OD-10).
  final bool toxic;
  final String descriptionAr;
  final String descriptionEn;

  /// Where the record came from, e.g. the RCRC Manual of Riyadh Plants.
  final String source;

  /// False for plants outside the official guides (OD-03); the UI labels them.
  final bool guideBacked;

  String name(String lang) => lang == 'ar' ? nameAr : nameEn;
  String description(String lang) => lang == 'ar' ? descriptionAr : descriptionEn;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'scientificName': scientificName,
        'category': category.name,
        'placements': placements.map((p) => p.name).toList(),
        'sun': sun.name,
        'water': water.name,
        'wateringEveryDays': wateringEveryDays,
        'toxic': toxic,
        'descriptionAr': descriptionAr,
        'descriptionEn': descriptionEn,
        'source': source,
        'guideBacked': guideBacked,
      };

  factory Plant.fromJson(Map<String, dynamic> j) => Plant(
        id: j['id'],
        nameAr: j['nameAr'],
        nameEn: j['nameEn'],
        scientificName: j['scientificName'],
        category: _enumByName(PlantCategory.values, j['category']),
        placements: (j['placements'] as List).map((p) => _enumByName(Placement.values, p as String)).toSet(),
        sun: _enumByName(Sun.values, j['sun']),
        water: _enumByName(Water.values, j['water']),
        wateringEveryDays: j['wateringEveryDays'],
        toxic: j['toxic'],
        descriptionAr: j['descriptionAr'],
        descriptionEn: j['descriptionEn'],
        source: j['source'],
        guideBacked: j['guideBacked'] ?? true,
      );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.phone,
    required this.name,
    required this.city,
    required this.role,
    this.partnerId,
  });

  final String id;

  /// Saudi mobile number in local form, 05XXXXXXXX.
  final String phone;
  final String name;
  final String city;
  final Role role;

  /// The nursery or professional record this account manages, if any.
  final String? partnerId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'city': city,
        'role': role.name,
        'partnerId': partnerId,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        phone: j['phone'],
        name: j['name'],
        city: j['city'],
        role: _enumByName(Role.values, j['role']),
        partnerId: j['partnerId'],
      );
}

class Nursery {
  const Nursery({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.city,
    required this.district,
    required this.phone,
    required this.hours,
    required this.status,
    this.rating = 0,
    this.ratingCount = 0,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String city;
  final String district;
  final String phone;
  final String hours;
  final PartnerStatus status;
  final double rating;
  final int ratingCount;

  String name(String lang) => lang == 'ar' ? nameAr : nameEn;
  bool get isVerified => status == PartnerStatus.verified;

  Nursery copyWith({PartnerStatus? status}) => Nursery(
        id: id,
        nameAr: nameAr,
        nameEn: nameEn,
        city: city,
        district: district,
        phone: phone,
        hours: hours,
        status: status ?? this.status,
        rating: rating,
        ratingCount: ratingCount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'city': city,
        'district': district,
        'phone': phone,
        'hours': hours,
        'status': status.name,
        'rating': rating,
        'ratingCount': ratingCount,
      };

  factory Nursery.fromJson(Map<String, dynamic> j) => Nursery(
        id: j['id'],
        nameAr: j['nameAr'],
        nameEn: j['nameEn'],
        city: j['city'],
        district: j['district'],
        phone: j['phone'],
        hours: j['hours'],
        status: _enumByName(PartnerStatus.values, j['status']),
        rating: (j['rating'] as num).toDouble(),
        ratingCount: j['ratingCount'],
      );
}

class Professional {
  const Professional({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.cities,
    required this.services,
    required this.phone,
    required this.status,
    this.rating = 0,
    this.jobsDone = 0,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final List<String> cities;
  final Set<ServiceType> services;
  final String phone;
  final PartnerStatus status;
  final double rating;
  final int jobsDone;

  String name(String lang) => lang == 'ar' ? nameAr : nameEn;

  Professional copyWith({PartnerStatus? status}) => Professional(
        id: id,
        nameAr: nameAr,
        nameEn: nameEn,
        cities: cities,
        services: services,
        phone: phone,
        status: status ?? this.status,
        rating: rating,
        jobsDone: jobsDone,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'cities': cities,
        'services': services.map((s) => s.name).toList(),
        'phone': phone,
        'status': status.name,
        'rating': rating,
        'jobsDone': jobsDone,
      };

  factory Professional.fromJson(Map<String, dynamic> j) => Professional(
        id: j['id'],
        nameAr: j['nameAr'],
        nameEn: j['nameEn'],
        cities: List<String>.from(j['cities']),
        services: (j['services'] as List).map((s) => _enumByName(ServiceType.values, s as String)).toSet(),
        phone: j['phone'],
        status: _enumByName(PartnerStatus.values, j['status']),
        rating: (j['rating'] as num).toDouble(),
        jobsDone: j['jobsDone'],
      );
}

/// A plant offered by one nursery (US-06).
class Listing {
  const Listing({
    required this.id,
    required this.nurseryId,
    required this.plantId,
    required this.price,
    required this.quantity,
    this.hidden = false,
  });

  final String id;
  final String nurseryId;
  final String plantId;

  /// Price in SAR.
  final double price;
  final int quantity;
  final bool hidden;

  bool get isAvailable => !hidden && quantity > 0;

  Listing copyWith({double? price, int? quantity, bool? hidden}) => Listing(
        id: id,
        nurseryId: nurseryId,
        plantId: plantId,
        price: price ?? this.price,
        quantity: quantity ?? this.quantity,
        hidden: hidden ?? this.hidden,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nurseryId': nurseryId,
        'plantId': plantId,
        'price': price,
        'quantity': quantity,
        'hidden': hidden,
      };

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        id: j['id'],
        nurseryId: j['nurseryId'],
        plantId: j['plantId'],
        price: (j['price'] as num).toDouble(),
        quantity: j['quantity'],
        hidden: j['hidden'] ?? false,
      );
}

/// Admin-set price range for a service type (TF-07; edited in US-13).
class PriceRange {
  const PriceRange({required this.service, required this.min, required this.max});

  final ServiceType service;
  final double min;
  final double max;

  Map<String, dynamic> toJson() => {'service': service.name, 'min': min, 'max': max};

  factory PriceRange.fromJson(Map<String, dynamic> j) => PriceRange(
        service: _enumByName(ServiceType.values, j['service']),
        min: (j['min'] as num).toDouble(),
        max: (j['max'] as num).toDouble(),
      );
}
