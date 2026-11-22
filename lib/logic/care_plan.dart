import '../models/models.dart';
import 'watering.dart';

/// A garden plant's watering plan: how often to water it now, and when to
/// check the soil next.
///
/// The plant's own interval (`Plant.wateringEveryDays`) is its usual need in
/// mild weather. The plan stretches or shortens it for things a household
/// knows without being a gardener:
///  * the season in Riyadh (summer dries soil fastest, winter slowest),
///  * where the plant lives (a small pot dries much faster than the ground),
///  * whether it is new (new plants need water more often while roots grow),
///  * what the customer told us when the soil was still moist (it learns).
///
/// It is general household advice worked out by rules, not a quote from a
/// guide, and the screens say "check the soil" rather than promising a date.

/// Riyadh's seasons for watering.
enum Season { summer, mild, winter }

/// June to September is summer, December to February winter.
Season riyadhSeason(DateTime when) => switch (when.toLocal().month) {
      6 || 7 || 8 || 9 => Season.summer,
      12 || 1 || 2 => Season.winter,
      _ => Season.mild,
    };

/// A sensible guess when the customer has not said: houseplants indoors,
/// trees, palms, grasses and groundcovers in the ground, the rest in a pot.
PlantHome guessHome(Plant p) {
  if (p.category == PlantCategory.houseplant || !p.placements.contains(Placement.outdoor)) return PlantHome.indoor;
  return switch (p.category) {
    PlantCategory.tree || PlantCategory.palm || PlantCategory.grass || PlantCategory.groundcover => PlantHome.ground,
    _ => PlantHome.bigPot,
  };
}

/// How long a new plant counts as settling in.
const settlingDays = 56;

/// Each "still moist" stretches the plant's own pace by this much...
const paceStep = 1.15;

/// ...up to this.
const maxPace = 2.0;

/// What changed the interval, shown as plain reasons ("summer", "small pot").
enum PlanReason { newPlant, summer, winter, smallPot, bigPot, learned }

class CarePlan {
  CarePlan._({
    required this.everyDays,
    required this.season,
    required this.home,
    required this.homeGuessed,
    required this.settling,
    required this.reasons,
    required this.dueInDays,
    required this.moisture,
    required this.watering,
  });

  factory CarePlan.of(GardenPlant g, Plant p, DateTime now) {
    final season = riyadhSeason(now);
    final home = g.home ?? guessHome(p);
    final indoor = home == PlantHome.indoor;
    final age = now.difference(g.addedAt).inDays;
    final settling = age < settlingDays;

    final seasonFactor = switch (season) {
      Season.summer => indoor ? 0.85 : 0.6,
      Season.mild => 1.0,
      Season.winter => indoor ? 1.3 : 1.6,
    };
    final homeFactor = switch (home) {
      PlantHome.ground || PlantHome.indoor => 1.0,
      PlantHome.bigPot => 0.8,
      PlantHome.smallPot => 0.55,
    };
    final settleFactor = !settling ? 1.0 : (age < 14 ? 0.5 : 0.75);
    final everyDays = (p.wateringEveryDays * seasonFactor * homeFactor * settleFactor * g.pace).round().clamp(1, 45);

    final reasons = [
      if (settling) PlanReason.newPlant,
      if (season == Season.summer) PlanReason.summer,
      if (season == Season.winter) PlanReason.winter,
      if (home == PlantHome.smallPot) PlanReason.smallPot,
      if (home == PlantHome.bigPot) PlanReason.bigPot,
      if (g.pace > 1.0) PlanReason.learned,
    ];

    // After "still moist", look again a little later instead of a whole
    // interval later.
    final watered = g.lastWateredAt ?? g.addedAt;
    final checked = g.lastCheckedAt;
    final WateringPlan watering;
    if (checked != null && checked.isAfter(watered)) {
      final recheck = (everyDays * 0.3).round().clamp(1, 7);
      watering = WateringPlan(recheck, from: checked, now: now);
    } else {
      watering = WateringPlan(everyDays, from: watered, now: now);
    }
    final due = watering.dueInDays;
    final moisture = (due / everyDays).clamp(0.0, 1.0);

    return CarePlan._(
      everyDays: everyDays,
      season: season,
      home: home,
      homeGuessed: g.home == null,
      settling: settling,
      reasons: reasons,
      dueInDays: due,
      moisture: moisture,
      watering: watering,
    );
  }

  /// How often to water now, in days.
  final int everyDays;
  final Season season;
  final PlantHome home;

  /// True when [home] is the app's guess, not the customer's answer.
  final bool homeGuessed;

  /// New plants get water more often for their first weeks.
  final bool settling;
  final List<PlanReason> reasons;

  /// Days until the soil should be checked: 0 today, negative late.
  final int dueInDays;

  /// How much water is likely left in the soil, 1 just watered, 0 dry.
  final double moisture;

  final WateringPlan watering;

  bool get isDue => dueInDays <= 0;

  /// The next seven days, today first: true on days to check and water.
  List<bool> nextDays([int days = 7]) {
    final first = dueInDays < 0 ? 0 : dueInDays;
    return [for (var d = 0; d < days; d++) d >= first && (d - first) % everyDays == 0];
  }
}
