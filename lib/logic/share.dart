import 'package:flutter/foundation.dart' show kIsWeb;

/// The public web demo, used for links shared from a phone build.
const webDemo = 'https://khalednjed-pixel.github.io/mashtal/';

/// A link that opens [plantId]'s page. On the web it points at the site the
/// customer is using; elsewhere at the public web demo.
Uri plantLink(String plantId, {Uri? base}) {
  final site = base ?? (kIsWeb ? Uri.base : Uri.parse(webDemo));
  return Uri(
    scheme: site.scheme,
    host: site.host,
    port: site.hasPort ? site.port : null,
    path: site.path,
    fragment: '/shop/plant/$plantId',
  );
}

/// The message sent with a shared plant: its name, the lowest price when a
/// nursery has it in stock, and the link. Prices are written with the
/// letters "ر.س" / "SAR", since chat apps may not draw the new riyal sign.
String shareMessage({required String lang, required String plantName, double? fromPrice, required Uri link}) {
  String amount(double p) => p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2);
  final price = fromPrice == null ? '' : (lang == 'ar' ? ' — من ${amount(fromPrice)} ر.س' : ' — from SAR ${amount(fromPrice)}');
  final lead = lang == 'ar' ? 'شف هذي النبتة في مشتل' : 'Have a look at this plant on Mashtal';
  return '$lead: $plantName$price\n$link';
}

/// WhatsApp's share link with [message] filled in.
Uri whatsAppShare(String message) => Uri.https('wa.me', '/', {'text': message});
