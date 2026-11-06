import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/seed/plants_seed.dart';
import 'package:mashtal/logic/citation.dart';
import 'package:mashtal/logic/suitability.dart';
import 'package:mashtal/models/models.dart';

const indoorDark = SuitabilityAnswers(
  city: 'riyadh',
  spot: Spot.inside,
  light: Amount.little,
  space: Amount.little,
  watering: Amount.some,
  kidsOrPets: false,
);

List<String> ids(SuitabilityOutcome o) => (o as Ranked).results.map((r) => r.plant.id).toList();

Plant plant(String id, {Set<Placement> placements = const {Placement.outdoor}, Sun sun = Sun.full, Water water = Water.low}) => Plant(
      id: id,
      nameAr: id,
      nameEn: id,
      scientificName: id,
      category: PlantCategory.shrub,
      placements: placements,
      sun: sun,
      water: water,
      wateringEveryDays: 7,
      toxic: false,
      descriptionAr: '',
      descriptionEn: '',
      source: 'test',
    );

void main() {
  group('US-07 questions', () {
    test('the window question is asked inside the house only (AC-02)', () {
      final inside = const SuitabilityAnswers().withSpot(Spot.inside).questions;
      expect(inside, contains(Question.window));
      expect(inside, isNot(contains(Question.sun)));

      for (final spot in [Spot.balcony, Spot.garden]) {
        final outside = const SuitabilityAnswers().withSpot(spot).questions;
        expect(outside, contains(Question.sun));
        expect(outside, isNot(contains(Question.window)));
      }
    });

    test('moving between inside and outside clears the light answer only', () {
      final a = indoorDark.withSpot(Spot.garden);
      expect(a.light, isNull);
      expect(a.space, Amount.little);
      expect(a.isComplete, isFalse);
      expect(indoorDark.withSpot(Spot.inside).light, Amount.little);
      expect(const SuitabilityAnswers(spot: Spot.balcony, light: Amount.lots).withSpot(Spot.garden).light, Amount.lots);
    });
  });

  group('US-09 ranking', () {
    test('a dark indoor spot ranks shade plants first, with a per-factor breakdown (AC-01)', () {
      final outcome = recommend(seedPlants, indoorDark);
      // Pothos 100, ZZ 93, spider plant 82, then elephant bush and snake
      // plant at 75 (guide-backed first). Aloe needs full sun and is out.
      expect(ids(outcome), ['p34', 'p36', 'p37', 'p28', 'p35']);
      final top = (outcome as Ranked).results.first;
      expect(top.total, 100);
      expect(top.factors.keys, Factor.values);
      expect(outcome.results.map((r) => r.total), [100, 93, 82, 75, 75]);
    });

    test('no toxic plant is shown when there are children or pets (AC-02, NFR-02)', () {
      final outcome = recommend(seedPlants, indoorDark.copyWith(kidsOrPets: true));
      expect(ids(outcome), ['p37', 'p28']);
      for (final spot in Spot.values) {
        for (final light in Amount.values) {
          final a = SuitabilityAnswers(
            city: 'riyadh',
            spot: spot,
            light: light,
            space: Amount.lots,
            watering: Amount.some,
            kidsOrPets: true,
          );
          final o = recommend(seedPlants, a);
          if (o is Ranked) expect(o.results.where((r) => r.plant.toxic), isEmpty);
        }
      }
    });

    test('at most 10 results, best first, all above the minimum', () {
      const garden = SuitabilityAnswers(
        city: 'riyadh',
        spot: Spot.garden,
        light: Amount.lots,
        space: Amount.lots,
        watering: Amount.some,
        kidsOrPets: false,
      );
      final results = (recommend(seedPlants, garden) as Ranked).results;
      expect(results.length, maxResults);
      final totals = results.map((r) => r.total).toList();
      expect(totals, [...totals]..sort((a, b) => b.compareTo(a)));
      expect(totals.every((t) => t >= minimumScore), isTrue);
      expect(results.every((r) => r.plant.placements.contains(Placement.outdoor)), isTrue);
    });

    test('the same answers always give the same ranking', () {
      expect(ids(recommend(seedPlants, indoorDark)), ids(recommend(seedPlants.reversed.toList(), indoorDark)));
    });

    test('factor rules', () {
      expect(lightScore(Amount.lots, Amount.little), 0);
      expect(lightScore(Amount.some, Amount.some), 100);
      expect(waterScore(Amount.lots, Amount.little), 0);
      expect(waterScore(Amount.little, Amount.lots), 40);
      expect(spaceScore(Amount.lots, Amount.little), 0);
      expect(spaceScore(Amount.little, Amount.lots), 85);
    });
  });

  group('US-10 citation', () {
    test('guide-backed plants cite the guide, edition and section', () {
      final ghaf = seedPlants.firstWhere((p) => p.id == 'p01');
      final c = citationFor(ghaf)!;
      expect(c.guide, 'Manual of Riyadh Plants');
      expect(c.edition, isNotEmpty);
      expect(c.section, 'Trees');
    });

    test('plants outside the guide have no citation, so the UI labels them (NFR-01)', () {
      final pothos = seedPlants.firstWhere((p) => p.id == 'p34');
      expect(citationFor(pothos), isNull);
      for (final p in seedPlants) {
        expect(citationFor(p) != null, p.guideBacked);
      }
    });
  });

  group('US-11 not covered', () {
    test('a city without guide data gets "not covered" instead of a ranking (AC-01)', () {
      expect(recommend(seedPlants, indoorDark.copyWith(city: 'jeddah')), isA<NotCovered>());
    });

    test('when nothing fits, the answer that ruled out most plants is named (AC-02)', () {
      final outdoorOnly = [plant('a'), plant('b'), plant('c', sun: Sun.shade)];
      final o = recommend(outdoorOnly, indoorDark);
      expect(o, isA<NothingFits>());
      expect((o as NothingFits).blocker, Blocker.place);
      expect(o.excluded, 3);
      expect(questionFor(o.blocker, indoorDark), Question.spot);
    });

    test('toxic plants count against the children or pets answer', () {
      final toxic = [for (final id in ['a', 'b']) plant(id, placements: {Placement.indoor}, sun: Sun.shade, water: Water.medium)]
          .map((p) => Plant(
                id: p.id,
                nameAr: p.nameAr,
                nameEn: p.nameEn,
                scientificName: p.scientificName,
                category: PlantCategory.houseplant,
                placements: p.placements,
                sun: p.sun,
                water: p.water,
                wateringEveryDays: 7,
                toxic: true,
                descriptionAr: '',
                descriptionEn: '',
                source: 'test',
              ))
          .toList();
      final o = recommend(toxic, indoorDark.copyWith(kidsOrPets: true)) as NothingFits;
      expect(o.blocker, Blocker.safety);
      expect(questionFor(o.blocker, indoorDark), Question.kidsOrPets);
    });
  });
}
