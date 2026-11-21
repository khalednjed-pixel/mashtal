import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/logic/watering.dart';

/// US-21: the watering frequency and rhythm shown on My Garden cards.
void main() {
  final monday = DateTime(2026, 11, 16, 9);

  test('frequency reads naturally in Arabic and English', () {
    expect(wateringEveryText('en', 1), 'Every day');
    expect(wateringEveryText('en', 3), 'Every 3 days');
    expect(wateringEveryText('ar', 1), 'كل يوم');
    expect(wateringEveryText('ar', 2), 'كل يومين');
    expect(wateringEveryText('ar', 3), 'كل 3 أيام');
    expect(wateringEveryText('ar', 14), 'كل 14 يوماً');
  });

  test('the next watering counts from the last one, else from when it was added', () {
    final plan = WateringPlan(3, from: monday, now: monday.add(const Duration(days: 1)));
    expect(plan.dueInDays, 2);
    expect(plan.isDue, isFalse);
    expect(plan.nextDays(), [false, false, true, false, false, true, false]);
  });

  test('a late plant is due today and then every N days', () {
    final plan = WateringPlan(2, from: monday, now: monday.add(const Duration(days: 5)));
    expect(plan.dueInDays, -3);
    expect(plan.isDue, isTrue);
    expect(plan.nextDays(), [true, false, true, false, true, false, true]);
    expect(nextWateringText('en', plan.dueInDays), '3 days late');
  });

  test('time of day does not matter, only the calendar day', () {
    final late = DateTime(2026, 11, 16, 23, 50);
    final plan = WateringPlan(1, from: late, now: DateTime(2026, 11, 17, 0, 10));
    expect(plan.dueInDays, 0);
    expect(nextWateringText('ar', 0), 'اسقِها اليوم');
    expect(nextWateringText('en', 1), 'Water tomorrow');
  });
}
