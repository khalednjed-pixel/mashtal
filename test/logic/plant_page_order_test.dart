import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/models/models.dart';
import 'package:mashtal/data/seed/seed_data.dart';
import 'package:mashtal/logic/catalog_search.dart';

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
}
