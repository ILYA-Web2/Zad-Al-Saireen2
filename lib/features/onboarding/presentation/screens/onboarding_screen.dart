import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/app_theme_definition.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/hive_service.dart';

/// Shown exactly once, on the very first launch — 3 short screens
/// (intro, theme choice, real permission requests with context given
/// before the OS dialog fires) instead of dropping a first-time user
/// straight onto the home screen with zero orientation, which is what
/// happened before (there was no onboarding at all).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == 2) {
      _finish();
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    await HiveService.instance.setSetting('onboarding_seen', true);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _finish,
                  child: Text('تخطّي', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textMuted)),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _IntroPage(),
                  _ThemePickerPage(),
                  _PermissionsPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final isActive = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.accent : AppColors.glassBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _page == 2 ? 'ابدأ' : 'التالي',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withOpacity(0.12),
              border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 1.5),
            ),
            child: Image.asset('assets/icons/app_icon_transparent.png', width: 72, height: 72, fit: BoxFit.contain),
          ),
          const SizedBox(height: 32),
          Text(
            AppConstants.appName,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            'القرآن، الأدعية، أوقات الصلاة، وسيرة أهل البيت عليهم السلام — كل ما تحتاجه في مكان واحد',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textMuted, height: 1.7),
          ),
        ],
      ),
    );
  }
}

class _ThemePickerPage extends StatefulWidget {
  const _ThemePickerPage();

  @override
  State<_ThemePickerPage> createState() => _ThemePickerPageState();
}

class _ThemePickerPageState extends State<_ThemePickerPage> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('اختر المظهر المفضّل لديك', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('يمكنك تغييره لاحقاً من الإعدادات في أي وقت', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 24),
          ...AppTheme.values.map((t) {
            final def = t.definition;
            final isSelected = ThemeController.instance.selectedTheme == t;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ThemeController.instance.setTheme(t);
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: def.backgroundPrimary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? def.accent : def.glassBorder, width: isSelected ? 1.6 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: def.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(t.arabicName, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: def.textPrimary)),
                      ),
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 20,
                        color: isSelected ? def.accent : def.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PermissionsPage extends StatefulWidget {
  const _PermissionsPage();

  @override
  State<_PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<_PermissionsPage> {
  bool _locationGranted = false;
  bool _requesting = false;

  Future<void> _requestLocation() async {
    setState(() => _requesting = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (mounted) {
        setState(() => _locationGranted =
            permission == LocationPermission.always || permission == LocationPermission.whileInUse);
      }
    } catch (_) {
      // Permission plugin unavailable (e.g. web without geolocation
      // support) — leave the toggle off rather than crash onboarding.
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('صلاحية واحدة تجعل التطبيق أدق', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 22, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('الموقع', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ),
                    if (_locationGranted) Icon(Icons.check_circle_rounded, size: 18, color: AppColors.accent),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'تُستخدم فقط لحساب أوقات الصلاة واتجاه القبلة بدقة لموقعك — لا تُستخدم لأي غرض آخر ولا تُشارَك مع أحد.',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted, height: 1.6),
                ),
                const SizedBox(height: 12),
                if (!_locationGranted)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _requesting ? null : _requestLocation,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.accent),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(
                        _requesting ? '...' : 'السماح بالوصول للموقع',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.accent),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'يمكنك أيضاً إدخال مدينتك يدوياً لاحقاً بدلاً من ذلك',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
