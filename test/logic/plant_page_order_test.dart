import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/models/models.dart';
import 'package:mashtal/data/seed/seed_data.dart';
import 'package:mashtal/logic/catalog_search.dart';
import 'package:mashtal/logic/shop_filters.dart';

void main() {
  Nursery? byId(String id) => seedNurseries.where((n) => n.id == id).firstOrNull;
  List<String> order(String? city) => [
        for (final o in customerOffers(listings: seedListings, nurseryById: byId, plantId: 'p24', city: city)) o.nursery.id,
      ];

  test('plant page lists nurseries in the customer city first, then cheapest (US-12 order)', () {
    final riyadh = order('riyadh');
    final jeddahAt = riyadh.indexOf('n4');
    expect(jeddahAt, greaterThan(0));
    expect(riyadh.take(jeddahAt).every((id) => byId(id)!.city == 'riyadh'), isTrue);
    expect(order('jeddah').first, 'n4');
  });

  test('a guest with no city still sees the cheapest first', () {
    final offers = customerOffers(listings: seedListings, nurseryById: byId, plantId: 'p24');
    final prices = [for (final o in offers) if (o.listing.isAvailable) o.listing.price];
    expect(prices, [...prices]..sort());
  });

  group('which city comes first', () {
    const riyadhUser = AppUser(id: 'u-test', phone: '0500000099', name: 'Test', city: 'riyadh', role: Role.customer);
    setUp(savedShopFilters.clear);

    test('a signed-in user starts with their account city', () {
      expect(preferredCity(riyadhUser), 'riyadh');
    });

    test('the shop filter city wins over the account city', () {
      setShopFilters(riyadhUser, const SearchFilters(city: 'jeddah'));
      expect(preferredCity(riyadhUser), 'jeddah');
      expect(order(preferredCity(riyadhUser)).first, 'n4');
    });

    test('a guest who picks a city in the filter gets that city first', () {
      expect(preferredCity(null), isNull);
      setShopFilters(null, const SearchFilters(city: 'jeddah'));
      expect(preferredCity(null), 'jeddah');
    });

    test('clearing the filter city falls back to the account city', () {
      setShopFilters(riyadhUser, const SearchFilters());
      expect(preferredCity(riyadhUser), 'riyadh');
    });
  });
}
