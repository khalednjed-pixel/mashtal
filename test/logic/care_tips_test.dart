import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/seed/plants_seed.dart';
import 'package:mashtal/logic/care_tips.dart';
import 'package:mashtal/models/models.dart';

void main() {
  Plant plant(String id) => seedPlants.firstWhere((p) => p.id == id);

  test('every plant gets a light and a water tip that match its needs', () {
    for (final p in seedPlants) {
      final keys = careTipsFor(p).map((t) => t.key).toList();
      expect(keys.take(2), ['tip.sun.${p.sun.name}', 'tip.water.${p.water.name}'], reason: p.id);
    }
  });

  test('outdoor plants get the summer tip, indoor ones the air-conditioner tip', () {
    final palm = careTipsFor(plant('p04')).map((t) => t.key);
    expect(palm, contains('tip.heat'));
    expect(palm, isNot(contains('tip.ac')));
  });

  test('toxic plants carry a safety tip and succulents a drainage tip', () {
    for (final p in seedPlants) {
      final keys = careTipsFor(p).map((t) => t.key);
      expect(keys.contains('tip.toxic'), p.toxic, reason: p.id);
      expect(keys.contains('tip.drainage'), p.category == PlantCategory.succulent, reason: p.id);
    }
  });
}
