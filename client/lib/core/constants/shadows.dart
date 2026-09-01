import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';

/// The shadow language of the "Bold Playful" system.
///
/// The signature effect is [hard]: a **zero-blur** shadow offset straight down,
/// painted in the base colour's `*Dark` partner. It reads as a solid slab under
/// the surface rather than a diffuse glow, which is what gives the UI its
/// chunky, pressable, physical quality.
///
/// Pair [hard] with [pressed] to animate a press: the surface translates down by
/// the difference in offset while its shadow collapses, so the element appears
/// to physically depress. See `ChunkyButton` for the canonical implementation.
class AppShadow {
  /// Default resting depth of an interactive surface, in logical pixels.
  static const double restDepth = 4.0;

  /// Depth while held down. The surface translates down by
  /// `restDepth - pressedDepth` to compensate.
  static const double pressedDepth = 1.0;

  /// The signature hard slab. [base] is the surface colour; the shadow is
  /// automatically derived via [AppColors.shadowFor].
  static List<BoxShadow> hard(Color base, {double y = restDepth}) => [
        BoxShadow(
          color: AppColors.shadowFor(base),
          blurRadius: 0,
          offset: Offset(0, y),
        ),
      ];

  /// Collapsed variant for the held-down state.
  static List<BoxShadow> pressed(Color base) => hard(base, y: pressedDepth);

  /// Explicit shadow colour, for surfaces whose fill isn't a palette colour
  /// (images, gradients) but which still need the hard slab.
  static List<BoxShadow> hardWith(Color shadow, {double y = restDepth}) => [
        BoxShadow(color: shadow, blurRadius: 0, offset: Offset(0, y)),
      ];

  /// Soft ambient lift for surfaces that float above the page — the bottom nav,
  /// bottom sheets, snackbars. Not the chunky look; use sparingly.
  static List<BoxShadow> lifted({double y = 6}) => [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: 0.10),
          blurRadius: 18,
          offset: Offset(0, y),
        ),
      ];

  /// Very soft separation for a resting card that should not look pressable.
  static List<BoxShadow> subtle() => [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  /// A coloured halo used only for celebration moments (level up, new best
  /// score) — the one place a glow is still appropriate.
  static List<BoxShadow> celebrate(Color base) => [
        BoxShadow(
          color: base.withValues(alpha: 0.45),
          blurRadius: 28,
          spreadRadius: 2,
        ),
      ];
}
