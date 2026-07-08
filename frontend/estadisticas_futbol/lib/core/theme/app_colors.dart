import 'package:flutter/material.dart';

/// Central color palette for both application themes.
abstract class AppColors {
  static bool _darkMode = true;

  static bool get isDarkMode => _darkMode;

  static void setDarkMode(bool value) {
    _darkMode = value;
  }

  // Surfaces
  static Color get bgDeep =>
      _darkMode ? const Color(0xFF080E1A) : const Color(0xFFEDF2F5);
  static Color get bgSurface =>
      _darkMode ? const Color(0xFF0F172A) : const Color(0xFFFCFDFE);
  static Color get bgCard =>
      _darkMode ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static Color get bgMuted =>
      _darkMode ? const Color(0xFF263045) : const Color(0xFFE7EDF1);

  // Borders
  static Color get borderSubtle =>
      _darkMode ? const Color(0xFF1E2D40) : const Color(0xFFD8E1E6);
  static Color get borderDefault =>
      _darkMode ? const Color(0xFF334155) : const Color(0xFFC3CFD6);
  static Color get borderStrong =>
      _darkMode ? const Color(0xFF475569) : const Color(0xFF96A5B1);

  // Brand / Accent
  static const Color accent = Color(0xFF10B981);
  static const Color accentDim = Color(0x2610B981);
  static const Color accentHover = Color(0xFF059669);

  // Semantic
  static const Color info = Color(0xFF3B82F6);
  static const Color infoDim = Color(0x263B82F6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDim = Color(0x26F59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerDim = Color(0x26EF4444);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleDim = Color(0x268B5CF6);

  // Text
  static Color get textPrimary =>
      _darkMode ? const Color(0xFFF1F5F9) : const Color(0xFF25323B);
  static Color get textSecondary =>
      _darkMode ? const Color(0xFF94A3B8) : const Color(0xFF5F6F7A);
  static Color get textMuted =>
      _darkMode ? const Color(0xFF64748B) : const Color(0xFF87949D);

  // Event colors
  static const Color eventPassOk = accent;
  static const Color eventPassBad = danger;
  static const Color eventShot = warning;
  static const Color eventGoal = Color(0xFFFFEB3B);
  static const Color eventFoul = danger;
  static const Color eventRecovery = info;
  static const Color eventCard = warning;
  static const Color eventSave = purple;

  // Pitch
  static const Color pitchGreen = Color(0xFF1A6B2E);
  static const Color pitchGreenAlt = Color(0xFF1D7334);
  static const Color pitchLine = Color(0x8AFFFFFF);
}
