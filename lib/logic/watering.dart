import '../models/models.dart';

/// Watering schedule of a garden plant from the knowledge base's watering
/// interval (US-21). Days are calendar days in local time.
class WateringPlan {
  WateringPlan(this.everyDays, {required DateTime from, required DateTime now})
      : _from = _day(from),
        _today = _day(now);

  final int everyDays;
  final DateTime _from;
  final DateTime _today;

  static DateTime _day(DateTime t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  factory WateringPlan.of(GardenPlant g, Plant p, DateTime now) =>
      WateringPlan(p.wateringEveryDays, from: g.lastWateredAt ?? g.addedAt, now: now);

  /// Days from today until the next watering: 0 is today, negative is late.
  int get dueInDays => _from.add(Duration(days: everyDays)).difference(_today).inDays;

  bool get isDue => dueInDays <= 0;

  /// Which of the next [days] days (today first) are watering days. A late
  /// plant is watered today and then every [everyDays] days.
  List<bool> nextDays([int days = 7]) {
    final first = dueInDays < 0 ? 0 : dueInDays;
    return [for (var d = 0; d < days; d++) d >= first && (d - first) % everyDays == 0];
  }
}

/// "Every 3 days" in the app's language, with Arabic number agreement.
String wateringEveryText(String lang, int days) {
  if (lang != 'ar') return days == 1 ? 'Every day' : 'Every $days days';
  if (days == 1) return 'كل يوم';
  if (days == 2) return 'كل يومين';
  if (days <= 10) return 'كل $days أيام';
  return 'كل $days يوماً';
}

/// When the next watering is: today, tomorrow, in N days, or N days late.
String nextWateringText(String lang, int dueInDays) {
  final ar = lang == 'ar';
  if (dueInDays < 0) {
    final late = -dueInDays;
    if (!ar) return late == 1 ? '1 day late' : '$late days late';
    if (late == 1) return 'متأخر يوماً';
    if (late == 2) return 'متأخر يومين';
    return late <= 10 ? 'متأخر $late أيام' : 'متأخر $late يوماً';
  }
  if (dueInDays == 0) return ar ? 'اسقِها اليوم' : 'Water today';
  if (dueInDays == 1) return ar ? 'الري غداً' : 'Water tomorrow';
  if (!ar) return 'Water in $dueInDays days';
  if (dueInDays == 2) return 'الري بعد يومين';
  return dueInDays <= 10 ? 'الري بعد $dueInDays أيام' : 'الري بعد $dueInDays يوماً';
}
