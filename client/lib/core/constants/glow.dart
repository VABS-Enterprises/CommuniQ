import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/shadows.dart';

/// MIGRATION SHIM — the neon-glow helpers from the old dark theme.
///
/// Glows are meaningless on a light ground, so these now delegate to the soft
/// ambient shadow in [AppShadow] to keep the ~9 remaining call sites compiling
/// and looking sane. Their names no longer describe what they draw.
///
/// **Do not use in new code** — use [AppShadow.hard] for chunky interactive
/// surfaces, [AppShadow.subtle] for resting cards, [AppShadow.celebrate] for
/// reward moments. This file is deleted once the last call site is migrated.
@Deprecated('Use AppShadow')
class AppGlow {
  @Deprecated('Use AppShadow.subtle()')
  static List<BoxShadow> cyanGlow({
    double blurRadius = 16.0,
    double spreadRadius = 2.0,
  }) =>
      AppShadow.subtle();

  @Deprecated('Use AppShadow.subtle()')
  static List<BoxShadow> magentaGlow({
    double blurRadius = 16.0,
    double spreadRadius = 2.0,
  }) =>
      AppShadow.subtle();

  @Deprecated('Use AppShadow.hard(AppColors.surface)')
  static List<BoxShadow> mixedGlow({
    double blurRadius = 16.0,
    double spreadRadius = 2.0,
  }) =>
      AppShadow.hard(AppColors.surface);
}
