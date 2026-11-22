import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/logic/reminders.dart';

void main() {
  test('a calendar reminder repeats every N days from the first due day, at 7 in the morning Riyadh time', () {
    final uri = calendarReminder(title: 'Check the soil of Jasmine', details: 'From Mashtal', firstDay: DateTime(2026, 11, 23, 15), everyDays: 3);
    expect(uri.host, 'calendar.google.com');
    expect(uri.queryParameters['action'], 'TEMPLATE');
    expect(uri.queryParameters['text'], 'Check the soil of Jasmine');
    expect(uri.queryParameters['dates'], '20261123T070000/20261123T071500');
    expect(uri.queryParameters['recur'], 'RRULE:FREQ=DAILY;INTERVAL=3');
    expect(uri.queryParameters['ctz'], 'Asia/Riyadh');
  });
}
