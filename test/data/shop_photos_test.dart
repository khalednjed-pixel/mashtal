import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/seed/plant_photos.dart';
import 'package:mashtal/data/seed/plants_seed.dart';

/// Every catalogue plant needs a bundled shop photo with a credit, so a plant
/// added to plants_seed.dart without one fails here (see docs/plant-data.md).
void main() {
  test('every catalogue plant has a bundled shop photo with its credit', () {
    for (final p in seedPlants) {
      final photo = shopPhotos[p.id];
      expect(photo, isNotNull, reason: '${p.id} ${p.nameEn} has no shop photo');
      expect(File(photo!.asset).existsSync(), isTrue, reason: '${photo.asset} is missing');
      expect(photo.file, isNotEmpty, reason: '${p.id} needs its Commons file name');
      expect(photo.licence, isNotEmpty, reason: '${p.id} needs its licence');
    }
  });

  test('no shop photo points at a plant that is not in the catalogue', () {
    final ids = seedPlants.map((p) => p.id).toSet();
    expect(shopPhotos.keys.where((id) => !ids.contains(id)), isEmpty);
  });
}
