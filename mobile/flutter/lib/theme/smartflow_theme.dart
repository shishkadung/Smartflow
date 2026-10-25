import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SfColors {
  static const bg = Color(0xFFEEF2F7);
  static const bg2 = Color(0xFFF7F9FC);
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0B1F3A);
  static const navy = Color(0xFF0B1F3A);
  static const muted = Color(0xFF526176);
  static const blue = Color(0xFF1D4ED8);
  static const blue2 = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFEDF3FF);
  static const border = Color(0xFFDCE3EC);
  static const gold = Color(0xFFB8860B);
  static const rule = Color(0xFFC5CED6);
  static const green = Color(0xFF15803D);
  static const red = Color(0xFFB91C1C);
  static const eng = Color(0xFF1D4ED8);
  static const hr = Color(0xFF5B21B6);
  static const bud = Color(0xFF047857);
  static const acc = Color(0xFFB45309);
  static const tre = Color(0xFF0F766E);
  static const may = Color(0xFF9F1239);
  static const strapBg = Color(0xFFE8EDF3);
  static const strapBorder = Color(0xFFD3DBE4);
  static const strapInk = Color(0xFF3E4C5E);

  /// Navy until the count is above zero. [live] is green, blue, or overdue red.
  static Color countInk(Object? raw, {Color live = navy}) {
    final text = '${raw ?? ''}'.replaceAll(RegExp(r'[^0-9.]'), '');
    final n = num.tryParse(text);
    if (n == null || n <= 0) return navy;
    return live;
  }

  /// Office identity stays neutral; status and actions own semantic colors.
  static Color dept(String code) => navy;
}

class SfGradients {
  static const pageSky = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [SfColors.bg, SfColors.bg],
  );

  static const navyBand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [SfColors.navy, SfColors.navy],
  );

  static const primaryBtn = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [SfColors.blue, SfColors.blue],
  );

  static const brandTitle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [SfColors.navy, SfColors.navy],
  );

  static const seal = SweepGradient(colors: [SfColors.navy, SfColors.navy]);
}

ThemeData buildSmartflowTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: SfColors.blue,
      primary: SfColors.blue,
      surface: SfColors.paper,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: SfColors.bg,
  );

  final sans = GoogleFonts.sourceSans3TextTheme(
    base.textTheme,
  ).apply(bodyColor: SfColors.ink, displayColor: SfColors.navy);

  return base.copyWith(
    textTheme: sans.copyWith(
      headlineSmall: sans.headlineSmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.4,
      ),
      titleLarge: sans.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      titleMedium: sans.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      bodyLarge: sans.bodyLarge?.copyWith(fontSize: 16, height: 1.4),
      bodyMedium: sans.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
      bodySmall: sans.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.4,
        color: SfColors.muted,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: SfColors.ink,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: SfColors.paper,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: SfColors.paper,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SfColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SfColors.navy,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        side: const BorderSide(color: SfColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SfColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SfColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SfColors.blue, width: 1.5),
      ),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: SfColors.muted,
      ),
    ),
  );
}
