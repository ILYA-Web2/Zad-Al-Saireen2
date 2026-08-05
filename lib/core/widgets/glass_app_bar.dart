import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

class GlassAppBar extends StatefulWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.actions,
    this.showBackground = false,
    this.onBack,
  });

  final List<Widget>? actions;
  final bool showBackground;

  /// When provided, shows a back button on the leading edge instead of
  /// the tappable app name/credit — used for the "extra sections" opened
  /// from the drawer, where a way back matters more than the identity
  /// flourish that makes sense on the 5 main tabs.
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(AppConstants.headerHeight);

  @override
  State<GlassAppBar> createState() => _GlassAppBarState();
}

class _GlassAppBarState extends State<GlassAppBar>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _creditFadeAnimation;

  // A slow, continuous, very subtle breathing glow behind the title —
  // replaces the static app icon that used to sit above the name (removed
  // per request) with a small ambient touch of life instead, without
  // being distracting.
  late final AnimationController _breathController;
  late final Animation<double> _breathAnimation;

  bool _isTapped = false;
  bool _showCredit = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.33),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _creditFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _breathAnimation = CurvedAnimation(parent: _breathController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    _breathController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_isTapped) return;
    setState(() {
      _isTapped = true;
      _showCredit = true;
    });
    await _controller.forward();
    await Future.delayed(
        const Duration(milliseconds: AppConstants.headerDeveloperTextDuration));
    if (mounted) {
      await _controller.reverse();
      setState(() {
        _isTapped = false;
        _showCredit = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppConstants.headerHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glass background (only when tapped)
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, _) {
              if (_fadeAnimation.value == 0) return const SizedBox.shrink();
              return Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDeep
                            .withOpacity(0.70 * _fadeAnimation.value),
                        border: Border(
                          bottom: BorderSide(
                            color:
                                AppColors.glassBorder.withOpacity(_fadeAnimation.value),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Balanced 3-zone layout ──────────────────────────────────────
          // Was a Stack with the title centered via `alignment: center` plus
          // a back button/actions absolutely positioned to one side only —
          // mathematically centered in the full width, but visually looked
          // off-center whenever only one side had an icon (which is most of
          // the time). Reserving an equal-width zone on both sides, empty
          // or not, is what actually fixes that: the title is now centered
          // relative to a truly symmetric layout, not just the raw Stack
          // bounds.
          Positioned.fill(
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: widget.onBack != null ? _BackButton(onTap: widget.onBack!) : null,
                ),
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _slideAnimation,
                      builder: (context, child) => SlideTransition(
                        position: _slideAnimation,
                        child: child,
                      ),
                      child: GestureDetector(
                        onTap: _handleTap,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _breathAnimation,
                              builder: (context, child) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accent.withOpacity(0.12 + 0.10 * _breathAnimation.value),
                                      blurRadius: 16 + 6 * _breathAnimation.value,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: child,
                              ),
                              child: Text(
                                AppConstants.appName,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.reemKufi(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              width: 28,
                              height: 2,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              AppConstants.appSubName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textMuted,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: widget.actions != null
                      ? Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: widget.actions!)
                      : null,
                ),
              ],
            ),
          ),

          // Developer credit — fades in below title
          if (_showCredit)
            Positioned(
              bottom: 4,
              child: AnimatedBuilder(
                animation: _creditFadeAnimation,
                builder: (context, child) => Opacity(
                  opacity: _creditFadeAnimation.value,
                  child: child,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'تم إنشاء هذا التطبيق بواسطة المطور ${AppConstants.developerName}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: AppColors.accentLight,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.accent),
        ),
      ),
    );
  }
}
