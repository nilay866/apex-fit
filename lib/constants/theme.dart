import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class ApexTheme {
  static ThemeData get dark {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: ApexColors.bg,
      primaryColor: ApexColors.accent,
      colorScheme: const ColorScheme.light(
        primary: ApexColors.accent,
        secondary: ApexColors.blue,
        surface: ApexColors.surface,
        error: ApexColors.red,
      ),
      dividerColor: ApexColors.border,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: ApexColors.t1,
          height: 1.0,
          letterSpacing: -1.0,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: ApexColors.t1,
          height: 1.1,
          letterSpacing: -0.4,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ApexColors.t1,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ApexColors.t1,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          color: ApexColors.t1,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          color: ApexColors.t2,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 11,
          color: ApexColors.t3,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: ApexColors.t3,
          letterSpacing: 0.8,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: ApexColors.t3,
          letterSpacing: 1.0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ApexColors.t1,
      ),
      cardTheme: CardThemeData(
        color: ApexColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ApexColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ApexColors.cardAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ApexColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ApexColors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: ApexColors.t3,
          letterSpacing: 0.8,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: ApexColors.t3,
          fontWeight: FontWeight.w400,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ApexColors.darkAction,
        contentTextStyle: GoogleFonts.inter(color: ApexColors.ink),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: ApexColors.surface,
        selectedItemColor: ApexColors.accent,
        unselectedItemColor: ApexColors.t3,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ApexColors.accent,
      ),
    );
  }

  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w700,
    Color color = ApexColors.t1,
  }) {
    return GoogleFonts.dmMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }
}
