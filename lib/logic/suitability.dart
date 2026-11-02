import '../models/models.dart';

/// Rule-based plant suitability (US-07 to US-11, NFR-02).
///
/// The customer answers a few plain questions about their place. Each plant
/// in the knowledge base gets a score per factor (place, light, water,
/// space) and a weighted total. The score is rules only, no AI, so the same
/// answers always give the same ranking and every number can be traced back
/// to a value in the plant data.

/// Where the plant will live (question 2).
enum Spot { inside, balcony, garden }

/// A three-step answer used for light, space and watering.
enum Amount { little, some, lots }

/// The scored factors, in the order they are shown.
enum Factor { place, light, water, space }

/// What removed a plant from the results. [safety] is the children or pets
/// answer (US-09 AC-02).
enum Blocker { place, light, water, space, safety }

/// The questions of the suitability flow, in order (US-07).
enum Question { city, spot, window, sun, space, watering, kidsOrPets }

/// Cities with guide data (OD-04: Riyadh only at launch).
const Set<String> coveredCities = {'riyadh'};

/// Plants below this total are not recommended (US-11 AC-02).
const int minimumScore = 60;

/// At most this many results are shown (US-09 AC-01).
const int maxResults = 10;

/// Weight of each factor in the total, out of 100.
const Map<Factor, int> factorWeights = {
  Factor.place: 25,
  Factor.light: 30,
  Factor.water: 25,
  Factor.space: 20,
};

class SuitabilityAnswers {
  const SuitabilityAnswers({this.city, this.spot, this.light, this.space, this.watering, this.kidsOrPets});

  final String? city;
  final Spot? spot;

  /// Window answer when [spot] is inside, sun answer otherwise.
  final Amount? light;
  final Amount? space;

  /// How often the customer can water.
  final Amount? watering;
  final bool? kidsOrPets;

  bool get isInside => spot == Spot.inside;

  /// The questions to ask for these answers. The window question is only
  /// asked inside the house, the sun question only outside (US-07 AC-02).
  List<Question> get questions => [
        Question.city,
        Question.spot,
        if (spot == null || isInside) Question.window else Question.sun,
        Question.space,
        Question.watering,
        Question.kidsOrPets,
      ];

  bool isAnswered(Question q) => switch (q) {
        Question.city => city != null,
        Question.spot => spot != null,
        Question.window || Question.sun => light != null,
        Question.space => space != null,
        Question.watering => watering != null,
        Question.kidsOrPets => kidsOrPets != null,
      };

  bool get isComplete => questions.every(isAnswered);

  /// Changing between inside and outside clears the light answer, because
  /// the window and sun questions mean different things.
  SuitabilityAnswers withSpot(Spot value) {
    final sameSide = spot != null && (spot == Spot.inside) == (value == Spot.inside);
    return SuitabilityAnswers(
      city: city,
      spot: value,
      light: sameSide ? light : null,
      space: space,
      watering: watering,
      kidsOrPets: kidsOrPets,
    );
  }

  SuitabilityAnswers copyWith({
    String? city,
    Amount? light,
    Amount? space,
    Amount? watering,
    bool? kidsOrPets,
  }) =>
      SuitabilityAnswers(
        city: city ?? this.city,
        spot: spot,
        light: light ?? this.light,
        space: space ?? this.space,
        watering: watering ?? this.watering,
        kidsOrPets: kidsOrPets ?? this.kidsOrPets,
      );
}

/// How much room a plant needs, from its type.
Amount sizeOf(Plant p) => switch (p.category) {
      PlantCategory.tree || PlantCategory.palm => Amount.lots,
      PlantCategory.shrub || PlantCategory.climber => Amount.some,
      PlantCategory.succulent ||
      PlantCategory.groundcover ||
      PlantCategory.grass ||
      PlantCategory.herb ||
      PlantCategory.houseplant =>
        Amount.little,
    };

Amount lightNeedOf(Plant p) => switch (p.sun) {
      Sun.shade => Amount.little,
      Sun.partial => Amount.some,
      Sun.full => Amount.lots,
    };

Amount waterNeedOf(Plant p) => switch (p.water) {
      Water.low => Amount.little,
      Water.medium => Amount.some,
      Water.high => Amount.lots,
    };

/// Light: matching is best. A bit more light than needed is fine; less
/// light hurts more, and two steps less rules the plant out.
int lightScore(Amount need, Amount have) => switch (have.index - need.index) {
      0 => 100,
      1 => 70,
      2 => 30,
      -1 => 40,
      _ => 0,
    };

