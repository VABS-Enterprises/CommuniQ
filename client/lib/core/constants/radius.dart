import 'package:flutter/material.dart';

/// Corner-radius tokens. Generous rounding is core to the playful feel — when
/// in doubt, round more, not less.
class AppRadius {
  static const double chips = 14.0;
  static const double buttons = 18.0;
  static const double cards = 24.0;
  static const double sheet = 32.0;

  /// Fully rounded. Use for stat pills, avatars, streak badges.
  static const double pill = 999.0;

  static BorderRadius get chipRadius => BorderRadius.circular(chips);
  static BorderRadius get buttonRadius => BorderRadius.circular(buttons);
  static BorderRadius get cardRadius => BorderRadius.circular(cards);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);

  /// Top-only rounding for bottom sheets.
  static BorderRadius get sheetRadius => const BorderRadius.vertical(
        top: Radius.circular(sheet),
      );

  @Deprecated('Use AppRadius.pillRadius for the nav bar')
  static const double navigation = 28.0;
  @Deprecated('Use AppRadius.pillRadius for the nav bar')
  static BorderRadius get navigationRadius => BorderRadius.circular(navigation);
}
