import '../models/models.dart';
import 'care_plan.dart';

/// "Going away" in My Garden: how long, and whether someone at home (a maid
/// or family) will water while the customer is away.
class AwayTrip {
  const AwayTrip({required this.from, required this.until, required this.helper});

  final DateTime from;

  /// The day the customer is back.
  final DateTime until;

  /// Someone at home will water.
  final bool helper;

  int get days => _day(until).difference(_day(from)).inDays;

  bool isOver(DateTime now) => !_day(now).isBefore(_day(until));

  static DateTime _day(DateTime t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  Map<String, dynamic> toJson() => {'from': from.toUtc().toIso8601String(), 'until': until.toUtc().toIso8601String(), 'helper': helper};

  factory AwayTrip.fromJson(Map<String, dynamic> j) =>
      AwayTrip(from: DateTime.parse(j['from']), until: DateTime.parse(j['until']), helper: j['helper'] == true);
}

/// Days a plant lasts on one deep watering just before the customer leaves,
/// with nobody watering. The ground and big pots hold water longer than
/// small pots; indoor plants dry slowly. A plain rule, said as advice.
int lastsAloneDays(CarePlan plan) => (plan.everyDays *
        switch (plan.home) {
          PlantHome.ground => 1.5,
          PlantHome.bigPot || PlantHome.indoor => 1.3,
          PlantHome.smallPot => 1.0,
        })
    .floor();

/// The plants that will not last the trip alone. [waterOn] is the first day
/// someone should water it; [times] how many waterings the trip needs, so
/// "once on Sunday" is only said when once is enough.
List<({String gardenId, DateTime waterOn, int times, int everyDays})> needsHelp(List<({GardenPlant garden, CarePlan plan})> plants, AwayTrip trip) => [
      for (final p in plants)
        if (lastsAloneDays(p.plan) case final lasts when lasts < trip.days)
          (
            gardenId: p.garden.id,
            waterOn: trip.from.add(Duration(days: lasts.clamp(1, trip.days))),
            times: ((trip.days - 1) ~/ lasts.clamp(1, trip.days)),
            everyDays: lasts.clamp(1, trip.days),
          ),
    ];

/// The watering plan sent to whoever looks after the plants: one line per
/// plant with where it is and how often, then how to check the soil. In the
/// language the customer picks, since a maid may read English better.
String helperMessage({
  required String lang,
  required String untilText,
  required List<({String name, PlantHome home, int everyDays})> plants,
  required Season season,
}) {
  final ar = lang == 'ar';
  String home(PlantHome h) => switch (h) {
        PlantHome.ground => ar ? 'في الأرض' : 'in the ground',
        PlantHome.bigPot => ar ? 'حوض كبير' : 'big pot',
        PlantHome.smallPot => ar ? 'حوض صغير' : 'small pot',
        PlantHome.indoor => ar ? 'داخل البيت' : 'indoors',
      };
  String every(int d) => ar
      ? switch (d) {
          1 => 'كل يوم',
          2 => 'كل يومين',
          <= 10 => 'كل $d أيام',
          _ => 'كل $d يوماً',
        }
      : (d == 1 ? 'every day' : 'every $d days');
  final lines = [
    ar ? 'خطة سقي النباتات حتى $untilText:' : 'Plant watering plan until $untilText:',
    for (final p in plants) '• ${p.name} (${home(p.home)}): ${every(p.everyDays)}',
    '',
    ar
        ? 'قبل السقي: أدخل إصبعك في التربة. إذا كانت جافة اسقها ببطء حتى تتشرب، وإذا كانت رطبة اتركها لليوم.'
        : "Before watering: push a finger into the soil. If it's dry, water slowly until it's soaked; if it's moist, leave it for today.",
    if (season == Season.summer) ar ? 'في الصيف: اسقِ الصبح بدري أو بعد المغرب.' : 'In summer: water early morning or after sunset.',
    ar ? 'شكراً لك!' : 'Thank you!',
  ];
  return lines.join('\n');
}
