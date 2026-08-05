import 'package:flutter/material.dart';

/// The 4 selectable themes — see خطة_التصميم_الشاملة.md section 2 for the
/// full rationale. Each is a completely independent [ThemeDefinition]
/// (every color is its own literal value, never derived from an
/// `isDark ? a : b` branch) specifically so a color that works in one
/// theme can never accidentally end up wrong in another — the exact
/// "white icon on a white theme" class of bug is structurally impossible
/// here because nothing is shared between definitions.
enum AppTheme { layl, fajr, sepia, kawthar }

extension AppThemeX on AppTheme {
  String get arabicName {
    switch (this) {
      case AppTheme.layl:
        return 'ليل';
      case AppTheme.fajr:
        return 'فجر';
      case AppTheme.sepia:
        return 'الضحى';
      case AppTheme.kawthar:
        return 'كوثر';
    }
  }

  String get arabicDescription {
    switch (this) {
      case AppTheme.layl:
        return 'داكن عميق بلمسة أزرق نيون سماوي';
      case AppTheme.fajr:
        return 'فاتح ناصع بأزرق ملكي هادئ';
      case AppTheme.sepia:
        return 'دافئ مريح للعين، بلا سواد كامل';
      case AppTheme.kawthar:
        return 'كحلي عميق بلمسة ذهبية';
    }
  }

  ThemeDefinition get definition => _definitions[this]!;
}

/// Every single color the app uses, as plain literal values — no branch,
/// no derivation from another theme, no shared default. Each of the 4
/// instances below fills in every field independently.
class ThemeDefinition {
  const ThemeDefinition({
    required this.isDark,
    required this.primaryDark,
    required this.primaryMedium,
    required this.primaryLight,
    required this.accent,
    required this.accentLight,
    required this.accentGlow,
    required this.backgroundDeep,
    required this.backgroundPrimary,
    required this.backgroundCard,
    required this.glassFill,
    required this.glassBorder,
    required this.glassBorderActive,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textArabic,
    required this.textAccent,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
  });

  /// Used only to pick the matching system status-bar icon brightness
  /// and Material [Brightness] — never used for color branching.
  final bool isDark;

  final Color primaryDark;
  final Color primaryMedium;
  final Color primaryLight;

  final Color accent;
  final Color accentLight;
  final Color accentGlow;

  final Color backgroundDeep;
  final Color backgroundPrimary;
  final Color backgroundCard;

  final Color glassFill;
  final Color glassBorder;
  final Color glassBorderActive;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textArabic;
  final Color textAccent;

  final Color success;
  final Color error;
  final Color warning;
  final Color info;
}

