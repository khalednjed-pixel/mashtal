import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/seed/plants_seed.dart';
import 'package:mashtal/logic/care_plan.dart';
import 'package:mashtal/models/models.dart';

void main() {
  final jasmine = seedPlants.firstWhere((p) => p.id == 'p23'); // every 3 days, outdoor shrub
  final palm = seedPlants.firstWhere((p) => p.id == 'p04'); // every 7 days, palm
  final pothos = seedPlants.firstWhere((p) => p.id == 'p34'); // houseplant

  GardenPlant owned(Plant p, {PlantHome? home, DateTime? added, DateTime? watered, DateTime? checked, double pace = 1}) => GardenPlant(
        id: 'g1',
        ownerId: 'c1',
        plantId: p.id,
        addedAt: added ?? DateTime(2026, 1, 1),
        source: GardenSource.manual,
        home: home,
        lastWateredAt: watered,
        lastCheckedAt: checked,
        pace: pace,
      );

  test('Riyadh seasons: June to September is summer, December to February winter', () {
    expect(riyadhSeason(DateTime(2026, 7, 10)), Season.summer);
    expect(riyadhSeason(DateTime(2026, 1, 10)), Season.winter);
    expect(riyadhSeason(DateTime(2026, 11, 10)), Season.mild);
  });

  test('the same plant needs water more often in summer than in winter', () {
    final g = owned(palm, home: PlantHome.ground);
    final summer = CarePlan.of(g, palm, DateTime(2026, 7, 10)).everyDays;
    final mild = CarePlan.of(g, palm, DateTime(2026, 11, 10)).everyDays;
    final winter = CarePlan.of(g, palm, DateTime(2027, 1, 10)).everyDays;
    expect(mild, palm.wateringEveryDays, reason: "the plant's own interval is its mild-weather need");
    expect(summer, lessThan(mild));
    expect(winter, greaterThan(mild));
  });

  test('a small pot dries faster than a big pot, which dries faster than the ground', () {
    final now = DateTime(2026, 11, 10);
    int every(PlantHome h) => CarePlan.of(owned(palm, home: h), palm, now).everyDays;
    expect(every(PlantHome.smallPot), lessThan(every(PlantHome.bigPot)));
    expect(every(PlantHome.bigPot), lessThan(every(PlantHome.ground)));
  });

  test('a new plant is watered more often while it settles in, and says why', () {
    final now = DateTime(2026, 11, 10);
    final fresh = CarePlan.of(owned(palm, home: PlantHome.ground, added: now), palm, now);
    final settled = CarePlan.of(owned(palm, home: PlantHome.ground, added: DateTime(2026, 1, 1)), palm, now);
    expect(fresh.everyDays, lessThan(settled.everyDays));
    expect(fresh.reasons, contains(PlanReason.newPlant));
    expect(settled.reasons, isEmpty);
  });

  test('"still moist" brings the next check sooner than a whole interval, and a learned pace stretches it', () {
    final now = DateTime(2026, 11, 10, 9);
    final g = owned(palm, home: PlantHome.ground, watered: DateTime(2026, 11, 3, 9), checked: now);
    final plan = CarePlan.of(g, palm, now);
    expect(plan.dueInDays, inInclusiveRange(1, plan.everyDays - 1));
    final learned = CarePlan.of(owned(palm, home: PlantHome.ground, pace: 1.5), palm, now);
    expect(learned.everyDays, greaterThan(palm.wateringEveryDays));
    expect(learned.reasons, contains(PlanReason.learned));
  });

  test('soil moisture drains from full after watering to empty when due', () {
    final now = DateTime(2026, 11, 10, 9);
    final g = owned(palm, home: PlantHome.ground, watered: now);
    expect(CarePlan.of(g, palm, now).moisture, 1);
    expect(CarePlan.of(g, palm, now.add(Duration(days: palm.wateringEveryDays))).moisture, 0);
  });

  test('without an answer the app guesses where a plant lives', () {
    expect(guessHome(palm), PlantHome.ground);
    expect(guessHome(jasmine), PlantHome.bigPot);
    expect(guessHome(pothos), PlantHome.indoor);
    final plan = CarePlan.of(owned(jasmine), jasmine, DateTime(2026, 11, 10));
    expect(plan.homeGuessed, isTrue);
    expect(plan.home, PlantHome.bigPot);
  });
}
