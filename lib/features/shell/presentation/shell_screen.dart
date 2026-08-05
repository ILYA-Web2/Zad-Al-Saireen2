import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/admin_notification_overlay.dart';
import '../../../core/widgets/force_update_gate.dart';
import '../../../core/widgets/section_disabled_placeholder.dart';
import '../../../core/providers/remote_config_provider.dart';
import '../../../services/hive_service.dart';
import '../../../services/admin_service.dart';
import '../../quran/presentation/widgets/quran_mini_player.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _currentIndex = 0;
  int _unreadNotifications = 0;

  static const List<String> _routes = [
    '/home', '/quran', '/duas', '/tasbih', '/downloads',
  ];

  // Extra feature routes shown in the drawer
  static const List<_DrawerItem> _baseDrawerItems = [
    _DrawerItem(icon: Icons.access_time_rounded, label: 'أوقات الصلاة', route: '/prayer-times'),
    _DrawerItem(icon: Icons.calendar_month_rounded, label: 'التقويم الهجري', route: '/calendar'),
    _DrawerItem(icon: Icons.star_outline_rounded, label: 'المعصومون الأربعة عشر', route: '/infallibles'),
    _DrawerItem(icon: Icons.format_quote_rounded, label: 'أحاديث أهل البيت', route: '/hadith'),
    _DrawerItem(icon: Icons.check_circle_outline_rounded, label: 'أعمال اليوم', route: '/daily-amaal'),
    _DrawerItem(icon: Icons.auto_awesome_rounded, label: 'أسماء الله الحسنى', route: '/allah-names'),
    _DrawerItem(icon: Icons.notifications_none_rounded, label: 'الإشعارات', route: '/notifications'),
    _DrawerItem(icon: Icons.settings_rounded, label: 'الإعدادات', route: '/settings'),
  ];

  @override
  void initState() {
    super.initState();
    _refreshUnreadNotifications();
    ThemeController.instance.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  /// Real count (not decorative) — same "active minus already-dismissed"
  /// logic [AdminNotificationOverlay] uses, so the badge and the popup
  /// always agree. Best-effort: a failed fetch just leaves the badge at
  /// its last known value instead of showing an error anywhere.
  Future<void> _refreshUnreadNotifications() async {
    try {
      final all = await AdminService.instance.getActiveNotifications();
      final dismissed = HiveService.instance.getDismissedNotificationIds();
      final unread = all.where((n) => !dismissed.contains(n.id)).length;
      if (mounted) setState(() => _unreadNotifications = unread);
    } catch (_) {
      // Keep whatever was last known.
    }
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    // Defense-in-depth against the same "orphaned modal" bug class the
    // share sheet had (see universal_share_sheet.dart's useRootNavigator
    // fix) — closes any other open bottom sheet/dialog still attached to
    // this navigator before swapping pages, so nothing can be left
    // stranded behind regardless of which modal it was.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    setState(() => _currentIndex = index);
    context.go(_routes[index]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.path;
    final index = _routes.indexOf(location);
    if (index != -1 && index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
    // Refresh the badge every time the shell notices a route change —
    // covers "just came back from the notifications screen" without
    // needing a dedicated navigation-result callback.
    _refreshUnreadNotifications();
  }

  List<_DrawerItem> get _drawerItems => [
        ..._baseDrawerItems,
        if (HiveService.instance.isAdminUnlocked())
          const _DrawerItem(icon: Icons.admin_panel_settings_rounded, label: 'الإدارة', route: '/admin'),
      ];

  void _openDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FeaturesDrawer(
        items: _drawerItems,
        unreadNotifications: _unreadNotifications,
        onItemTap: (route) {
          Navigator.pop(context);
          context.go(route);
          setState(() => _currentIndex = -1);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remoteConfig = ref.watch(remoteConfigProvider);

    // Keeps "follow system" mode honest — updates on every rebuild
    // (including the one MediaQuery itself triggers when the device's own
    // theme flips), with no effect at all when the person picked an
    // explicit light/dark override instead of "system".
    ThemeController.instance.updateSystemBrightness(MediaQuery.platformBrightnessOf(context));

    // Force-update takes over the entire screen — checked first, before
    // anything else even renders, since it must be un-skippable.
    final currentVersion = AppConstants.appVersion;
    if (remoteConfig.forceUpdate && isVersionOlderThan(currentVersion, remoteConfig.latestVersion)) {
      return ForceUpdateGate(
        updateUrl: remoteConfig.updateUrl,
        message: remoteConfig.maintenanceMessage,
      );
    }

    final currentPath = GoRouterState.of(context).uri.path;
    final sectionKey = currentPath.startsWith('/') ? currentPath.substring(1) : currentPath;
    final isDisabled = remoteConfig.disabledSections.contains(sectionKey);
    // Extra sections (opened from the "More" drawer — prayer times,
    // calendar, hadith, etc.) get a back button up top and lose the
    // bottom tab bar instead, since none of its 5 tabs actually
    // represent where the person currently is.
    final isExtraSection = !_routes.contains(currentPath);

    // ── Responsive breakpoints (tablet / desktop-web) ─────────────────────
    // Below 600px: unchanged phone layout (bottom bar + drawer sheet).
    // 600px+: a persistent side rail replaces the bottom bar entirely —
    // this used to just be the same phone layout stretched wider, with
    // no actual re-layout at all.
    final width = MediaQuery.sizeOf(context).width;
    final isWideLayout = width >= 600;
    // 1024px+: content additionally gets a centered, capped-width column
    // instead of stretching edge-to-edge across a desktop monitor, which
    // is what "flutter web running on a big screen" looked like before.
    final isDesktopLayout = width >= 1024;

    Widget pageContent = isDisabled
        ? SectionDisabledPlaceholder(message: remoteConfig.maintenanceMessage)
        : widget.child;

    if (isDesktopLayout) {
      pageContent = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: pageContent,
        ),
      );
    }

    final scaffoldBody = Stack(
      children: [
        Container(decoration: BoxDecoration(gradient: AppColors.backgroundGradient)),

        // Page content sits below the header so it is never clipped by it.
        Positioned.fill(
          top: AppConstants.headerHeight,
          child: pageContent,
        ),

        // ── Header ─────────────────────────────────────────────────────
        // Wrapped in its own SafeArea (instead of Scaffold's `appBar`
        // slot) so the title never clips into the status bar, notch, or
        // camera cutout on any device shape — no hardcoded heights.
        SafeArea(
          bottom: false,
          child: GlassAppBar(
            onBack: isExtraSection ? () => context.go('/home') : null,
          ),
        ),

        // Non-blocking connectivity banner — only visible while offline.
        Positioned(
          top: AppConstants.headerHeight + MediaQuery.paddingOf(context).top,
          left: 0,
          right: 0,
          child: const OfflineBanner(),
        ),

        // Broadcast notifications from the admin panel — sits above
        // everything else in this Stack so it truly blocks interaction
        // with the page underneath until dismissed.
        const AdminNotificationOverlay(),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      extendBody: true,
      body: isWideLayout
          ? Row(
              children: [
                _SideNavRail(
                  currentIndex: _currentIndex,
                  onTap: _onNavTap,
                  onMoreTap: () => _openDrawer(context),
                ),
                Expanded(
                  child: Column(
                    children: [
                      if (_currentIndex == 1) const QuranMiniPlayer(),
                      Expanded(child: scaffoldBody),
                    ],
                  ),
                ),
              ],
            )
          : scaffoldBody,
      bottomNavigationBar: (isExtraSection || isWideLayout)
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_currentIndex == 1) const QuranMiniPlayer(),
                AppBottomNavBar(
                  currentIndex: _currentIndex < 0 ? 0 : _currentIndex,
                  onTap: _onNavTap,
                  onMoreTap: () => _openDrawer(context),
                ),
              ],
            ),
    );
  }
}

