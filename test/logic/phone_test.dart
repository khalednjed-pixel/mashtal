import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/logic/phone.dart';

void main() {
  test('accepts the common ways of writing a Saudi mobile number', () {
    for (final input in ['0551234567', '551234567', '+966551234567', '00966551234567', '055 123 4567', '٠٥٥١٢٣٤٥٦٧']) {
      expect(SaudiPhone.normalize(input), '0551234567', reason: input);
    }
  });

  test('rejects numbers that are not Saudi mobiles', () {
    for (final input in ['', '0112345678', '05512345', '05512345678', '+971551234567', 'abc']) {
      expect(SaudiPhone.normalize(input), isNull, reason: input);
    }
  });

  test('converts to international form', () {
    expect(SaudiPhone.toE164('0551234567'), '+966551234567');
  });
}
