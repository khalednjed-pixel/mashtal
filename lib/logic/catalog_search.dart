import '../models/models.dart';
import 'text_match.dart';

/// Filters a customer can apply in Buy Plants (US-05 AC-02).
class SearchFilters {
  const SearchFilters({this.placement, this.sun, this.water, this.maxPrice, this.city});

  final Placement? placement;
  final Sun? sun;
  final Water? water;

  /// Upper price limit in SAR.
  final double? maxPrice;
  final String? city;

  bool get isEmpty => placement == null && sun == null && water == null && maxPrice == null && city == null;

  int get activeCount => [placement, sun, water, maxPrice, city].where((v) => v != null).length;

  SearchFilters copyWith({
    Placement? Function()? placement,
    Sun? Function()? sun,
    Water? Function()? water,
    double? Function()? maxPrice,
    String? Function()? city,
  }) =>
      SearchFilters(
        placement: placement != null ? placement() : this.placement,
        sun: sun != null ? sun() : this.sun,
        water: water != null ? water() : this.water,
        maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
        city: city != null ? city() : this.city,
      );
}

/// A plant together with the offers of verified nurseries that match the filters.
class PlantResult {
  const PlantResult(this.plant, this.offers);

  final Plant plant;
  final List<Offer> offers;

  bool get anyAvailable => offers.any((o) => o.listing.isAvailable);

  double? get lowestPrice {
    final prices = offers.where((o) => o.listing.isAvailable).map((o) => o.listing.price);
    return prices.isEmpty ? null : prices.reduce((a, b) => a < b ? a : b);
  }
}

class Offer {
  const Offer(this.listing, this.nursery);
  final Listing listing;
  final Nursery nursery;
}

class SearchResults {
  const SearchResults(this.plants, this.nurseries);
  final List<PlantResult> plants;
  final List<Nursery> nurseries;
  bool get isEmpty => plants.isEmpty && nurseries.isEmpty;
}

/// Buy Plants search (US-05): plants sold by verified nurseries first, then
/// matching verified nurseries. Hidden listings never appear; listings with
/// quantity 0 appear as not available (US-06 AC-02). Unverified nurseries and
/// their listings are never shown to customers (US-03 AC-01).
SearchResults searchCatalog({
  required String query,
  required SearchFilters filters,
  required List<Plant> plants,
  required List<Nursery> nurseries,
  required List<Listing> listings,
}) {
  final verified = {
    for (final n in nurseries)
      if (n.isVerified && (filters.city == null || n.city == filters.city)) n.id: n,
  };

  final offersByPlant = <String, List<Offer>>{};
  for (final l in listings) {
    final n = verified[l.nurseryId];
    if (n == null || l.hidden) continue;
    if (filters.maxPrice != null && l.price > filters.maxPrice!) continue;
    offersByPlant.putIfAbsent(l.plantId, () => []).add(Offer(l, n));
  }

  final plantResults = <PlantResult>[];
  for (final p in plants) {
    final offers = offersByPlant[p.id];
    if (offers == null) continue;
    if (filters.placement != null && !p.placements.contains(filters.placement)) continue;
    if (filters.sun != null && p.sun != filters.sun) continue;
    if (filters.water != null && p.water != filters.water) continue;
    if (!matchesQuery(query, [p.nameAr, p.nameEn, p.scientificName])) continue;
    offers.sort((a, b) => a.listing.price.compareTo(b.listing.price));
    plantResults.add(PlantResult(p, offers));
  }
  // Closest name match first, then available plants, then by lowest price.
  int rank(Plant p) => matchRank(query, [p.nameAr, p.nameEn, p.scientificName]);
  plantResults.sort((a, b) {
    final byRank = rank(a.plant).compareTo(rank(b.plant));
    if (byRank != 0) return byRank;
    if (a.anyAvailable != b.anyAvailable) return a.anyAvailable ? -1 : 1;
    return (a.lowestPrice ?? double.infinity).compareTo(b.lowestPrice ?? double.infinity);
  });

  final nurseryResults = query.trim().isEmpty
      ? <Nursery>[]
      : verified.values.where((n) => matchesQuery(query, [n.nameAr, n.nameEn, n.district])).toList();

  return SearchResults(plantResults, nurseryResults);
}
