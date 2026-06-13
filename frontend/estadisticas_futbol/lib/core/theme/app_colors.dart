import 'package:flutter/material.dart';

/// FieldIQ color palette — dark-first design system
abstract class AppColors {
  // ── Surfaces ──────────────────────────────────────────
  static const Color bgDeep    = Color(0xFF080E1A); // page background
  static const Color bgSurface = Color(0xFF0F172A); // sidebar, header
  static const Color bgCard    = Color(0xFF1E293B); // cards
  static const Color bgMuted   = Color(0xFF263045); // inputs, chips

  // ── Borders ───────────────────────────────────────────
  static const Color borderSubtle   = Color(0xFF1E2D40);
  static const Color borderDefault  = Color(0xFF334155);
  static const Color borderStrong   = Color(0xFF475569);

  // ── Brand / Accent ────────────────────────────────────
  static const Color accent        = Color(0xFF10B981); // emerald-500
  static const Color accentDim     = Color(0x2610B981); // accent 15%
  static const Color accentHover   = Color(0xFF059669);

  // ── Semantic ──────────────────────────────────────────
  static const Color info    = Color(0xFF3B82F6); // blue-500
  static const Color infoDim = Color(0x263B82F6);
  static const Color warning = Color(0xFFF59E0B); // amber-500
  static const Color warningDim = Color(0x26F59E0B);
  static const Color danger  = Color(0xFFEF4444); // red-500
  static const Color dangerDim  = Color(0x26EF4444);
  static const Color purple  = Color(0xFF8B5CF6); // violet-500
  static const Color purpleDim  = Color(0x268B5CF6);

  // ── Text ──────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF1F5F9); // slate-100
  static const Color textSecondary = Color(0xFF94A3B8); // slate-400
  static const Color textMuted     = Color(0xFF475569); // slate-600

  // ── Event colors ──────────────────────────────────────
  static const Color eventPassOk    = accent;
  static const Color eventPassBad   = danger;
  static const Color eventShot      = warning;
  static const Color eventGoal      = Color(0xFFFFEB3B);
  static const Color eventFoul      = danger;
  static const Color eventRecovery  = info;
  static const Color eventCard      = warning;
  static const Color eventSave      = purple;

  // ── Pitch ─────────────────────────────────────────────
  static const Color pitchGreen      = Color(0xFF1A6B2E);
  static const Color pitchGreenAlt   = Color(0xFF1D7334);
  static const Color pitchLine       = Color(0x8AFFFFFF);
}