import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/seed/plants_seed.dart';
import 'package:mashtal/logic/away.dart';
import 'package:mashtal/logic/care_plan.dart';
import 'package:mashtal/models/models.dart';

void main() {
  final now = DateTime(2026, 11, 21, 9);
  Plant plant(String id) => seedPlants.firstWhere((p) => p.id == id);
  ({GardenPlant garden, CarePlan plan}) owned(String id, PlantHome home) {
    final g = GardenPlant(id: 'g-$id', ownerId: 'c1', plantId: id, addedAt: DateTime(2026, 1, 1), source: GardenSource.manual, home: home);
    return (garden: g, plan: CarePlan.of(g, plant(id), now));
  }

  test('a trip counts whole days and is over on the day you are back', () {
    final trip = AwayTrip(from: now, until: DateTime(2026, 11, 28), helper: false);
    expect(trip.days, 7);
    expect(trip.isOver(DateTime(2026, 11, 27, 23)), isFalse);
    expect(trip.isOver(DateTime(2026, 11, 28, 8)), isTrue);
    expect(AwayTrip.fromJson(trip.toJson()).days, 7);
  });

  test('the ground holds water longer than a small pot', () {
    expect(lastsAloneDays(owned('p04', PlantHome.ground).plan), greaterThan(lastsAloneDays(owned('p04', PlantHome.smallPot).plan)));
  });

  test('plants that will not last the trip alone are named, with the day to water them once', () {
    final jasmine = owned('p23', PlantHome.smallPot); // every 3 days
    final sidr = owned('p03', PlantHome.ground); // every 10 days
    final trip = AwayTrip(from: now, until: now.add(const Duration(days: 7)), helper: false);
    final help = needsHelp([jasmine, sidr], trip);
    expect(help.map((h) => h.gardenId), ['g-p23']);
    expect(help.single.waterOn.isAfter(now), isTrue);
    expect(help.single.waterOn.isBefore(trip.until), isTrue);
    expect(needsHelp([sidr], AwayTrip(from: now, until: now.add(const Duration(days: 3)), helper: false)), isEmpty);
    // A long trip needs more than one watering, and says so.
    final long = needsHelp([jasmine], AwayTrip(from: now, until: now.add(const Duration(days: 30)), helper: false)).single;
    expect(long.times, greaterThan(1));
    final short = needsHelp([sidr], AwayTrip(from: now, until: now.add(const Duration(days: 20)), helper: false)).single;
    expect(short.times, 1);
  });

  test('the plan for whoever waters lists each plant and how to check the soil, in either language', () {
    final plants = [(name: 'Arabian jasmine', home: PlantHome.smallPot, everyDays: 2)];
    final en = helperMessage(lang: 'en', untilText: 'Friday 28 November', plants: plants, season: Season.summer);
    expect(en, contains('• Arabian jasmine (small pot): every 2 days'));
    expect(en, contains('push a finger into the soil'));
    expect(en, contains('early morning or after sunset'));
    final ar = helperMessage(lang: 'ar', untilText: 'الجمعة 28 نوفمبر', plants: [(name: 'الفل', home: PlantHome.ground, everyDays: 1)], season: Season.mild);
    expect(ar, contains('• الفل (في الأرض): كل يوم'));
    expect(ar, isNot(contains('الصيف')));
  });
}
