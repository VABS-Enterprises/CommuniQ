import 'package:flutter/material.dart';

/// CommuniQ's colour system — "Bold Playful".
///
/// Light, warm and high-saturation. The defining rule of this system: **every
/// brand colour ships with a `*Dark` partner**, used as the *hard offset
/// shadow* underneath a surface painted in the base colour (see [AppShadow]).
/// That base/shadow pairing is what makes the UI read as chunky and physical
/// rather than flat — it is not decoration, it is the core of the look.
///
/// Reach for a semantic name (`ink`, `outline`, `success`) over a brand name
/// (`coral`, `grape`) wherever one fits — it keeps future re-skins to this file.
class AppColors {
  // ── Ground ───────────────────────────────────────────────────────────────
  /// App background. Warm cream, never pure white — white is reserved for
  /// raised surfaces so cards separate from the page without a heavy border.
  static const Color bg = Color(0xFFFFF9F0);

  /// Recessed wells (progress tracks, inset fields) — reads as "below" [bg].
  static const Color bgSunk = Color(0xFFF4ECE1);

  /// Raised surfaces: cards, sheets, dialogs.
  static const Color surface = Color(0xFFFFFFFF);

  /// Secondary raised surface for banding two adjacent cards.
  static const Color surfaceAlt = Color(0xFFFFF4E2);

  // ── Ink ──────────────────────────────────────────────────────────────────
  static const Color ink = Color(0xFF2B2B3A); // primary text
  static const Color inkMuted = Color(0xFF6B6B7B); // secondary text
  static const Color inkSoft = Color(0xFF9A9AAB); // hints, disabled
  static const Color inkOnDark = Color(0xFFFFFFFF); // text on a brand fill

  // ── Brand ────────────────────────────────────────────────────────────────
  /// Primary CTA. Every prominent action in the app is coral.
  static const Color coral = Color(0xFFFF5A5F);
  static const Color coralDark = Color(0xFFD93F44);
  static const Color coralSoft = Color(0xFFFFE4E5); // tinted background

  /// XP, streaks, coins, first place — anything "earned".
  static const Color sun = Color(0xFFFFC531);
  static const Color sunDark = Color(0xFFE0A400);
  static const Color sunSoft = Color(0xFFFFF3D1);

  /// Growth and completion. Pairs with [success] for scoring.
  static const Color teal = Color(0xFF2EC4B6);
  static const Color tealDark = Color(0xFF22A197);
  static const Color tealSoft = Color(0xFFD6F5F1);

  /// Learning / lessons accent.
  static const Color grape = Color(0xFF8B5CF6);
  static const Color grapeDark = Color(0xFF6D3FD1);
  static const Color grapeSoft = Color(0xFFEDE4FF);

  // ── Status ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF58CC02);
  static const Color successDark = Color(0xFF46A302);
  static const Color successSoft = Color(0xFFE4F8D2);

  static const Color error = Color(0xFFFF4B4B);
  static const Color errorDark = Color(0xFFD63333);
  static const Color errorSoft = Color(0xFFFFE0E0);

  static const Color warning = sun;
  static const Color warningDark = sunDark;
  static const Color warningSoft = sunSoft;

  static const Color info = Color(0xFF1CB0F6);
  static const Color infoDark = Color(0xFF1687BC);
  static const Color infoSoft = Color(0xFFDCF1FE);

  // ── Borders ──────────────────────────────────────────────────────────────
  /// Hairline separator / default card edge.
  static const Color outline = Color(0xFFE3D9CB);

  /// Heavy 2px edge used on chunky interactive surfaces.
  static const Color outlineStrong = Color(0xFF2B2B3A);

  // ── Score tiers ──────────────────────────────────────────────────────────
  // Used by contest results, leaderboards, roleplay feedback. Single source of
  // truth so a score reads the same colour everywhere it appears.
  static const Color scoreExcellent = success;
  static const Color scoreGood = teal;
  static const Color scoreNeedsWork = sun;
  static const Color scorePoor = error;

  /// Maps a 0–100 score to its tier colour.
  static Color forScore(num score) {
    if (score >= 80) return scoreExcellent;
    if (score >= 60) return scoreGood;
    if (score >= 40) return scoreNeedsWork;
    return scorePoor;
  }

