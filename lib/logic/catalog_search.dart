import '../data/seed/plant_media.g.dart';
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

/// The app's own names first, then Wikidata's labels as extra search terms
/// (docs/plant-data.md), so the app's names still rank as the closest match.
List<String> _searchNames(Plant p) => [
      p.nameAr,
      p.nameEn,
      p.scientificName,
      if (!p.isCustom) ...?plantMedia[p.id]?.aliases,
    ];

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
    if (!matchesQuery(query, _searchNames(p))) continue;
    offers.sort((a, b) => a.listing.price.compareTo(b.listing.price));
    plantResults.add(PlantResult(p, offers));
  }
  // Closest name match first, then available plants, then by lowest price.
  int rank(Plant p) => matchRank(query, _searchNames(p));
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

/// One rule for every customer screen (QA BUG-5, US-06 AC-02): a listing is
/// shown when its nursery is verified and the nursery has not hidden it.
/// Listings with quantity 0 are shown as "not available", after the ones in
/// stock, on both the plant page and the nursery page. Counts of "nurseries
/// that have it" use only listings in stock. Within each group, nurseries in
/// the customer's [city] come first, then the cheapest (the US-12 order).
List<Offer> customerOffers({
  required List<Listing> listings,
  required Nursery? Function(String id) nurseryById,
  String? plantId,
  String? nurseryId,
  String? city,
}) {
  final offers = [
    for (final l in listings)
      if (!l.hidden && (plantId == null || l.plantId == plantId) && (nurseryId == null || l.nurseryId == nurseryId))
        if (nurseryById(l.nurseryId) case final n? when n.isVerified) Offer(l, n),
  ];
  offers.sort((a, b) {
    if (a.listing.isAvailable != b.listing.isAvailable) return a.listing.isAvailable ? -1 : 1;
    final aHere = city != null && a.nursery.city == city, bHere = city != null && b.nursery.city == city;
    if (aHere != bHere) return aHere ? -1 : 1;
    return a.listing.price.compareTo(b.listing.price);
  });
  return offers;
}
