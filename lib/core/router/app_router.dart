import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/shell/presentation/shell_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/audio_player_screen.dart';
import '../../features/quran/presentation/screens/quran_screen.dart';
import '../../features/quran/presentation/screens/surah_read_screen.dart';
import '../../features/duas/presentation/screens/duas_screen.dart';
import '../../features/duas/presentation/screens/dua_reader_screen.dart';
import '../../features/tasbih/presentation/screens/tasbih_screen.dart';
import '../../features/downloads/presentation/screens/downloads_screen.dart';
import '../../features/prayer_times/presentation/screens/prayer_times_screen.dart';
import '../../features/islamic_calendar/presentation/screens/islamic_calendar_screen.dart';
import '../../features/infallibles/presentation/screens/infallibles_screen.dart';
import '../../features/hadith/presentation/screens/hadith_screen.dart';
import '../widgets/section_disabled_placeholder.dart';
import '../../features/allah_names/presentation/screens/allah_names_screen.dart';
import '../../features/admin/presentation/screens/admin_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  debugLogDiagnostics: false,
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => ShellScreen(child: child),
      routes: [
        GoRoute(path: '/home', pageBuilder: (c, s) => const NoTransitionPage(child: HomeScreen())),
        GoRoute(path: '/quran', pageBuilder: (c, s) => const NoTransitionPage(child: QuranScreen())),
        GoRoute(path: '/duas', pageBuilder: (c, s) => const NoTransitionPage(child: DuasScreen())),
        GoRoute(path: '/tasbih', pageBuilder: (c, s) => const NoTransitionPage(child: TasbihScreen())),
        GoRoute(path: '/downloads', pageBuilder: (c, s) => const NoTransitionPage(child: DownloadsScreen())),
        GoRoute(path: '/prayer-times', pageBuilder: (c, s) => const NoTransitionPage(child: PrayerTimesScreen())),
        GoRoute(path: '/calendar', pageBuilder: (c, s) => const NoTransitionPage(child: IslamicCalendarScreen())),
        GoRoute(path: '/infallibles', pageBuilder: (c, s) => const NoTransitionPage(child: InfalliblesScreen())),
        GoRoute(path: '/hadith', pageBuilder: (c, s) => const NoTransitionPage(child: HadithScreen())),
        // Adhkar content paused pending better/verified text sources —
        // shows the same "قيد التطوير" placeholder used for
        // remotely-disabled sections until real content is supplied.
        GoRoute(
          path: '/daily-amaal',
          pageBuilder: (c, s) => const NoTransitionPage(
            child: SectionDisabledPlaceholder(
              message: 'سيتم إضافة نصوص الأذكار قريباً بعد مراجعتها',
            ),
          ),
        ),
        GoRoute(path: '/allah-names', pageBuilder: (c, s) => const NoTransitionPage(child: AllahNamesScreen())),
        GoRoute(path: '/admin', pageBuilder: (c, s) => const NoTransitionPage(child: AdminScreen())),
        GoRoute(path: '/notifications', pageBuilder: (c, s) => const NoTransitionPage(child: NotificationsScreen())),
        GoRoute(path: '/settings', pageBuilder: (c, s) => const NoTransitionPage(child: SettingsScreen())),
      ],
    ),

    // ── Full-screen routes (no shell) ────────────────────────────────────────
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/player/:videoId',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: AudioPlayerScreen(
          videoId: state.pathParameters['videoId']!,
          title: state.uri.queryParameters['title'] ?? '',
          artist: state.uri.queryParameters['channel'] ?? '',
          thumbnailUrl: state.uri.queryParameters['thumbnail'] ?? '',
        ),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic))
                .animate(animation),
            child: child,
          );
        },
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/quran/:surahNumber',
      builder: (context, state) {
        // int.parse (and the old `!` null-check) crashed the whole app on
        // any malformed link — including a typo'd admin_notifications
        // link_url, or any bad/legacy deep link — instead of showing a
        // recoverable error. A Quran has exactly 114 Surahs, so anything
        // outside that range is invalid too, not just non-numeric input.
        final surahNumber =
            int.tryParse(state.pathParameters['surahNumber'] ?? '');
        if (surahNumber == null || surahNumber < 1 || surahNumber > 114) {
          return const _InvalidSurahScreen();
        }
        return SurahReadScreen(
          surahNumber: surahNumber,
          surahNameArabic: state.uri.queryParameters['arabic'] ?? '',
          revelationTypeArabic: state.uri.queryParameters['type'] ?? '',
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/duas/:duaId',
      builder: (context, state) => DuaReaderScreen(duaId: state.pathParameters['duaId']!),
    ),
  ],
);

/// Shown instead of crashing when `/quran/:surahNumber` is opened with an
/// invalid or out-of-range Surah number (malformed deep link, bad admin
/// notification link, stale saved link, etc).
class _InvalidSurahScreen extends StatelessWidget {
  const _InvalidSurahScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: AppColors.accent),
                const SizedBox(height: 16),
                Text(
                  'رقم السورة غير صالح',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => context.go('/quran'),
                  child: const Text('العودة إلى القرآن الكريم', style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
