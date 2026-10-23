import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/seed/plants_seed.dart';
import 'package:mashtal/data/seed/seed_data.dart';
import 'package:mashtal/logic/catalog_search.dart';
import 'package:mashtal/models/models.dart';

SearchResults search(String q, [SearchFilters f = const SearchFilters(), List<Nursery>? nurseries, List<Listing>? listings]) =>
    searchCatalog(
      query: q,
      filters: f,
      plants: seedPlants,
      nurseries: nurseries ?? seedNurseries,
      listings: listings ?? seedListings,
    );

void main() {
  test('plant data v1 has at least 30 guide-backed species (TF-06)', () {
    expect(seedPlants.where((p) => p.guideBacked).length, greaterThanOrEqualTo(30));
    expect(seedPlants.map((p) => p.id).toSet().length, seedPlants.length);
  });

  group('US-05 search', () {
    test('Arabic plant name finds the plant', () {
      final r = search('الغاف');
      expect(r.plants.first.plant.id, 'p01');
      // Partial matches still show, after the exact one ("الأغاف", agave).
      expect(r.plants.map((p) => p.plant.id), contains('p27'));
    });

    test('English plant name finds the plant', () {
      final r = search('date palm');
      expect(r.plants.single.plant.id, 'p04');
    });

    test('nursery name finds the nursery', () {
      final r = search('الياسمين');
      expect(r.nurseries.map((n) => n.id), ['n3']);
    });

    test('filters keep only matching plants', () {
      final r = search('', const SearchFilters(placement: Placement.indoor));
      expect(r.plants, isNotEmpty);
      expect(r.plants.every((p) => p.plant.placements.contains(Placement.indoor)), isTrue);

      final cheap = search('', const SearchFilters(maxPrice: 25));
      expect(cheap.plants.expand((p) => p.offers).every((o) => o.listing.price <= 25), isTrue);

      final jeddah = search('', const SearchFilters(city: 'jeddah'));
      expect(jeddah.plants.expand((p) => p.offers).every((o) => o.nursery.city == 'jeddah'), isTrue);

      final lowWaterShade = search('', const SearchFilters(sun: Sun.shade, water: Water.low));
      expect(lowWaterShade.plants.every((p) => p.plant.sun == Sun.shade && p.plant.water == Water.low), isTrue);
    });
  });

  group('US-03 only verified nurseries are visible', () {
    test('a pending nursery and its listings are hidden', () {
      // n5 is pending and is the only nursery listing p06 and p20.
      final r = search('');
      final offers = r.plants.expand((p) => p.offers);
      expect(offers.any((o) => o.nursery.id == 'n5'), isFalse);
      expect(r.plants.any((p) => p.plant.id == 'p06'), isFalse);
      expect(search('الفجر').nurseries, isEmpty);
    });

    test('after verification it appears', () {
      final nurseries = [for (final n in seedNurseries) n.id == 'n5' ? n.copyWith(status: PartnerStatus.verified) : n];
      final r = search('', const SearchFilters(), nurseries);
      expect(r.plants.any((p) => p.plant.id == 'p06'), isTrue);
      expect(search('الفجر', const SearchFilters(), nurseries).nurseries.single.id, 'n5');
    });
  });

  group('US-06 availability', () {
    test('quantity 0 is shown as not available', () {
      // Only n3 lists p36 and has quantity 0.
      final zz = search('zz plant').plants.single;
      expect(zz.anyAvailable, isFalse);
      expect(zz.lowestPrice, isNull);
    });

    test('hidden listings never appear', () {
      // p19 is only listed by n3 and hidden.
      expect(search('arfaj').plants, isEmpty);
    });

    test('available plants come before unavailable ones', () {
      final r = search('');
      final firstUnavailable = r.plants.indexWhere((p) => !p.anyAvailable);
      expect(r.plants.skip(firstUnavailable).every((p) => !p.anyAvailable), isTrue);
    });
  });
}
