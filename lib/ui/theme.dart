import 'package:flutter/material.dart';

/// Mashtal brand tokens. The single source of colour for the app:
/// screens read these through [ThemeData] / [ColorScheme], not as hex values.
abstract final class MashtalColors {
  // "Canopy · Emerald": three layers of forest green on a fresh, near-white page.
  static const forest = Color(0xFF08452D); // canopy: headings, banner, selected nav
  static const forestDeep = Color(0xFF0B2A1A); // ink: primary text on light backgrounds
  static const leaf = Color(0xFF0A7F4B); // secondary actions, links, icons (AA on white)
  static const emerald = Color(0xFF0FB36B); // THE primary action (one per screen), ink label
  static const emeraldLight = Color(0xFF3FD089); // lit side of the primary blend
  static const emeraldDeep = Color(0xFF0A9A5A); // shaded side of the primary blend

  /// Two-tone emerald blend for the primary action and the round action dots:
  /// light at the top-start, deeper at the bottom-end, like a lit leaf.
  static const emeraldBlend = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [emeraldLight, emerald, emeraldDeep],
    stops: [0, 0.45, 1],
  );
  static const sprout = emerald; // positive states, score ring, factor bars
  static const lime = Color(0xFFC9F2A6); // new-growth highlight on the dark canopy only
  static const mint = Color(0xFFCDEFD9); // chips, selected backgrounds, nav indicator
  static const ground = Color(0xFFE8F6EE); // mist: photo tiles and soft tinted surfaces
  static const page = Color(0xFFF6FAF7); // page background
  static const surface = Color(0xFFFFFFFF); // cards
  static const line = Color(0xFFE2EDE6); // borders and dividers
  static const sand = Color(0xFFFFF4D6); // notices that need attention (pending review)
  static const shadow = Color(0x1A0B2A1A); // soft ink shadow for floating things only (nav, product boxes)

  /// Secondary text: forestDeep at reduced opacity (about 8:1 on white).
  static final muted = forestDeep.withValues(alpha: 0.72);

  /// Functional colour for errors and warnings only (not a brand accent).
  static const error = Color(0xFFA4372A);
  static const errorSoft = Color(0xFFF6E3DE);
}

/// Spacing on a 4-pt grid and the two radii used across the app.
abstract final class MashtalSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Side padding for every screen.
  static const screen = 16.0;

  /// Cards, inputs, sheets, dialogs, photos.
  static const radius = 16.0;

  /// White product boxes (shop), with photos inset at [radius].
  static const cardRadius = 24.0;

  /// Chips and pill buttons.
  static const pill = 999.0;
}

typedef _c = MashtalColors; // ignore: camel_case_types

final ColorScheme _scheme = ColorScheme(
  brightness: Brightness.light,
  primary: _c.forest,
  onPrimary: _c.surface,
  primaryContainer: _c.mint,
  onPrimaryContainer: _c.forestDeep,
  secondary: _c.leaf,
  onSecondary: _c.surface,
  secondaryContainer: _c.mint,
  onSecondaryContainer: _c.forestDeep,
  tertiary: _c.emerald,
  onTertiary: _c.forestDeep,
  tertiaryContainer: _c.ground,
  onTertiaryContainer: _c.forestDeep,
  error: _c.error,
  onError: _c.surface,
  errorContainer: _c.errorSoft,
  onErrorContainer: _c.forestDeep,
  surface: _c.surface,
  onSurface: _c.forestDeep,
  onSurfaceVariant: _c.muted,
  surfaceDim: _c.ground,
  surfaceBright: _c.surface,
  surfaceContainerLowest: _c.surface,
  surfaceContainerLow: _c.ground,
  surfaceContainer: _c.ground,
  surfaceContainerHigh: _c.ground,
  surfaceContainerHighest: _c.ground,
  outline: _c.line,
  outlineVariant: _c.line,
  shadow: const Color(0x00000000),
  scrim: _c.forestDeep,
  inverseSurface: _c.forestDeep,
  onInverseSurface: _c.ground,
  inversePrimary: _c.mint,
  surfaceTint: const Color(0x00000000),
);

/// Type scale (sp): 28 title · 20 section · 16 body · 14 secondary · 12 caption.
/// Weights: 400 body, 500 labels, 700 titles. Arabic needs line height >= 1.4.
TextTheme _textTheme() {
  TextStyle s(double size, FontWeight weight, {double height = 1.4, Color? color}) =>
      TextStyle(fontFamily: 'Tajawal', fontFamilyFallback: const ['MashtalRiyal'], fontSize: size, fontWeight: weight, height: height, color: color ?? _c.forestDeep);
  const regular = FontWeight.w400, medium = FontWeight.w500, bold = FontWeight.w700;
  return TextTheme(
    displayLarge: s(28, bold, color: _c.forest),
    displayMedium: s(28, bold, color: _c.forest),
    displaySmall: s(28, bold, color: _c.forest),
    headlineLarge: s(28, bold, color: _c.forest),
    headlineMedium: s(28, bold, color: _c.forest),
    headlineSmall: s(28, bold, color: _c.forest),
    titleLarge: s(20, bold, color: _c.forest),
    titleMedium: s(16, bold),
    titleSmall: s(14, medium),
    bodyLarge: s(16, regular, height: 1.5),
    bodyMedium: s(14, regular, height: 1.5),
    bodySmall: s(12, regular, height: 1.5, color: _c.muted),
    labelLarge: s(16, medium),
    labelMedium: s(14, medium),
    labelSmall: s(12, medium, color: _c.muted),
  );
}