final Map<AppTheme, ThemeDefinition> _definitions = {
  // ─── ليل — the original theme, unchanged ────────────────────────────────
  AppTheme.layl: const ThemeDefinition(
    isDark: true,
    primaryDark: Color(0xFF050607),
    primaryMedium: Color(0xFF0A1620),
    primaryLight: Color(0xFF102A3A),
    accent: Color(0xFF00D4FF),
    accentLight: Color(0xFF5CE8FF),
    accentGlow: Color(0x4D00D4FF),
    backgroundDeep: Color(0xFF050506),
    backgroundPrimary: Color(0xFF0B0C0F),
    backgroundCard: Color(0x14FFFFFF),
    glassFill: Color(0x14FFFFFF),
    glassBorder: Color(0x3300D4FF),
    glassBorderActive: Color(0x8000D4FF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFDDE6EA),
    textMuted: Color(0xFF8FA5B0),
    textArabic: Color(0xFFF2F8FB),
    textAccent: Color(0xFF00D4FF),
    success: Color(0xFF3DFDFF),
    error: Color(0xFFEF5350),
    warning: Color(0xFFFF9800),
    info: Color(0xFF00D4FF),
  ),

  // ─── فجر — bright light theme. Accent is a deliberately *darker* royal
  // blue than the neon cyan used elsewhere: the neon tone measured well
  // under 4.5:1 contrast against white, which is exactly the kind of
  // "icon barely visible" bug this whole system exists to prevent.
  AppTheme.fajr: const ThemeDefinition(
    isDark: false,
    primaryDark: Color(0xFFE8F1F8),
    primaryMedium: Color(0xFFD3E6F2),
    primaryLight: Color(0xFFB8D6EA),
    accent: Color(0xFF0B6FA8),
    accentLight: Color(0xFF0E8ACF),
    accentGlow: Color(0x330B6FA8),
    backgroundDeep: Color(0xFFFFFFFF),
    backgroundPrimary: Color(0xFFF7FBFF),
    backgroundCard: Color(0x0A00374D),
    glassFill: Color(0x1200374D),
    glassBorder: Color(0x330B6FA8),
    glassBorderActive: Color(0x800B6FA8),
    textPrimary: Color(0xFF0A0E12),
    textSecondary: Color(0xFF2E3A42),
    textMuted: Color(0xFF57717D),
    textArabic: Color(0xFF10161A),
    textAccent: Color(0xFF0B6FA8),
    success: Color(0xFF0E8F8C),
    error: Color(0xFFC62828),
    warning: Color(0xFFB25E00),
    info: Color(0xFF0B6FA8),
  ),

  // ─── سيبيا — warm, paper-like, easy on the eyes at night without full
  // black. Accent is a dark bronze/gold, never the neon cyan (which would
  // clash badly with warm tones and also fail contrast on the cream
  // background).
  AppTheme.sepia: const ThemeDefinition(
    isDark: false,
    primaryDark: Color(0xFFF1E4CE),
    primaryMedium: Color(0xFFE6D3B0),
    primaryLight: Color(0xFFD8BE8E),
    accent: Color(0xFF8A5A24),
    accentLight: Color(0xFFA9752F),
    accentGlow: Color(0x338A5A24),
    backgroundDeep: Color(0xFFFBF3E3),
    backgroundPrimary: Color(0xFFF6EAD3),
    backgroundCard: Color(0x0F5C3B14),
    glassFill: Color(0x145C3B14),
    glassBorder: Color(0x338A5A24),
    glassBorderActive: Color(0x808A5A24),
    textPrimary: Color(0xFF2E2010),
    textSecondary: Color(0xFF4A3A22),
    textMuted: Color(0xFF7A6748),
    textArabic: Color(0xFF241A0C),
    textAccent: Color(0xFF8A5A24),
    success: Color(0xFF3D7A4A),
    error: Color(0xFFB33A2E),
    warning: Color(0xFFA9752F),
    info: Color(0xFF8A5A24),
  ),

  // ─── كوثر — deep royal midnight blue instead of true black, with a
  // gold accent for a distinct identity from "ليل" while remaining a
  // dark theme.
  AppTheme.kawthar: const ThemeDefinition(
    isDark: true,
    primaryDark: Color(0xFF060B16),
    primaryMedium: Color(0xFF0B1730),
    primaryLight: Color(0xFF16274A),
    accent: Color(0xFFD4AF37),
    accentLight: Color(0xFFE8CB6E),
    accentGlow: Color(0x4DD4AF37),
    backgroundDeep: Color(0xFF050912),
    backgroundPrimary: Color(0xFF0A1020),
    backgroundCard: Color(0x14FFFFFF),
    glassFill: Color(0x14FFFFFF),
    glassBorder: Color(0x33D4AF37),
    glassBorderActive: Color(0x80D4AF37),
    textPrimary: Color(0xFFF5F1E6),
    textSecondary: Color(0xFFDCD6C8),
    textMuted: Color(0xFF8D93A6),
    textArabic: Color(0xFFF8F4E9),
    textAccent: Color(0xFFD4AF37),
    success: Color(0xFF3DFDFF),
    error: Color(0xFFEF5350),
    warning: Color(0xFFE8CB6E),
    info: Color(0xFFD4AF37),
  ),
};
