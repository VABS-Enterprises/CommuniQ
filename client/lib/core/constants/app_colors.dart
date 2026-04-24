import 'package:flutter/material.dart';

class AppColors {
  // ── Primary ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF5B52F0);       // Electric Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryExtraLight = Color(0xFFA5B4FC);
  static const Color primaryDark = Color(0xFF3730A3);

  // ── Extended Palette ─────────────────────────────────────────────────────
  static const Color violet = Color(0xFF7C3AED);        // Deep Violet
  static const Color violetLight = Color(0xFFA78BFA);   // Soft Violet
  static const Color secondary = Color(0xFF38BDF8);     // Neon Sky
  static const Color accent = Color(0xFF0EA5E9);        // Aurora Blue

  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const Color background = Color(0xFF060918);    // Deepest Void
  static const Color bgDark = Color(0xFF0A1128);        // Midnight Blue
  static const Color bgDeep = Color(0xFF060918);        // Deep Void
  static const Color bgVoid = Color(0xFF020617);        // True Void

  // ── Surfaces ─────────────────────────────────────────────────────────────
  static const Color surface = Color(0xFF0E1628);       // Card Surface
  static const Color surfaceVariant = Color(0xFF1A2640); // Elevated Surface
  static const Color cardSurface = Color(0xFF0D1525);   // Premium Card
  static const Color cardBorder = Color(0xFF1A2744);    // Subtle Border

  // ── Glass ────────────────────────────────────────────────────────────────
  static const Color border = Colors.transparent;
  static const Color glass = Color(0x0DFFFFFF);
  static const Color glassBorder = Color(0xFF1E2D4A);   // Visible glass edge

  // ── Typography ───────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFBECCE3);
  static const Color textMuted = Color(0xFF4E6585);

  // ── Status ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);       // Emerald
  static const Color emerald = Color(0xFF10B981);       // Alias
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);       // Amber
  static const Color amber = Color(0xFFF59E0B);         // Alias

  // ── Gradients ────────────────────────────────────────────────────────────
  static const List<Color> primaryGradient = [Color(0xFF6366F1), Color(0xFF7C3AED)];
  static const List<Color> goldGradient = [Color(0xFFF59E0B), Color(0xFFD97706)];
  static const List<Color> emeraldGradient = [Color(0xFF10B981), Color(0xFF059669)];
  static const List<Color> roseGradient = [Color(0xFFF43F5E), Color(0xFFE11D48)];

  // ── Standard ─────────────────────────────────────────────────────────────
  static const Color white = Colors.white;
  static const Color black = Colors.black;
}
