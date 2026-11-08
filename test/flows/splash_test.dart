import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/ui/splash.dart';

void main() {
  testWidgets('opening screen shows briefly, then fades to the app', (tester) async {
    SplashGate.enabled = true;
    addTearDown(() => SplashGate.enabled = false);
    await tester.pumpWidget(const MaterialApp(home: SplashGate(child: Scaffold(body: Text('home')))));
    expect(find.byType(SplashView), findsOneWidget);
    await tester.pump(SplashGate.hold);
    await tester.pumpAndSettle();
    expect(find.byType(SplashView), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });
}
