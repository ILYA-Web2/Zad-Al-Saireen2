import 'package:flutter/material.dart';
import 'theme_controller.dart';
import 'app_theme_definition.dart';

/// Every getter here now reads from whichever [ThemeDefinition] is
/// currently active (see app_theme_definition.dart) instead of branching
/// on a single dark/light boolean — the public API (`AppColors.accent`,
/// `AppColors.backgroundDeep`, etc.) is unchanged on purpose, so none of
/// the dozens of screens referencing these names needed to change at all.
class AppColors {
  AppColors._();

  static ThemeDefinition get _t => ThemeController.instance.definition;

  // ─── Primary Palette ────────────────────────────────────────────────────
  static Color get primaryDark => _t.primaryDark;
  static Color get primaryMedium => _t.primaryMedium;
  static Color get primaryLight => _t.primaryLight;

  // ─── Accent ─────────────────────────────────────────────────────────────
  static Color get accent => _t.accent;
  static Color get accentLight => _t.accentLight;
  static Color get accentGlow => _t.accentGlow;

  // ─── Backgrounds ────────────────────────────────────────────────────────
  static Color get backgroundDeep => _t.backgroundDeep;
  static Color get backgroundPrimary => _t.backgroundPrimary;
  static Color get backgroundCard => _t.backgroundCard;

  // ─── Glass Effect ───────────────────────────────────────────────────────
  static Color get glassFill => _t.glassFill;
  static Color get glassBorder => _t.glassBorder;
  static Color get glassBorderActive => _t.glassBorderActive;

  // ─── Text ───────────────────────────────────────────────────────────────
  static Color get textPrimary => _t.textPrimary;
  static Color get textSecondary => _t.textSecondary;
  static Color get textMuted => _t.textMuted;
  static Color get textArabic => _t.textArabic;
  static Color get textAccent => _t.textAccent;

  // ─── Functional Colors ──────────────────────────────────────────────────
  static Color get success => _t.success;
  static Color get error => _t.error;
  static Color get warning => _t.warning;
  static Color get info => _t.info;

  // ─── Gradient Definitions ───────────────────────────────────────────────
  // Derived from the active theme's own colors (rather than a hardcoded
  // cyan) so every theme gets a gradient that actually matches its own
  // identity instead of all 4 themes sharing one theme's brand color.
  static LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_t.backgroundDeep, _t.backgroundPrimary, _t.backgroundDeep],
        stops: const [0.0, 0.6, 1.0],
      );

  static LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_t.accent, _t.accentLight],
      );

  static RadialGradient get tasbihIdleGradient => RadialGradient(
        colors: [_t.accentGlow, _t.primaryDark.withOpacity(0.8)],
        stops: const [0.0, 1.0],
      );

  static RadialGradient get tasbihActiveGradient => RadialGradient(
        colors: [_t.accent.withOpacity(0.5), _t.primaryDark],
        stops: const [0.0, 1.0],
      );

  static RadialGradient get tasbihCompleteGradient => RadialGradient(
        colors: [_t.success.withOpacity(0.8), _t.primaryDark],
        stops: const [0.0, 1.0],
      );

  // ─── Glow Shadows ───────────────────────────────────────────────────────
  // Kept as empty lists (not deleted) per the flat, no-glow visual
  // direction — every existing call site (`boxShadow: AppColors.glowShadow`)
  // keeps compiling unchanged.
  static const List<BoxShadow> glowShadow = [];
  static const List<BoxShadow> glowShadowStrong = [];
  static const List<BoxShadow> cardShadow = [];
}