class _DrawerItem {
  const _DrawerItem({required this.icon, required this.label, required this.route});
  final IconData icon;
  final String label;
  final String route;
}

/// The tablet/desktop counterpart to [AppBottomNavBar] — same 5 sections
/// plus "المزيد", laid out as a persistent vertical rail instead of a
/// bottom bar, which is the actual re-layout (not just a wider version
/// of the phone bar) called for at the 600px breakpoint.
class _SideNavRail extends StatelessWidget {
  const _SideNavRail({required this.currentIndex, required this.onTap, required this.onMoreTap});
  final int currentIndex;
  final void Function(int) onTap;
  final VoidCallback onMoreTap;

  static const List<(IconData, String)> _items = [
    (Icons.home_rounded, 'الرئيسية'),
    (Icons.menu_book_rounded, 'القرآن'),
    (Icons.auto_stories_rounded, 'المكتبة'),
    (Icons.radio_button_on_rounded, 'التسبيح'),
    (Icons.history_rounded, 'السجل'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + AppConstants.headerHeight + 12),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        border: Border(left: BorderSide(color: AppColors.glassBorder, width: 1)),
      ),
      child: Column(
        children: [
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final (icon, label) = entry.value;
            final isSelected = currentIndex == index;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: GestureDetector(
                onTap: () => onTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: isSelected ? Border.all(color: AppColors.accent.withOpacity(0.4), width: 1) : null,
                  ),
                  child: Column(
                    children: [
                      Icon(icon, size: 22, color: isSelected ? AppColors.accent : AppColors.textMuted),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 9,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected ? AppColors.accent : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          GestureDetector(
            onTap: onMoreTap,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  Icon(Icons.grid_view_rounded, size: 20, color: AppColors.textMuted),
                  const SizedBox(height: 4),
                  Text('المزيد', style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturesDrawer extends StatelessWidget {
  const _FeaturesDrawer({required this.items, required this.onItemTap, this.unreadNotifications = 0});
  final List<_DrawerItem> items;
  final void Function(String route) onItemTap;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundDeep.withOpacity(0.93),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.glassBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'المزيد من الأقسام',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: AppColors.glassBorder, height: 1),
              Flexible(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final showBadge = item.route == '/notifications' && unreadNotifications > 0;
                    return GestureDetector(
                      onTap: () => onItemTap(item.route),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.glassFill,
                          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                          border: Border.all(color: AppColors.glassBorder, width: 1.2),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.accent.withOpacity(0.15),
                                  ),
                                  child: Icon(item.icon, size: 20, color: AppColors.accent),
                                ),
                                if (showBadge)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      constraints: const BoxConstraints(minWidth: 16),
                                      decoration: BoxDecoration(
                                        color: AppColors.error,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.backgroundDeep, width: 1.5),
                                      ),
                                      child: Text(
                                        unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                item.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
