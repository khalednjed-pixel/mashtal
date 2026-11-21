import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mashtal/app.dart';
import 'package:mashtal/data/local_backend.dart';
import 'package:mashtal/state/app_state.dart';
import 'package:mashtal/ui/splash.dart';
import 'package:mashtal/ui/widgets/plant_photo.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starts the whole app on fresh seed data, in English so finders can use
/// the English labels. Returns the app state for direct checks.
Future<AppState> pumpMashtal(WidgetTester tester, {String lang = 'en', DateTime Function()? clock}) async {
  SharedPreferences.setMockInitialValues({'flutter.mashtal.lang': lang});
  WikiPhotos.enabled = false;
  SplashGate.enabled = false;
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  late AppState app;
  await tester.runAsync(() async {
    final backend = await LocalBackend.open(random: Random(3), clock: clock);
    app = await AppState.create(backend);
  });
  await tester.pumpWidget(ChangeNotifierProvider.value(value: app, child: const MashtalApp()));
  await tester.pumpAndSettle();
  return app;
}

void go(WidgetTester tester, String location) {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
}

/// Signs in through the real sign-in screen using the on-screen demo code.
Future<void> signInWithPhone(WidgetTester tester, String phone) async {
  await tester.enterText(find.byKey(const Key('phoneField')), phone);
  await tester.tap(find.byKey(const Key('sendCode')));
  await tester.pumpAndSettle();
  final demo = tester.widget<Text>(find.byKey(const Key('demoCode'))).data!;
  final code = RegExp(r'\d{6}').firstMatch(demo)![0]!;
  await tester.enterText(find.byKey(const Key('codeField')), code);
  await tester.tap(find.byKey(const Key('verify')));
  await tester.pumpAndSettle();
}

String location(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).routerDelegate.currentConfiguration.uri.toString();

/// Presses and holds the plant page's water ring until it fills.
Future<void> holdToWater(WidgetTester tester) async {
  final ring = find.byKey(const Key('waterNow'));
  await tester.ensureVisible(ring);
  await tester.pumpAndSettle();
  final gesture = await tester.startGesture(tester.getCenter(ring));
  // The fill starts on the next frame and takes WaterRing.holdFor.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1300));
  await gesture.up();
  await tester.pumpAndSettle();
  // The ring shows "Watered" for a moment, then empties again.
  await tester.pump(const Duration(milliseconds: 1300));
  await tester.pumpAndSettle();
}
