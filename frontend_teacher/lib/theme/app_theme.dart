import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ===== Black-White Color Palette =====
  // Primary: Black
  // Secondary: White
  // Accent: Grey shades
  // Background: Black
  // Surface: Dark Grey/Black

  static const Color primaryBlack = Color(0xFF000000);
  static const Color primaryGrey = Color(0xFF1F1F1F);
  static const Color secondaryGrey = Color(0xFF2D2D2D);
  static const Color lightGrey = Color(0xFF3A3A3A);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color lightBackground = Color(0xFF000000);
  static const Color textDark = Color(0xFFFFFFFF);

  // ===== Light Theme =====
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryBlack,
        onPrimary: Colors.white,
        primaryContainer: primaryGrey,
        onPrimaryContainer: Colors.white,
        secondary: surfaceWhite,
        onSecondary: primaryBlack,
        secondaryContainer: Color(0xFFE5E5E5),
        onSecondaryContainer: primaryBlack,
        tertiary: lightGrey,
        onTertiary: Colors.white,
        tertiaryContainer: secondaryGrey,
        onTertiaryContainer: Colors.white,
        error: errorRed,
        onError: Colors.white,
        errorContainer: Color(0xFFFEE2E2),
        onErrorContainer: errorRed,
        background: primaryBlack,
        onBackground: Colors.white,
        surface: primaryGrey,
        onSurface: Colors.white,
        surfaceVariant: secondaryGrey,
        onSurfaceVariant: textGrey,
        outline: lightGrey,
        outlineVariant: secondaryGrey,
        scrim: Colors.black,
        inverseSurface: Colors.white,
      ),
      scaffoldBackgroundColor: primaryBlack,
      
      // ===== AppBar Theme =====
      appBarTheme: AppBarTheme(
        backgroundColor: primaryBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // ===== Card Theme =====
      cardTheme: CardTheme(
        color: primaryGrey,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ===== Bottom Navigation Theme =====
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: primaryGrey,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.5),
        indicatorColor: surfaceWhite.withOpacity(0.2),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            );
          }
          return GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textGrey,
          );
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return IconThemeData(color: Colors.white, size: 24);
          }
          return IconThemeData(color: textGrey, size: 24);
        }),
      ),

      // ===== Button Themes =====
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: surfaceWhite,
          foregroundColor: primaryBlack,
          elevation: 2,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: surfaceWhite,
          foregroundColor: primaryBlack,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ===== Input Decoration Theme =====
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryGrey,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: lightGrey, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: lightGrey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: errorRed, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: errorRed, width: 2),
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: textGrey,
        ),
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),

      // ===== Text Themes =====
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        displaySmall: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        headlineLarge: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        titleSmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textGrey,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        labelMedium: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        labelSmall: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textGrey,
        ),
      ),

      // ===== Other Components =====
      chipTheme: ChipThemeData(
        backgroundColor: primaryGrey,
        selectedColor: surfaceWhite.withOpacity(0.2),
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: Colors.white,
        linearMinHeight: 4,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: surfaceWhite,
        foregroundColor: primaryBlack,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryGrey,
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),

      dialogTheme: DialogTheme(
        backgroundColor: primaryGrey,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
    );
  }

  // ===== Dark Theme =====
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryBlack,
        onPrimary: Colors.white,
        primaryContainer: primaryGrey,
        onPrimaryContainer: Colors.white,
        secondary: surfaceWhite,
        onSecondary: primaryBlack,
        secondaryContainer: Color(0xFFE5E5E5),
        onSecondaryContainer: primaryBlack,
        tertiary: lightGrey,
        onTertiary: Colors.white,
        tertiaryContainer: secondaryGrey,
        onTertiaryContainer: Colors.white,
        error: errorRed,
        onError: Colors.white,
        errorContainer: Color(0xFFFEE2E2),
        onErrorContainer: errorRed,
        background: primaryBlack,
        onBackground: Colors.white,
        surface: primaryGrey,
        onSurface: Colors.white,
        surfaceVariant: secondaryGrey,
        onSurfaceVariant: textGrey,
        outline: lightGrey,
        outlineVariant: secondaryGrey,
        scrim: Colors.black,
        inverseSurface: Colors.white,
      ),
      scaffoldBackgroundColor: primaryBlack,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        color: primaryGrey,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
