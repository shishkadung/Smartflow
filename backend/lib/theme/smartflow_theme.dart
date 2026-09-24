import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// LGU Urbiztondo SmartFlow — institutional government tokens.
/// SOURCE OF TRUTH for colors/type across Flutter, web, and web-mock.
/// Mirror CSS: web/src/index.css · web-mock/css/tokens.css
class SfColors {
  static const bg = Color(0xFFEEF2F7);
  static const bg2 = Color(0xFFF7F9FC);
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0B1F3A);
  static const navy = Color(0xFF0B1F3A);
  static const muted = Color(0xA30B1F3A);
  static const blue = Color(0xFF1D4ED8);
  static const blue2 = Color(0xFF2563EB);
  static const gold = Color(0xFFB8860B);
  static const rule = Color(0xFFC9B896);
  static const green = Color(0xFF15803D);
  static const red = Color(0xFFB91C1C);
  static const eng = Color(0xFF1D4ED8);
  static const hr = Color(0xFF5B21B6);
  static const bud = Color(0xFF047857);
  static const acc = Color(0xFFB45309);
  static const tre = Color(0xFF0F766E);
  static const may = Color(0xFF9F1239);
  static const strapBg = Color(0xFFF3EFE6);
  static const strapBorder = Color(0xFFC9B896);
  static const strapInk = Color(0xFF5C4A32);

  static Color dept(String code) {
    switch (code.toUpperCase()) {
      case 'ENG':
        return eng;
      case 'HR':
        return hr;
      case 'BUD':
        return bud;
      case 'TRE':
        return tre;
      case 'MAY':
        return may;
      default:
        return acc;
    }
  }
}

class SfGradients {
  static const pageSky = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8EEF6), Color(0xFFEEF2F7), Color(0xFFF7F9FC)],
    stops: [0.0, 0.35, 1.0],
  );

  /// Ceremonial navy wash for auth headers.
  static const navyBand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1A33), Color(0xFF0B1F3A), Color(0xFF123056)],
    stops: [0.0, 0.45, 1.0],
  );

  static const primaryBtn = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [SfColors.blue, SfColors.blue2],
  );

  /// Kept for legacy call sites; prefer solid navy/blue wordmark.
  static const brandTitle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [SfColors.navy, SfColors.blue],
  );

  static const seal = SweepGradient(
    startAngle: 2.1,
    colors: [SfColors.navy, SfColors.rule, SfColors.navy],
  );
}

ThemeData buildSmartflowTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: SfColors.blue,
      primary: SfColors.blue,
      surface: SfColors.bg,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: SfColors.bg,
  );

  final sans = GoogleFonts.sourceSans3TextTheme(base.textTheme).apply(
    bodyColor: SfColors.ink,
    displayColor: SfColors.navy,
  );
  final display = GoogleFonts.sourceSerif4TextTheme(base.textTheme);

  return base.copyWith(
    textTheme: sans.copyWith(
      headlineLarge: display.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: SfColors.navy,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: SfColors.navy,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: SfColors.navy,
      ),
      titleLarge: display.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: SfColors.navy,
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
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SfColors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0x290B1F3A)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0x290B1F3A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0x731D4ED8), width: 1.5),
      ),
      labelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: SfColors.muted,
      ),
    ),
  );
}
