import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Pastel Palette: Matcha & Warm Oatmeal
  static const Color background = Color(0xFFF8F6EE); // Warm Oatmeal Cream
  static const Color surface = Color(0xFFFFFFFF); // Pure white card surface
  static const Color surfaceOatmeal = Color(0xFFF2EFE5); // Secondary oatmeal
  static const Color matchaPastel = Color(0xFFD5E5D5); // Soft Matcha Green
  static const Color matchaDark = Color(0xFF2E5339); // Deep Forest Matcha for text
  static const Color butterPastel = Color(0xFFFDE8A1); // Soft Warm Butter accent
  static const Color peachPastel = Color(0xFFFEE2D5); // Warm Peach alert
  static const Color charcoal = Color(0xFF22252A); // High contrast dark charcoal
  static const Color charcoalLight = Color(0xFF32363D); // Secondary dark
  
  // Text Colors
  static const Color textPrimary = Color(0xFF1E2024);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Border & Dividers
  static const Color borderLight = Color(0x12000000); // 7% opacity black

  static ThemeData get theme {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.light(
        primary: charcoal,
        secondary: matchaPastel,
        surface: surface,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: textPrimary,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: textSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
    );
  }
}
