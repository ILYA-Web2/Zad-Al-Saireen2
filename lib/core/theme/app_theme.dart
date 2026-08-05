import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'theme_controller.dart';
import '../constants/app_constants.dart';

class AppTheme {
  AppTheme._();

  /// Despite the name (kept for compatibility with the one existing call
  /// site in `main.dart`), this is no longer a fixed dark-only theme —
  /// every `AppColors.x` value it reads below is itself now a getter that
  /// already reflects the live [ThemeController] state, so this
  /// ThemeData genuinely flips between real dark and real light
  /// depending on the active mode without needing a separate
  /// `lightTheme` getter.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: ThemeController.instance.isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundDeep,
      colorScheme: ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.primaryLight,
        surface: AppColors.backgroundPrimary,
        error: AppColors.error,
        onPrimary: AppColors.textPrimary,
        onSecondary: AppColors.textPrimary,
        onSurface: AppColors.textPrimary,
        onError: AppColors.textPrimary,
      ),
      textTheme: _buildTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 10),
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          elevation: 0,
          shadowColor: Colors.transparent,
          // Cut/angled corners instead of rounded ones — the "gaming HUD"
          // frame look (like the sharp-angled border around a game's
          // START button) — plus a crisp, bright border line of its own
          // color so the frame itself reads clearly against any
          // background, not just a flat filled shape.
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            side: BorderSide(color: AppColors.accent, width: 1.4),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.4,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: BorderSide(color: AppColors.glassBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: BorderSide(color: AppColors.glassBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: BorderSide(color: AppColors.accent, width: 1.8),
        ),
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      iconTheme: IconThemeData(color: AppColors.textSecondary, size: 24),
      dividerTheme: DividerThemeData(
        color: AppColors.glassBorder,
        thickness: 0.8,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textMuted,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.accent, width: 2.5),
          borderRadius: BorderRadius.circular(2),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.glassBorder,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accentGlow,
        trackHeight: 4.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.cairo(
        fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
      ),
      displayMedium: GoogleFonts.cairo(
        fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      ),
      displaySmall: GoogleFonts.cairo(
        fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.cairo(
        fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.cairo(
        fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.cairo(
        fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.cairo(
        fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
      ),
      titleSmall: GoogleFonts.cairo(
        fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted,
      ),
      bodyLarge: GoogleFonts.cairo(
        fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
      ),
      bodyMedium: GoogleFonts.cairo(
        fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
      ),
      bodySmall: GoogleFonts.cairo(
        fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted,
      ),
      labelLarge: GoogleFonts.cairo(
        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
    );
  }
}
