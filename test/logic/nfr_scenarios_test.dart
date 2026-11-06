import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/seed/plants_seed.dart';
import 'package:mashtal/logic/citation.dart';
import 'package:mashtal/logic/suitability.dart';

/// NFR-01 and NFR-02 over 30 labelled scenarios (Sprint 2).
///
/// Each scenario names the plant a gardener would pick first for those
/// answers, chosen from the plants' care needs, not from the app's output.
/// The labels should be reviewed by the team (Faisal, Ghali) against the
/// RCRC guide; change a label only for a horticultural reason.
///
/// NFR-02: the expected plant must be shown and rank in the top 3 for at
/// least 27 of the 30 scenarios. Plants with the same score share a rank,
/// because the order among equal scores is only a tie-break by name.
/// NFR-01: every result is either cited (guide, edition, section) or
/// labelled as outside the guide.
typedef Scenario = (String label, SuitabilityAnswers answers, String expected);

SuitabilityAnswers a(Spot spot, Amount light, Amount space, Amount water, {bool kids = false}) => SuitabilityAnswers(
      city: 'riyadh',
      spot: spot,
      light: light,
      space: space,
      watering: water,
      kidsOrPets: kids,
    );

const l = Amount.little, s = Amount.some, x = Amount.lots;
const inside = Spot.inside, balcony = Spot.balcony, garden = Spot.garden;

final List<Scenario> scenarios = [
  // Inside the house.
  ('dark room, small pot, weekly water', a(inside, l, l, s), 'p34'), // pothos
  ('dark room, small pot, rare water', a(inside, l, l, l), 'p36'), // ZZ
  ('dark room, small pot, rare water, kids', a(inside, l, l, l, kids: true), 'p28'), // elephant bush
  ('bright room, small pot, rare water', a(inside, s, l, l), 'p35'), // snake plant
  ('bright room, small pot, weekly water, kids', a(inside, s, l, s, kids: true), 'p37'), // spider plant
  ('sunny window, small pot, rare water', a(inside, x, l, l), 'p26'), // aloe
  ('sunny window, small pot, rare water, kids', a(inside, x, l, l, kids: true), 'p28'), // elephant bush
  ('bright room, small pot, frequent water', a(inside, s, l, x), 'p37'), // spider plant
  ('dark room, floor pot, weekly water', a(inside, l, s, s), 'p34'), // pothos
  ('bright room, floor pot, rare water', a(inside, s, s, l), 'p35'), // snake plant
  // Balcony or roof.
  ('sunny balcony, small pot, rare water', a(balcony, x, l, l), 'p32'), // rosemary
  ('sunny balcony, small pot, rare water, kids', a(balcony, x, l, l, kids: true), 'p32'),
  ('half-sun balcony, big pot, weekly water', a(balcony, s, s, s), 'p23'), // Arabian jasmine
  ('half-sun balcony, big pot, weekly water, kids', a(balcony, s, s, s, kids: true), 'p23'),
  ('half-sun balcony, big pot, frequent water', a(balcony, s, s, x), 'p24'), // hibiscus
  ('sunny balcony, big pot, rare water', a(balcony, x, s, l), 'p16'), // bougainvillea
  ('sunny balcony, big pot, weekly water', a(balcony, x, s, s), 'p14'), // yellow bells
  ('shady balcony, small pot, rare water', a(balcony, l, l, l), 'p28'), // elephant bush
  ('half-sun balcony, small pot, rare water', a(balcony, s, l, l), 'p28'),
  ('sunny balcony, small pot, weekly water', a(balcony, x, l, s), 'p32'), // rosemary
  // Yard or garden.
  ('sunny yard, in the ground, rare water', a(garden, x, x, l), 'p01'), // ghaf
  ('sunny yard, in the ground, weekly water', a(garden, x, x, s), 'p04'), // date palm
  ('sunny yard, in the ground, frequent water', a(garden, x, x, x), 'p10'), // royal poinciana
  ('sunny yard, in the ground, rare water, kids', a(garden, x, x, l, kids: true), 'p03'), // sidr
  ('half-sun yard, big pot, weekly water', a(garden, s, s, s), 'p22'), // Natal plum
  ('sunny yard, big pot, rare water', a(garden, x, s, l), 'p13'), // Texas sage
  ('sunny yard, small bed, frequent water', a(garden, x, l, x), 'p30'), // seashore paspalum
  ('sunny yard, small bed, rare water', a(garden, x, l, l), 'p31'), // sea purslane
  ('half-sun yard, small bed, rare water', a(garden, s, l, l), 'p28'), // elephant bush
  ('shady yard, big pot, weekly water, kids', a(garden, l, s, s, kids: true), 'p22'), // Natal plum
];

/// Rank of [plantId] in [outcome], with equal scores sharing a rank; null if
/// the plant is not shown.
int? sharedRank(SuitabilityOutcome outcome, String plantId) {
  final results = (outcome as Ranked).results;
  final mine = results.where((r) => r.plant.id == plantId).firstOrNull;
  if (mine == null) return null;
  return results.map((r) => r.total).toSet().where((t) => t > mine.total).length + 1;
}

void main() {
  test('there are 30 labelled scenarios', () => expect(scenarios, hasLength(30)));

  test('NFR-02 the expected plant is in the top 3 for at least 27 of 30 scenarios', () {
    final misses = <String>[];
    for (final (label, answers, expected) in scenarios) {
      final rank = sharedRank(recommend(seedPlants, answers), expected);
      if (rank == null || rank > 3) misses.add('$label: $expected ranked ${rank ?? 'not shown'}');
    }
    expect(misses.length, lessThanOrEqualTo(3), reason: misses.join('\n'));
  });

  test('NFR-02 no toxic plant is shown in any scenario with children or pets', () {
    for (final (label, answers, _) in scenarios.where((sc) => sc.$2.kidsOrPets == true)) {
      final shown = (recommend(seedPlants, answers) as Ranked).results;
      expect(shown.where((r) => r.plant.toxic), isEmpty, reason: label);
    }
  });

  test('NFR-01 every result in every scenario is cited or labelled', () {
    var checked = 0;
    for (final (label, answers, _) in scenarios) {
      for (final r in (recommend(seedPlants, answers) as Ranked).results) {
        final c = citationFor(r.plant);
        if (c == null) {
          expect(r.plant.guideBacked && !r.plant.isCustom, isFalse, reason: '$label: ${r.plant.id}');
        } else {
          expect([c.guide, c.edition, c.section, c.guideAr, c.editionAr, c.sectionAr], everyElement(isNotEmpty));
        }
        checked++;
      }
    }
    expect(checked, greaterThan(100));
  });
}
