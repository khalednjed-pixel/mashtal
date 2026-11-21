import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/logic/share.dart';

void main() {
  test('a plant link opens the plant page on the same site', () {
    final link = plantLink('p04', base: Uri.parse('https://example.github.io/mashtal/?x=1#/cart'));
    expect(link.toString(), 'https://example.github.io/mashtal/#/shop/plant/p04');
  });

  test('the message names the plant, its lowest price and the link', () {
    final link = Uri.parse('https://example.github.io/mashtal/#/shop/plant/p04');
    expect(
      shareMessage(lang: 'en', plantName: 'Date palm', fromPrice: 380, link: link),
      'Have a look at this plant on Mashtal: Date palm — from SAR 380\n$link',
    );
    expect(shareMessage(lang: 'ar', plantName: 'نخلة التمر', fromPrice: 12.5, link: link), contains('من 12.50 ر.س'));
    expect(shareMessage(lang: 'en', plantName: 'Date palm', link: link), isNot(contains('SAR')), reason: 'no price when nobody has it in stock');
  });

  test('WhatsApp gets the whole message, encoded', () {
    final uri = whatsAppShare('a & b\nc');
    expect(uri.host, 'wa.me');
    expect(uri.queryParameters['text'], 'a & b\nc');
  });
}
