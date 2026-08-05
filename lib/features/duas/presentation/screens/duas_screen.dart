import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// المكتبة الحسينية — معطّلة مؤقتاً بطلب من فريق التطوير أثناء إعادة بنائها
/// (المرحلة القادمة ستُعيدها بمحتوى مُتحقَّق منه من مصادر موثوقة بدل أي
/// نص كُتب من الذاكرة). البيانات والملفات القديمة (DuaModel/duas_provider)
/// لم تُحذف، فقط شاشة الدخول عُطّلت هنا.
class DuasScreen extends StatelessWidget {
  const DuasScreen({super.key});

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
              Icon(
                Icons.construction_rounded,
                size: 34,
                color: AppColors.accent,
              ),
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
              const SizedBox(height: 8),
              Text(
                'نعمل على إعادة بناء المكتبة الحسينية بمحتوى موثّق\nسيعود القسم قريباً',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
