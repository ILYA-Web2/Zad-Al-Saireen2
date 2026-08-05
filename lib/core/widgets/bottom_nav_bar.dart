import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../constants/app_constants.dart';

class AppBottomNavBar extends StatefulWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onMoreTap,
  });

  final int currentIndex;
  final void Function(int) onTap;

  /// The floating "grid launcher" circular button used to live on its
  /// own next to this bar — merged into the bar itself as a real 6th
  /// item instead, for a cleaner, more unified navigation surface.
  final VoidCallback onMoreTap;

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;
  int _lastTappedIndex = -1;

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_rounded, label: 'الرئيسية'),
    _NavItem(icon: Icons.menu_book_rounded, label: 'القرآن'),
    _NavItem(icon: Icons.auto_stories_rounded, label: 'المكتبة'),
    _NavItem(icon: Icons.radio_button_on_rounded, label: 'التسبيح'),
    _NavItem(icon: Icons.history_rounded, label: 'السجل'),
    _NavItem(icon: Icons.grid_view_rounded, label: 'المزيد'),
  ];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 40),
      TweenSequenceItem(tween: Tween(begin: -10, end: 3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 3, end: 0), weight: 30),
    ]).animate(CurvedAnimation(
        parent: _bounceController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  Future<void> _onItemTapped(int index) async {
    if (index == 5) {
      HapticFeedback.lightImpact();
      widget.onMoreTap();
      return;
    }
    if (index == widget.currentIndex) return;
    HapticFeedback.lightImpact();
    setState(() => _lastTappedIndex = index);
    _bounceController.forward(from: 0.0);
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: AppConstants.bottomNavHeight,
            decoration: BoxDecoration(
              color: AppColors.backgroundDeep.withOpacity(0.75),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(
                color: AppColors.glassBorder,
                width: AppConstants.borderWidth,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                _items.length,
                (index) => _NavBarItem(
                  item: _items[index],
                  isSelected: widget.currentIndex == index,
                  isAnimating: _lastTappedIndex == index,
                  bounceAnimation: _bounceAnimation,
                  onTap: () => _onItemTapped(index),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.isAnimating,
    required this.bounceAnimation,
    required this.onTap,
  });

  final _NavItem item;
  final bool isSelected;
  final bool isAnimating;
  final Animation<double> bounceAnimation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: AppConstants.bottomNavHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: bounceAnimation,
              builder: (context, child) {
                final offset = isAnimating ? bounceAnimation.value : 0.0;
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: child,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 44,
                height: 32,
                decoration: isSelected
                    ? BoxDecoration(
                        color: AppColors.accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: Icon(
                  item.icon,
                  size: 22,
                  color: isSelected ? AppColors.accent : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? AppColors.accent : AppColors.textMuted,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}
