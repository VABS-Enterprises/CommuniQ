import 'package:flutter/material.dart';

class AppRadius {
  static const double cards = 24.0;
  static const double buttons = 20.0;
  static const double chips = 12.0;
  static const double navigation = 28.0;

  // BorderRadius objects for convenience
  static BorderRadius get cardRadius => BorderRadius.circular(cards);
  static BorderRadius get buttonRadius => BorderRadius.circular(buttons);
  static BorderRadius get chipRadius => BorderRadius.circular(chips);
  static BorderRadius get navigationRadius => BorderRadius.circular(navigation);
}
