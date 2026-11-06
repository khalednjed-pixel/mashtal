import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/ui/customer/choose_screen.dart';

import 'app_harness.dart';

/// Fixes from the review of the Sprint 2 branch (PR #2).
void main() {
  setUp(ChooseScreen.resetSaved);

  Future<void> answer(WidgetTester tester, String option) async {
    await tester.tap(find.byKey(Key('option-$option')));
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester, String phone) async {
    go(tester, '/login');
    await tester.pumpAndSettle();
    await signInWithPhone(tester, phone);
  }

  testWidgets('US-14 the admin edits a plant; the log shows values in the UI language', (tester) async {
    final app = await pumpMashtal(tester, lang: 'ar');
    await signIn(tester, '0500000001');
    go(tester, '/admin/plants');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plantData-p01')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chip-partial')));
    await tester.tap(find.byKey(const Key('toxicSwitch')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('savePlant')));
    await tester.pumpAndSettle();

    final ghaf = app.backend.plantById('p01')!;
    expect(ghaf.toxic, isTrue);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('toxicSwitch'))).value, isTrue);
    expect(find.textContaining('شمس كاملة → شمس جزئية'), findsOneWidget);
    expect(find.textContaining('لا → نعم'), findsOneWidget);
    expect(find.textContaining('full'), findsNothing);
    expect(find.textContaining('true'), findsNothing);
  });

  testWidgets('answers from one account are not shown to the next', (tester) async {
    await pumpMashtal(tester);
    await signIn(tester, '0500000005');
    go(tester, '/choose');
    await tester.pumpAndSettle();
    await answer(tester, 'city-riyadh');
    await answer(tester, 'spot-garden');
    expect(find.byKey(const Key('question-sun')), findsOneWidget);

    go(tester, '/account');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signOut')));
    await tester.pumpAndSettle();

    go(tester, '/choose');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('question-city')), findsOneWidget);
  });

  testWidgets('US-12 nurseries in the answered city come first', (tester) async {
    await pumpMashtal(tester);
    go(tester, '/choose');
    await tester.pumpAndSettle();
    await answer(tester, 'city-riyadh');
    await answer(tester, 'spot-garden');
    await answer(tester, 'sun-lots');
    await answer(tester, 'space-lots');
    await answer(tester, 'watering-some');
    await answer(tester, 'kids-no');
    // Date palm (p04): Al Rawdah in Riyadh at 450, Oasis in Jeddah at 400 (cheaper).
    await tester.scrollUntilVisible(find.byKey(const Key('result-p04')), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('result-p04')));
    await tester.pumpAndSettle();
    final riyadh = tester.getTopLeft(find.byKey(const Key('offer-l3'))).dy;
    final jeddah = tester.getTopLeft(find.byKey(const Key('offer-l35'))).dy;
    expect(riyadh, lessThan(jeddah));
  });
}
