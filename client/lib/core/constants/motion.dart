import 'package:flutter/material.dart';

/// Motion tokens. Bounce is the personality of this design system, so it has to
/// be consistent — screens should pull curves and durations from here rather
/// than inventing a new `Curves.easeInOut, 300ms` each time.
///
/// Built entirely on Flutter's own animation primitives — no extra dependency.
class AppMotion {
  // ── Durations ────────────────────────────────────────────────────────────
  /// Taps, toggles, colour changes. Fast enough to feel instant.
  static const Duration quick = Duration(milliseconds: 180);

  /// The default for most transitions — entrances, expansions.
  static const Duration settle = Duration(milliseconds: 320);

  /// Attention-seeking overshoot: rewards, mascot reactions, level unlocks.
  static const Duration spring = Duration(milliseconds: 420);

  /// Celebration sequences (confetti, score reveal).
  static const Duration celebrate = Duration(milliseconds: 900);

  /// Press feedback. Deliberately near-instant so the button feels mechanical.
  static const Duration press = Duration(milliseconds: 90);

  // ── Curves ───────────────────────────────────────────────────────────────
  /// Overshoots and wobbles back. For things that should feel alive.
  static const Curve springCurve = Curves.elasticOut;

  /// A single confident overshoot — the workhorse for entrances.
  static const Curve pop = Curves.easeOutBack;

  /// Decelerating, no overshoot. For anything reading as "settling into place".
  static const Curve ease = Curves.easeOutCubic;

  /// Symmetric, for reversible state changes.
  static const Curve smooth = Curves.easeInOut;

  // ── Stagger ──────────────────────────────────────────────────────────────
  /// Per-item delay when a list animates in. Kept short — a long stagger makes
  /// a screen feel slow to arrive.
  static const Duration stagger = Duration(milliseconds: 55);

  /// Delay for the [index]-th item in a staggered list, capped so long lists
  /// don't leave the last item waiting seconds to appear.
  static Duration staggerFor(int index, {int cap = 8}) =>
      stagger * (index > cap ? cap : index);
}
