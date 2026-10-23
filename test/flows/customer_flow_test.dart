import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

void main() {
  testWidgets('US-01 a guest browses and searches without an account', (tester) async {
    await pumpMashtal(tester);
    expect(location(tester), '/shop');
    expect(find.text('Buy Plants'), findsWidgets);

    await tester.enterText(find.byKey(const Key('searchField')), 'ghaf');
    await tester.pumpAndSettle();
    expect(find.text('Ghaf tree'), findsOneWidget);
  });

  testWidgets('US-01 a guest who reserves signs in and returns to the cart with it kept', (tester) async {
    final app = await pumpMashtal(tester);
    go(tester, '/shop/plant/p01');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_shopping_cart).first);
    await tester.pumpAndSettle();
    expect(app.cartCount, 1);

    go(tester, '/cart');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reserve')));
    await tester.pumpAndSettle();
    expect(location(tester), startsWith('/login'));

    // A new number: code, then name and city.
    await signInWithPhone(tester, '0551112222');
    expect(location(tester), startsWith('/login/profile'));
    await tester.enterText(find.byKey(const Key('nameField')), 'Noura');
    await tester.tap(find.byKey(const Key('createAccount')));
    await tester.pumpAndSettle();

    expect(location(tester), '/cart');
    expect(app.user?.name, 'Noura');
    expect(app.cartCount, 1);
    expect(find.text('Ghaf tree'), findsOneWidget);
  });

  testWidgets('US-01 My Garden asks a guest to sign in and returns there', (tester) async {
    await pumpMashtal(tester);
    await tester.tap(find.text('My Garden'));
    await tester.pumpAndSettle();
    expect(location(tester), '/login?from=%2Fgarden');
    await signInWithPhone(tester, '0500000005');
    expect(location(tester), '/garden');
  });

  testWidgets('US-02 a wrong code shows an error and resend waits 60 seconds', (tester) async {
    await pumpMashtal(tester);
    go(tester, '/login');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('phoneField')), '0551112222');
    await tester.tap(find.byKey(const Key('sendCode')));
    await tester.pumpAndSettle();

    final demo = tester.widget<Text>(find.byKey(const Key('demoCode'))).data!;
    final code = RegExp(r'\d{6}').firstMatch(demo)![0]!;
    await tester.enterText(find.byKey(const Key('codeField')), code == '000000' ? '111111' : '000000');
    await tester.tap(find.byKey(const Key('verify')));
    await tester.pumpAndSettle();
    expect(find.text('The code is incorrect. Check it and try again.'), findsOneWidget);

    expect(tester.widget<TextButton>(find.byKey(const Key('resend'))).onPressed, isNull);
    await tester.pump(const Duration(seconds: 61));
    expect(tester.widget<TextButton>(find.byKey(const Key('resend'))).onPressed, isNotNull);
  });

  testWidgets('US-02 the sign-in error is in Arabic by default', (tester) async {
    await pumpMashtal(tester, lang: 'ar');
    go(tester, '/login');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('phoneField')), '0112345678');
    await tester.tap(find.byKey(const Key('sendCode')));
    await tester.pumpAndSettle();
    expect(find.text('أدخل رقم جوال سعودي صحيح يبدأ بـ 05'), findsOneWidget);
    // Phone numbers stay left-to-right inside the right-to-left layout.
    expect(tester.widget<TextField>(find.byKey(const Key('phoneField'))).textDirection, TextDirection.ltr);
    expect(Directionality.of(tester.element(find.byType(Scaffold).first)), TextDirection.rtl);
  });
}