  /// The hard-shadow partner for any brand/status colour above. Falls back to
  /// a darkened copy so callers never have to special-case an unknown colour.
  static Color shadowFor(Color base) {
    if (base == coral) return coralDark;
    if (base == sun) return sunDark;
    if (base == teal) return tealDark;
    if (base == grape) return grapeDark;
    if (base == success) return successDark;
    if (base == error) return errorDark;
    if (base == info) return infoDark;
    if (base == surface || base == surfaceAlt) return outline;
    return Color.lerp(base, Colors.black, 0.22)!;
  }

  // ── Rank / podium ────────────────────────────────────────────────────────
  static const Color gold = Color(0xFFFFC531);
  static const Color silver = Color(0xFFB8C4D0);
  static const Color bronze = Color(0xFFD79155);

  // ── Standard ─────────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  /// Scrim behind modals and sheets.
  static const Color scrim = Color(0x662B2B3A);

  // ───────────────────────────────────────────────────────────────────────────
  // MIGRATION SHIM — names from the old dark/neon palette.
  //
  // ~340 raw call sites across 29 view files still use these. They are remapped
  // onto the new light palette so the app compiles and renders coherently while
  // screens are rebuilt phase by phase. Each screen's rebuild should replace
  // these with the semantic names above; this whole block gets deleted in the
  // final cleanup phase. **Do not use these in new code.**
  // ───────────────────────────────────────────────────────────────────────────

  @Deprecated('Use AppColors.coral')
  static const Color primary = coral;
  @Deprecated('Use AppColors.coral')
  static const Color primaryLight = Color(0xFFFF8B8F);
  @Deprecated('Use AppColors.coralSoft')
  static const Color primaryExtraLight = coralSoft;
  @Deprecated('Use AppColors.coralDark')
  static const Color primaryDark = coralDark;

  @Deprecated('Use AppColors.grape')
  static const Color violet = grape;
  @Deprecated('Use AppColors.grape')
  static const Color violetLight = Color(0xFFA98BFF);
  @Deprecated('Use AppColors.teal')
  static const Color secondary = teal;
  @Deprecated('Use AppColors.info')
  static const Color accent = info;

  @Deprecated('Use AppColors.bg')
  static const Color background = bg;
  @Deprecated('Use AppColors.bg')
  static const Color bgDark = bg;
  @Deprecated('Use AppColors.bgSunk')
  static const Color bgDeep = bgSunk;
  @Deprecated('Use AppColors.bgSunk')
  static const Color bgVoid = bgSunk;

  @Deprecated('Use AppColors.surfaceAlt')
  static const Color surfaceVariant = surfaceAlt;
  @Deprecated('Use AppColors.surface')
  static const Color cardSurface = surface;
  @Deprecated('Use AppColors.outline')
  static const Color cardBorder = outline;

  @Deprecated('Glass is gone — use AppColors.surface')
  static const Color glass = surface;
  @Deprecated('Use AppColors.outline')
  static const Color glassBorder = outline;
  @Deprecated('Use AppColors.outline')
  static const Color border = outline;

  @Deprecated('Use AppColors.ink')
  static const Color textPrimary = ink;
  @Deprecated('Use AppColors.inkMuted')
  static const Color textSecondary = inkMuted;
  @Deprecated('Use AppColors.inkSoft')
  static const Color textMuted = inkSoft;

  @Deprecated('Use AppColors.success')
  static const Color emerald = success;
  @Deprecated('Use AppColors.sun')
  static const Color amber = sun;
  @Deprecated('Use AppColors.sun')
  static const Color goldLight = sun;
  @Deprecated('Use AppColors.sunDark')
  static const Color goldDark = sunDark;

  @Deprecated('Use a solid colour + AppShadow.hard')
  static const List<Color> primaryGradient = [coral, Color(0xFFFF7A5F)];
  @Deprecated('Use a solid colour + AppShadow.hard')
  static const List<Color> goldGradient = [sun, sunDark];
  @Deprecated('Use a solid colour + AppShadow.hard')
  static const List<Color> emeraldGradient = [success, successDark];
  @Deprecated('Use a solid colour + AppShadow.hard')
  static const List<Color> roseGradient = [coral, coralDark];
}