ThemeData buildTheme() {
  final text = _textTheme();
  final radius = BorderRadius.circular(MashtalSpace.radius);
  const pill = StadiumBorder();
  const tapSize = Size(48, 48);

  return ThemeData(
    useMaterial3: true,
    colorScheme: _scheme,
    fontFamily: 'Tajawal',
    fontFamilyFallback: const ['MashtalRiyal'],
    textTheme: text,
    primaryTextTheme: text,
    scaffoldBackgroundColor: _c.page,
    canvasColor: _c.page,
    dividerColor: _c.line,
    splashFactory: InkRipple.splashFactory,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,

    appBarTheme: AppBarTheme(
      backgroundColor: _c.page,
      foregroundColor: _c.forest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: MashtalSpace.screen,
      titleTextStyle: text.titleLarge,
      iconTheme: const IconThemeData(color: _c.forest, size: 24),
      actionsIconTheme: const IconThemeData(color: _c.forest, size: 24),
    ),

    iconTheme: const IconThemeData(color: _c.leaf, size: 24),

    cardTheme: CardThemeData(
      color: _c.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: _c.line)),
    ),

    dividerTheme: const DividerThemeData(color: _c.line, thickness: 1, space: 1),

    listTileTheme: ListTileThemeData(
      iconColor: _c.leaf,
      textColor: _c.forestDeep,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodyMedium?.copyWith(color: _c.muted),
      contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: MashtalSpace.lg),
      minVerticalPadding: MashtalSpace.md,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: MashtalSpace.lg, vertical: MashtalSpace.md),
      hintStyle: text.bodyLarge?.copyWith(color: _c.muted),
      labelStyle: text.bodyLarge?.copyWith(color: _c.muted),
      floatingLabelStyle: text.bodyMedium?.copyWith(color: _c.leaf, fontWeight: FontWeight.w500),
      helperStyle: text.bodySmall,
      errorStyle: text.bodySmall?.copyWith(color: _c.error),
      prefixIconColor: _c.leaf,
      suffixIconColor: _c.leaf,
      border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: _c.line)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: _c.line)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: _c.leaf, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: _c.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: _c.error, width: 1.5)),
    ),

    // Emerald is reserved for the single primary action on a screen. The label is
    // ink, not white: white on this green is only 2.7:1, ink is 5.6:1 (WCAG AA).
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _c.emerald,
        foregroundColor: _c.forestDeep,
        // Paint the emerald blend behind the label (flat line colour when disabled).
        backgroundBuilder: (context, states, child) => DecoratedBox(
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            gradient: states.contains(WidgetState.disabled) ? null : _c.emeraldBlend,
            color: states.contains(WidgetState.disabled) ? _c.line : null,
          ),
          child: child,
        ),
        disabledBackgroundColor: _c.line,
        disabledForegroundColor: _c.muted,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.xl),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        shape: pill,
        elevation: 0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _c.surface,
        foregroundColor: _c.forest,
        minimumSize: tapSize,
        textStyle: text.labelLarge,
        shape: pill,
        elevation: 0,
        side: const BorderSide(color: _c.line),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _c.forest,
        minimumSize: tapSize,
        padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.lg),
        textStyle: text.labelLarge,
        shape: pill,
        side: const BorderSide(color: _c.leaf),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _c.leaf,
        minimumSize: tapSize,
        padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.md),
        textStyle: text.labelLarge,
        shape: pill,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: _c.forest, minimumSize: tapSize),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: _c.surface,
      selectedColor: _c.mint,
      disabledColor: _c.ground,
      checkmarkColor: _c.forest,
      deleteIconColor: _c.leaf,
      iconTheme: const IconThemeData(color: _c.leaf, size: 18),
      labelStyle: text.labelMedium,
      secondaryLabelStyle: text.labelMedium,
      side: const BorderSide(color: _c.line),
      shape: pill,
      padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.sm, vertical: MashtalSpace.xs),
      showCheckmark: false,
      elevation: 0,
      pressElevation: 0,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _c.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: _c.mint,
      indicatorShape: pill,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? _c.forest : _c.muted, size: 24),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? text.labelSmall!.copyWith(color: _c.forest, fontWeight: FontWeight.w700)
            : text.labelSmall!,
      ),
    ),

    // Floating add buttons (nursery listings, admin) are those screens' primary action.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _c.emerald,
      foregroundColor: _c.forestDeep,
      elevation: 2,
      highlightElevation: 4,
      extendedTextStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      shape: pill,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _c.emerald,
      linearTrackColor: _c.line,
      circularTrackColor: Colors.transparent,
    ),

    badgeTheme: BadgeThemeData(
      backgroundColor: _c.forest,
      textColor: _c.surface,
      textStyle: text.labelSmall?.copyWith(color: _c.surface),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: _c.forestDeep,
      contentTextStyle: text.bodyMedium?.copyWith(color: _c.surface),
      actionTextColor: _c.mint,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: _c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radius),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyLarge,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _c.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: _c.surface,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: _c.line,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(MashtalSpace.radius))),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: _c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: _c.line)),
      textStyle: text.bodyLarge,
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? _c.forest : Colors.transparent),
      checkColor: const WidgetStatePropertyAll(_c.surface),
      side: const BorderSide(color: _c.leaf, width: 1.5),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? _c.forest : _c.leaf),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? _c.surface : _c.leaf),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? _c.forest : _c.ground),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? _c.forest : _c.leaf),
    ),

    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: _c.leaf,
      selectionColor: _c.mint,
      selectionHandleColor: _c.leaf,
    ),
  );
}
