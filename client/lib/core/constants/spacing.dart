/// Spacing scale. Raw `EdgeInsets.all(20)` magic numbers are the single most
/// common inconsistency in the old codebase — reach for these instead.
class AppSpacing {
  static const double s2 = 2.0;
  static const double s4 = 4.0;
  static const double s6 = 6.0;
  static const double s8 = 8.0;
  static const double s10 = 10.0;
  static const double s12 = 12.0;
  static const double s14 = 14.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s28 = 28.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  static const double s48 = 48.0;
  static const double s64 = 64.0;

  // ── Semantic ─────────────────────────────────────────────────────────────
  /// Standard horizontal page margin.
  static const double page = s20;

  /// Padding inside a card.
  static const double card = s16;

  /// Gap between sections on a scrolling screen.
  static const double section = s28;

  /// Gap between sibling items in a list.
  static const double item = s12;

  /// Bottom padding on scroll views so content clears the floating nav bar.
  static const double navClearance = 108.0;

  @Deprecated('Use AppSpacing.s24 or AppSpacing.section')
  static const double lg = s24;
}
