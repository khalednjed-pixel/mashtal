import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/seed/seed_data.dart';
import 'package:mashtal/logic/directions.dart';

/// US-18 AC-02: the directions link points the map app at the nursery.
void main() {
  test('with a map point, directions go to that point', () {
    final n1 = seedNurseries.firstWhere((n) => n.id == 'n1');
    final uri = directionsTo(n1);
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['destination'], '${n1.lat},${n1.lng}');
  });

  test('without one, the map searches for the nursery by name and district', () {
    final n = seedNurseries.first.copyWith(location: () => null);
    final uri = directionsTo(n);
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters['query'], contains('Al Rawdah Nursery'));
  });

  test('every demo nursery has a map point', () {
    expect(seedNurseries.every((n) => n.lat != null && n.lng != null), isTrue);
  });

  test('the admin can type coordinates or paste a Google Maps link', () {
    expect(parseLocation('24.7136, 46.6753'), (24.7136, 46.6753));
    expect(parseLocation('https://www.google.com/maps/place/X/@24.7376,46.7725,15z'), (24.7376, 46.7725));
    expect(parseLocation('https://maps.google.com/?q=21.5675,39.1505'), (21.5675, 39.1505));
    expect(parseLocation('Al Rawdah'), isNull);
    expect(parseLocation('124.5, 46.2'), isNull);
  });
}
