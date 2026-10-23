import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'router.dart';
import 'state/app_state.dart';
import 'ui/theme.dart';

class MashtalApp extends StatefulWidget {
  const MashtalApp({super.key});

  @override
  State<MashtalApp> createState() => _MashtalAppState();
}

class _MashtalAppState extends State<MashtalApp> {
  late final GoRouter _router = buildRouter(context.read<AppState>());

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.select<AppState, String>((a) => a.lang);
    // Keyed by language so every screen rebuilds with the new text and
    // direction; the router keeps the current page.
    return MaterialApp.router(
      key: ValueKey(lang),
      title: lang == 'ar' ? 'مشتل' : 'Mashtal',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: _router,
    );
  }
}
