import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';

/// Typography for the "Bold Playful" system.
///
/// Set in Nunito (bundled at `assets/fonts/Nunito.ttf`, a variable font
/// covering ExtraLight→Black). The scale runs deliberately **heavy and tight**:
/// display and headline weights sit at w800/w900 with negative tracking, which
/// is what carries the confident, game-like tone. Body text stays at w600 —
/// even "regular" text in this system is semibold.
class AppTextStyles {
  static const String fontFamily = 'Nunito';

  // ── Display — hero moments only (score reveals, celebration screens) ─────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.0,
    height: 1.1,
    color: AppColors.ink,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.8,
    height: 1.15,
    color: AppColors.ink,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 29,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.2,
    color: AppColors.ink,
  );

  // ── Headline — screen titles ─────────────────────────────────────────────
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.25,
    color: AppColors.ink,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.3,
    color: AppColors.ink,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.3,
    color: AppColors.ink,
  );

  // ── Title — card headers, section labels ─────────────────────────────────
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    height: 1.35,
    color: AppColors.ink,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.4,
    color: AppColors.ink,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: AppColors.ink,
  );

  // ── Body ─────────────────────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.ink,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.inkMuted,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: AppColors.inkMuted,
  );

  // ── Label — buttons, chips, tabs ─────────────────────────────────────────
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
    height: 1.2,
    color: AppColors.ink,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.3,
    height: 1.2,
    color: AppColors.ink,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    height: 1.2,
    color: AppColors.inkMuted,
  );

  // ── Specials ─────────────────────────────────────────────────────────────
  /// Big numerals: XP totals, scores, streak counts. Tabular so digits don't
  /// jitter as a counter animates.
  static const TextStyle numeral = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.0,
    height: 1.0,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Small stat numerals inside pills and badges.
  static const TextStyle numeralSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 1.0,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// ALL-CAPS eyebrow above a section heading.
  static const TextStyle eyebrow = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    height: 1.2,
    color: AppColors.inkSoft,
  );

  /// Transcript / quoted speech in the conversation and feedback screens.
  static const TextStyle quote = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontStyle: FontStyle.italic,
    height: 1.55,
    color: AppColors.inkMuted,
  );
}
