import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/app_theme_definition.dart';
import '../../../../core/widgets/glass_container.dart';

/// The app's first real Settings screen — previously there wasn't one at
/// all; theme switching (when it existed as a plain dark/light toggle)
/// had no dedicated home anywhere in the navigation.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.settings_rounded, size: 22, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text(
                      'الإعدادات',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),

            // ── Appearance / Theme ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('المظهر', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    ...AppTheme.values.asMap().entries.map((entry) {
                      final i = entry.key;
                      final t = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ThemeCard(theme: t)
                            .animate(delay: (i * 60).ms)
                            .fadeIn(duration: 250.ms)
                            .slideX(begin: 0.04, end: 0),
                      );
                    }),
                    const SizedBox(height: 6),
                    _FollowSystemSwitch(),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── About ────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('حول التطبيق', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverToBoxAdapter(
                child: GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: AppColors.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'زاد السائرين',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.theme});
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    final def = theme.definition;
    final isSelected = !ThemeController.instance.followSystem &&
        ThemeController.instance.selectedTheme == theme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ThemeController.instance.setTheme(theme);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.glassBorder,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            // Live mini-preview swatch — shows this theme's *actual*
            // colors regardless of which theme is currently active, so
            // the choice can be made with confidence up front rather
            // than by switching back and forth to compare.
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: def.backgroundDeep,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: def.glassBorder, width: 1),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: def.accent.withOpacity(0.25)),
                  ),
                  Icon(Icons.brightness_2_rounded, size: 14, color: def.accent),
                  Positioned(
                    bottom: 6,
                    child: Container(width: 24, height: 3, decoration: BoxDecoration(color: def.textMuted, borderRadius: BorderRadius.circular(2))),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(theme.arabicName, style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(theme.arabicDescription, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 22,
              color: isSelected ? AppColors.accent : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowSystemSwitch extends StatelessWidget {
  const _FollowSystemSwitch();

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.smartphone_rounded, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text('اتباع نظام الجهاز (فاتح/داكن)', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
          ),
          Switch(
            value: ThemeController.instance.followSystem,
            onChanged: (v) => ThemeController.instance.setFollowSystem(v),
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}
