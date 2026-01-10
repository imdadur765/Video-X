import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color _primaryColor = Color(0xFF2979FF); // Electric Blue
  static const Color _surfaceColor = Color(0xFF1E1E1E);
  static const Color _backgroundColor = Color(0xFF0F0F0F); // Deep Black
  static const Color _accentColor = Color(0xFF00E5FF); // Cyan

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _backgroundColor,
    primaryColor: _primaryColor,
    cardColor: _surfaceColor,
    canvasColor: _backgroundColor,

    colorScheme: const ColorScheme.dark(
      primary: _primaryColor,
      secondary: _accentColor,
      surface: _surfaceColor,
      background: _backgroundColor,
      error: Color(0xFFCF6679),
    ),

    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white),
      titleLarge: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
      bodyLarge: GoogleFonts.outfit(fontSize: 16, color: Colors.white70),
      bodyMedium: GoogleFonts.outfit(fontSize: 14, color: Colors.white60),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),

    iconTheme: const IconThemeData(color: Colors.white),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
