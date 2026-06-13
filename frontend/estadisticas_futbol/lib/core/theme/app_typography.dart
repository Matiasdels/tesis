import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract class AppTypography {
  static TextTheme get textTheme => GoogleFonts.interTextTheme(
    const TextTheme(
      // Display
      displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w500, color: AppColors.textPrimary, letterSpacing: -0.5),
      displayMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      // Headlines
      headlineLarge:  TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      headlineSmall:  TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      // Titles
      titleLarge:  TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      titleMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      titleSmall:  TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      // Body
      bodyLarge:   TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.6),
      bodyMedium:  TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.6),
      bodySmall:   TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.5),
      // Labels
      labelLarge:  TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      labelMedium: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      labelSmall:  TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: AppColors.textMuted, letterSpacing: 0.5),
    ),
  );

  // Stat number style — mono for digits
  static TextStyle get statLarge => GoogleFonts.jetBrainsMono(
    fontSize: 28, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
  );
  static TextStyle get statMedium => GoogleFonts.jetBrainsMono(
    fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
  );
  static TextStyle get statSmall => GoogleFonts.jetBrainsMono(
    fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
  );
}