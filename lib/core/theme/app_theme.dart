import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Colors.blue;
  static const Color secondaryColor = Colors.white;
  static const Color accentColor = Colors.green;
  static const Color errorColor = Colors.red;
  static const Color backgroundColor = Color(0xFFF5F7FA);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        error: errorColor,
        background: backgroundColor,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        displayLarge: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        displaySmall: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        headlineMedium: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.cairo(fontWeight: FontWeight.w500),
        titleSmall: GoogleFonts.cairo(fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.cairo(fontWeight: FontWeight.normal),
        bodyMedium: GoogleFonts.cairo(fontWeight: FontWeight.normal),
        bodySmall: GoogleFonts.cairo(fontWeight: FontWeight.normal),
        labelLarge: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        labelMedium: GoogleFonts.cairo(fontWeight: FontWeight.w500),
        labelSmall: GoogleFonts.cairo(fontWeight: FontWeight.w500),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: accentColor,
        error: errorColor,
      ),
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
    );
  }
}
