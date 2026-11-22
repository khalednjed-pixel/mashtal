import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/data/repositories.dart';
import 'package:mashtal/ui/widgets/common.dart';

import 'app_harness.dart';

/// Every screen saves through trySave, so a save that fails says so instead
/// of doing nothing.
void main() {
  BuildContext screen(WidgetTester tester) => tester.element(find.byType(Scaffold).first);

  testWidgets('a save that works shows its message and reports success', (tester) async {
    await pumpMashtal(tester);
    late bool ok;
    await tester.runAsync(() async => ok = await trySave(screen(tester), () async {}, done: 'Saved'));
    await tester.pump();
    expect(ok, isTrue);
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('a save that fails says so and reports failure', (tester) async {
    await pumpMashtal(tester);
    late bool ok;
    await tester.runAsync(() async => ok = await trySave(screen(tester), () async => throw StateError('permission-denied'), done: 'Saved'));
    await tester.pump();
    expect(ok, isFalse);
    expect(find.text('Saved'), findsNothing);
    expect(find.text("Couldn't save that. Check your connection and try again."), findsOneWidget);
  });

  testWidgets('a full device gets the storage message, not the generic one', (tester) async {
    await pumpMashtal(tester);
    late bool ok;
    await tester.runAsync(() async => ok = await trySave(screen(tester), () async => throw const StorageFull()));
    await tester.pump();
    expect(ok, isFalse);
    expect(find.textContaining("Couldn't save that"), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('the failure message is in Arabic on Arabic screens', (tester) async {
    await pumpMashtal(tester, lang: 'ar');
    await tester.runAsync(() => trySave(screen(tester), () async => throw StateError('offline')));
    await tester.pump();
    expect(find.text('ما قدرنا نحفظها. تأكد من الاتصال وحاول مرة ثانية.'), findsOneWidget);
  });
}