/// Water: [have] is how often the customer can water. Watering more than
/// needed is a smaller risk than watering less; two steps less rules it out.
int waterScore(Amount need, Amount have) => switch (have.index - need.index) {
      0 => 100,
      1 => 70,
      2 => 40,
      -1 => 30,
      _ => 0,
    };

/// Space: a plant that fits is fine; one that outgrows the space is not.
int spaceScore(Amount need, Amount have) {
  final d = have.index - need.index;
  if (d == 0) return 100;
  if (d > 0) return 85;
  if (d == -1) return 20;
  return 0;
}

int placeScore(Plant p, Spot spot) {
  final needed = spot == Spot.inside ? Placement.indoor : Placement.outdoor;
  return p.placements.contains(needed) ? 100 : 0;
}

/// One plant's score with its per-factor breakdown (US-09 AC-01).
class PlantScore {
  const PlantScore(this.plant, this.factors, this.total);

  final Plant plant;
  final Map<Factor, int> factors;

  /// Weighted total, 0 to 100.
  final int total;

  /// The factor that pulled the total down the most.
  Factor get weakest => factors.entries.reduce((a, b) => b.value < a.value ? b : a).key;
}

/// Scores [plant] for complete [answers]. Returns null for a toxic plant
/// when there are children or pets, which is never shown (US-09 AC-02).
PlantScore? scorePlant(Plant plant, SuitabilityAnswers answers) {
  assert(answers.isComplete, 'score only complete answers');
  if (answers.kidsOrPets == true && plant.toxic) return null;
  final factors = {
    Factor.place: placeScore(plant, answers.spot!),
    Factor.light: lightScore(lightNeedOf(plant), answers.light!),
    Factor.water: waterScore(waterNeedOf(plant), answers.watering!),
    Factor.space: spaceScore(sizeOf(plant), answers.space!),
  };
  final weighted = factors.entries.fold<int>(0, (sum, e) => sum + e.value * factorWeights[e.key]!);
  return PlantScore(plant, factors, (weighted / 100).round());
}

sealed class SuitabilityOutcome {
  const SuitabilityOutcome();
}

/// The city has no guide data yet (US-11 AC-01).
class NotCovered extends SuitabilityOutcome {
  const NotCovered(this.city);
  final String city;
}

/// Up to [maxResults] plants, best first (US-09).
class Ranked extends SuitabilityOutcome {
  const Ranked(this.results);
  final List<PlantScore> results;
}

/// No plant reached [minimumScore]. [blocker] is the answer that ruled out
/// the most plants, so the customer knows what to change (US-11 AC-02).
class NothingFits extends SuitabilityOutcome {
  const NothingFits(this.blocker, this.excluded);
  final Blocker blocker;
  final int excluded;
}

/// The question to go back to for each blocker.
Question questionFor(Blocker b, SuitabilityAnswers a) => switch (b) {
      Blocker.place => Question.spot,
      Blocker.light => a.isInside ? Question.window : Question.sun,
      Blocker.water => Question.watering,
      Blocker.space => Question.space,
      Blocker.safety => Question.kidsOrPets,
    };

Blocker _blockerOf(Factor f) => switch (f) {
      Factor.place => Blocker.place,
      Factor.light => Blocker.light,
      Factor.water => Blocker.water,
      Factor.space => Blocker.space,
    };

/// Ranks [plants] for [answers]: higher total first, then guide-backed
/// plants before others, then by English name so the order is stable.
SuitabilityOutcome recommend(List<Plant> plants, SuitabilityAnswers answers) {
  final city = answers.city;
  if (city == null || !coveredCities.contains(city)) return NotCovered(city ?? '');

  final kept = <PlantScore>[];
  final blockers = <Blocker, int>{};
  for (final p in plants) {
    final s = scorePlant(p, answers);
    if (s == null) {
      blockers.update(Blocker.safety, (v) => v + 1, ifAbsent: () => 1);
    } else if (s.total < minimumScore || s.factors.values.contains(0)) {
      blockers.update(_blockerOf(s.weakest), (v) => v + 1, ifAbsent: () => 1);
    } else {
      kept.add(s);
    }
  }

  if (kept.isEmpty) {
    if (blockers.isEmpty) return const NothingFits(Blocker.place, 0);
    final top = blockers.entries.reduce((a, b) => b.value > a.value ? b : a);
    return NothingFits(top.key, top.value);
  }

  kept.sort((a, b) {
    final byTotal = b.total.compareTo(a.total);
    if (byTotal != 0) return byTotal;
    if (a.plant.guideBacked != b.plant.guideBacked) return a.plant.guideBacked ? -1 : 1;
    return a.plant.nameEn.compareTo(b.plant.nameEn);
  });
  return Ranked(kept.take(maxResults).toList());
}
