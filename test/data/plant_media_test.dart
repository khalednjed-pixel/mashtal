import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/seed/plant_media.g.dart';
import 'package:mashtal/data/seed/plants_seed.dart';
import 'package:mashtal/logic/catalog_search.dart';
import 'package:mashtal/data/seed/seed_data.dart';
import 'package:mashtal/ui/widgets/plant_photo.dart';

/// Imported Wikidata / Commons data (docs/plant-data.md).
void main() {
  test('35 of the 37 seed plants are linked to Wikidata', () {
    final ids = {for (final p in seedPlants) p.id};
    expect(plantMedia.keys.toSet().difference(ids), isEmpty);
    expect(plantMedia.length, 35);
    expect(plantMedia.values.map((m) => m.wikidataId), everyElement(matches(RegExp(r'^Q\d+$'))));
  });

  test('every imported photo has a licence, and CC BY photos also an author or file page', () {
    for (final MapEntry(key: id, value: m) in plantMedia.entries.where((e) => e.value.hasPhoto)) {
      expect(m.photoUrl, startsWith('https://upload.wikimedia.org/'), reason: id);
      expect(m.photoLicence, isNotNull, reason: id);
      expect(m.photoPageUrl, startsWith('https://commons.wikimedia.org/wiki/File:'), reason: id);
      if (m.photoLicence!.startsWith('CC BY')) {
        expect(m.photoLicenceUrl, startsWith('https://creativecommons.org/licenses/'), reason: id);
      }
    }
  });

  test('the photo comes from the dataset, with its credit, without a network lookup', () async {
    final ghaf = seedPlants.firstWhere((p) => p.id == 'p01');
    WikiPhotos.enabled = true;
    final photo = await WikiPhotos.of(ghaf);
    expect(photo?.media?.photoAuthor, 'LRBurdak');
    expect(photo?.media?.credit, 'LRBurdak · CC BY-SA 4.0 · Wikimedia Commons');
  });

  test('Wikidata names are extra search terms; the app names still rank first', () {
    SearchResults search(String q) => searchCatalog(
          query: q,
          filters: const SearchFilters(),
          plants: seedPlants,
          nurseries: seedNurseries,
          listings: seedListings,
        );
    // "Flamboyant" is a Wikidata name of the royal poinciana (p10).
    expect(search('flamboyant').plants.map((r) => r.plant.id), ['p10']);
    // Arabic Wikidata label of the oleander: دفلى.
    expect(search('دفلى').plants.map((r) => r.plant.id), contains('p15'));
  });
}
