/// A repeating reminder in the phone's own calendar, so watering reminders
/// arrive even with the app closed and without push notifications (which
/// need the paid Firebase plan). Google Calendar's "add event" link opens
/// the calendar app on Android and the website elsewhere.
Uri calendarReminder({
  required String title,
  required String details,
  required DateTime firstDay,
  required int everyDays,
  int hour = 7,
}) {
  final start = DateTime(firstDay.year, firstDay.month, firstDay.day, hour);
  final end = start.add(const Duration(minutes: 15));
  String stamp(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}${_two(t.month)}${_two(t.day)}T${_two(t.hour)}${_two(t.minute)}00';
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': title,
    'details': details,
    'dates': '${stamp(start)}/${stamp(end)}',
    'ctz': 'Asia/Riyadh',
    'recur': 'RRULE:FREQ=DAILY;INTERVAL=$everyDays',
  });
}

String _two(int n) => n.toString().padLeft(2, '0');
