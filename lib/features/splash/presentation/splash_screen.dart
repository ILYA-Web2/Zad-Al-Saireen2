import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/hive_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _subtitleFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
          milliseconds: AppConstants.splashAnimationDuration),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _subtitleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    await _controller.forward();

    // If Hive failed to initialize during bootstrap (network hiccup,
    // browser storage permission issue on web, etc.), calling into it
    // here used to throw with nothing catching it — which silently
    // killed this function before it ever reached `context.go('/home')`
    // below, leaving the person stuck looking at the splash screen
    // forever with no error shown anywhere. Now it degrades safely
    // instead: treat an unreadable "first launch" flag as "not first
    // launch" (shorter splash) rather than let the whole sequence die.
    var isFirst = false;
    var onboardingSeen = true;
    try {
      isFirst = HiveService.instance.isFirstLaunch();
      if (isFirst) await HiveService.instance.markLaunched();
      onboardingSeen = HiveService.instance.getSetting<bool>('onboarding_seen') ?? false;
    } catch (e) {
      debugPrint('[SplashScreen] Hive unavailable, continuing anyway: $e');
    }

    final delay = isFirst
        ? AppConstants.splashDurationFirstLaunch
        : AppConstants.splashDurationReturn;

    await Future.delayed(Duration(milliseconds: delay));

    if (mounted) {
      // Onboarding (intro + theme choice + permissions) didn't exist
      // before at all — every first launch used to land directly on the
      // home screen with zero orientation.
      context.go(onboardingSeen ? '/home' : '/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Stack(
        children: [
          // Theme-aware background (true black in dark mode, true white in
          // light mode — no more hardcoded green gradient).
          Container(
            decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
          ),

          // Subtle geometric pattern overlay
          Positioned.fill(
            child: CustomPaint(painter: _IslamicPatternPainter()),
          ),

          // Main content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Real app logo — transparent, no background/border
                    // box around it, exactly as provided.
                    Image.asset(
                      'assets/icons/app_icon_transparent.png',
                      width: 132,
                      height: 132,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),

                    // App Name
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: 2.5,
                        shadows: [
                          Shadow(
                            color: AppColors.accentGlow,
                            blurRadius: 20,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Sub-name
                    FadeTransition(
                      opacity: _subtitleFade,
                      child: Text(
                        AppConstants.appSubName,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textMuted,
                          letterSpacing: 4.0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Decorative divider
                    FadeTransition(
                      opacity: _subtitleFade,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 1,
                            color: AppColors.accent.withOpacity(0.4),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 1,
                            color: AppColors.accent.withOpacity(0.4),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Developer name
                    FadeTransition(
                      opacity: _subtitleFade,
                      child: Text(
                        'إعداد: ${AppConstants.developerName}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: AppColors.textMuted,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    FadeTransition(
                      opacity: _subtitleFade,
                      child: Text(
                        'جميع الحقوق محفوظة © ١٤٤٦ هـ',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading indicator at bottom
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _subtitleFade,
              child: Column(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.accent),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'جاري التهيئة...',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IslamicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent.withOpacity(0.04)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const spacing = 60.0;
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        canvas.drawCircle(Offset(x, y), spacing * 0.35, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
