import 'package:flutter/material.dart';

const mashtalGreen = Color(0xFF2E6B3F);
const mashtalSand = Color(0xFFF6F1E7);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: mashtalGreen, surface: mashtalSand);
  return ThemeData(
    colorScheme: scheme,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: mashtalSand,
    appBarTheme: const AppBarTheme(backgroundColor: mashtalSand, centerTitle: false, scrolledUnderElevation: 0),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    ),
  );
}
