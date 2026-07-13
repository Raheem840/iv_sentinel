import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

// Base text theme using Manrope — imported at runtime from Google Fonts CDN
// (first launch requires internet; cached thereafter)
TextTheme _buildTextTheme(Color primary, Color secondary) {
  return GoogleFonts.manropeTextTheme().copyWith(
    displayLarge: GoogleFonts.manrope(
      fontSize: 48,
      fontWeight: FontWeight.w700,
      color: primary,
      fontFeatures: [const FontFeature.tabularFigures()],
    ),
    displayMedium: GoogleFonts.manrope(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: primary,
      fontFeatures: [const FontFeature.tabularFigures()],
    ),
    titleLarge: GoogleFonts.manrope(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    titleMedium: GoogleFonts.manrope(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    bodyMedium: GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: primary,
    ),
    bodySmall: GoogleFonts.manrope(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: secondary,
    ),
    labelSmall: GoogleFonts.manrope(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: secondary,
      letterSpacing: 0.5,
    ),
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBackgroundDark,
    colorScheme: const ColorScheme.dark(
      surface: kSurfaceDark,
      primary: kStatusGreen,
      error: kStatusRed,
    ),
    textTheme: _buildTextTheme(kTextPrimaryDark, kTextSecondaryDark),
    cardTheme: CardThemeData(
      color: kSurfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorderDark, width: 1),
      ),
    ),
    dividerColor: kBorderDark,
    iconTheme: const IconThemeData(color: kTextSecondaryDark),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? kStatusGreen : kTextSecondaryDark,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? kStatusGreenDim : kBorderDark,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: kStatusGreen,
      thumbColor: kStatusGreen,
      inactiveTrackColor: kBorderDark,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kBackgroundDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kStatusGreen, width: 1.5),
      ),
      labelStyle: GoogleFonts.manrope(color: kTextSecondaryDark, fontSize: 14),
      hintStyle: GoogleFonts.manrope(color: kTextSecondaryDark, fontSize: 14),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kBackgroundDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: kTextPrimaryDark,
      ),
      iconTheme: const IconThemeData(color: kTextPrimaryDark),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kStatusGreen,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
  );
}

ThemeData buildLightTheme() {
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: kBackgroundLight,
    colorScheme: const ColorScheme.light(
      surface: kSurfaceLight,
      primary: kStatusGreen,
      error: kStatusRed,
    ),
    textTheme: _buildTextTheme(kTextPrimaryLight, kTextSecondaryLight),
    cardTheme: CardThemeData(
      color: kSurfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorderLight, width: 1),
      ),
    ),
    dividerColor: kBorderLight,
    iconTheme: const IconThemeData(color: kTextSecondaryLight),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? kStatusGreen : kTextSecondaryLight,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? kStatusGreenDim : kBorderLight,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: kStatusGreen,
      thumbColor: kStatusGreen,
      inactiveTrackColor: kBorderLight,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kBackgroundLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kStatusGreen, width: 1.5),
      ),
      labelStyle: GoogleFonts.manrope(color: kTextSecondaryLight, fontSize: 14),
      hintStyle: GoogleFonts.manrope(color: kTextSecondaryLight, fontSize: 14),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kBackgroundLight,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: kTextPrimaryLight,
      ),
      iconTheme: const IconThemeData(color: kTextPrimaryLight),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kStatusGreen,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
  );
}
