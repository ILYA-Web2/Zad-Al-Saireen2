import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shown instead of a real screen whenever the admin panel has remotely
/// disabled that section for everyone — the same "تحت التطوير" look used
/// for the Duas placeholder, but reusable for any section by name.
class SectionDisabledPlaceholder extends StatelessWidget {
  const SectionDisabledPlaceholder({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/icons/app_icon_transparent.png',
                  width: 88,
                  height: 88,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              Icon(Icons.construction_rounded, size: 34, color: AppColors.accent),
              const SizedBox(height: 14),
              Text(
                'هذا القسم قيد التطوير',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if ((message ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
