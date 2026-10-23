/// Saudi mobile number rules for sign-in (US-02).
class SaudiPhone {
  static final _local = RegExp(r'^05\d{8}$');

  /// Accepts 05XXXXXXXX, 5XXXXXXXX, +9665XXXXXXXX or 009665XXXXXXXX, with
  /// spaces or dashes, and returns the local form 05XXXXXXXX. Returns null
  /// when the input is not a Saudi mobile number.
  static String? normalize(String input) {
    var digits = input.replaceAll(RegExp(r'[\s-]'), '');
    digits = _toWesternDigits(digits);
    if (digits.startsWith('+966')) {
      digits = '0${digits.substring(4)}';
    } else if (digits.startsWith('00966')) {
      digits = '0${digits.substring(5)}';
    } else if (digits.startsWith('966')) {
      digits = '0${digits.substring(3)}';
    } else if (digits.startsWith('5')) {
      digits = '0$digits';
    }
    return _local.hasMatch(digits) ? digits : null;
  }

  /// International form used by SMS providers: +9665XXXXXXXX.
  static String toE164(String local) => '+966${local.substring(1)}';

  static String _toWesternDigits(String s) {
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = eastern.indexOf(ch);
      b.write(i >= 0 ? '$i' : ch);
    }
    return b.toString();
  }
}
