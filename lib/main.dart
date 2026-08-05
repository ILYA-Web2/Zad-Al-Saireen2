import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'services/supabase_service.dart';
import 'services/hive_service.dart';
import 'services/quran_audio_handler.dart';
import 'services/youtube_key_rotation_manager.dart';
import 'services/admin_service.dart';
import 'core/utils/hijri_date_converter.dart';

/// Globally registered background audio handler for continuous Surah
/// playback, initialized once before the widget tree is built so every
/// screen and the OS notification / lock-screen controls share the same
/// playback session — this keeps Quran audio alive while backgrounded.
late final QuranAudioHandler quranAudioHandler;

/// Runs a fire-and-forget [task] but never lets it block startup forever:
/// if it doesn't finish within [timeout] or throws, the error is logged and
/// execution continues so `runApp()` is always reached.
///
/// Before this guard existed, a single stuck or throwing initialization
/// call here (Hive / Supabase) would prevent `runApp()` from ever running —
/// which shows up on a real device as a permanently black, unresponsive
/// first screen, since the native Android launch screen never gets
/// replaced by a Flutter frame. It's invisible when running from an IDE
/// (the debugger surfaces the exception immediately) but silent in an
/// installed release build.
Future<void> _bootstrapVoid(
  String label,
  Future<void> Function() task, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    await task().timeout(timeout);
  } catch (e, st) {
    debugPrint('[bootstrap:$label] failed, continuing without it — $e\n$st');
  }
}

/// Same guarantee as [_bootstrapVoid] but for a step that must produce a
/// value — falls back to [fallback] on timeout/failure instead of leaving
/// the caller with nothing.
Future<T> _bootstrapStep<T>(
  String label,
  Future<T> Function() task, {
  required T fallback,
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    return await task().timeout(timeout);
  } catch (e, st) {
    debugPrint('[bootstrap:$label] failed, using fallback — $e\n$st');
    return fallback;
  }
}

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Surface framework/render errors instead of a silent black screen.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('[FlutterError] ${details.exceptionAsString()}');
    };

    // ── System UI styling ─────────────────────────────────────────────────
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await _bootstrapVoid(
      'orientation',
      () => SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]),
      timeout: const Duration(seconds: 3),
    );

    // ── Initialize local storage ────────────────────────────────────────────
    await _bootstrapVoid('hive', () => HiveService.instance.initialize());
    HijriDate.calibrationOffsetDays = HiveService.instance.getHijriCalibrationOffset();

    // ── Initialize Supabase ─────────────────────────────────────────────────
    // Network-dependent — the most likely of the three to stall on a slow
    // or flaky first connection, so it must never be allowed to block
    // startup indefinitely.
    await _bootstrapVoid('supabase', () => SupabaseService.initialize());

    // Fire-and-forget: syncs the shared, database-backed YouTube API key
    // pool for this device. Never awaited — a slow/unreachable database
    // must not add even a millisecond to startup, and the rotation
    // manager already falls back to whatever was cached from the last
    // successful sync (or the compiled defaults, on a brand new install).
    unawaited(YoutubeKeyRotationManager.instance.refreshFromRemote());

    // Also fire-and-forget: silently registers/touches this installation
    // in the hidden, stats-only user registry so the admin panel has a
    // real user count. Never shown to the person using the app, and a
    // failure here (offline, DNS, etc.) is simply ignored.
    unawaited(
      AdminService.instance
          .pingUser(
            HiveService.instance.getOrCreateDeviceId(),
            platform: defaultTargetPlatform.name,
          )
          .catchError((_) {}),
    );

    // ── Initialize background audio session (Quran continuous playback) ────
    // Falls back to a plain (non-background-service) handler if AudioService
    // registration fails or times out, so the app still launches and Quran
    // audio still plays in the foreground even in that degraded case.
    //
    // No custom androidNotificationIcon here on purpose: a custom
    // 'drawable/ic_notification' kept throwing "Invalid notification (no
    // valid small icon)" even after fixing its opacity/content, which means
    // the resource reference itself — not its visual content — was the
    // problem (a stale/misresolved resource ID, most likely). Rather than
    // keep guessing at a custom asset, this uses audio_service's own
    // default icon reference, which is the app's actual launcher icon —
    // already proven to render correctly since it's what's on the device's
    // home screen right now.
    // No custom drawable here on purpose: a custom 'drawable/ic_notification'
    // kept throwing "Invalid notification (no valid small icon)" even after
    // fixing its opacity/content twice, which means the resource reference
    // itself — not its visual content — was the problem (most likely a
    // stale/misresolved resource ID from repeatedly regenerating that
    // drawable). Explicitly pointing at 'mipmap/ic_launcher' instead of
    // omitting this field removes any dependency on assuming what
    // audio_service's internal default resolves to — this is the app's
    // actual launcher icon, proven to render correctly since it's what's
    // on the device's home screen right now.
    quranAudioHandler = await _bootstrapStep(
      'audio_service',
      () => AudioService.init(
        builder: () => QuranAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.zad.alsaereen.audio',
          androidNotificationChannelName: 'زاد السائرين — تشغيل القرآن',
          androidNotificationIcon: 'mipmap/ic_launcher',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      ),
      fallback: QuranAudioHandler(),
    );

    runApp(const ProviderScope(child: ZadAlsaereenApp()));
  }, (error, stack) {
    debugPrint('[UNCAUGHT] $error\n$stack');
  });
}

class ZadAlsaereenApp extends StatefulWidget {
  const ZadAlsaereenApp({super.key});

  @override
  State<ZadAlsaereenApp> createState() => _ZadAlsaereenAppState();
}

class _ZadAlsaereenAppState extends State<ZadAlsaereenApp> {
  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    // Most screens read AppColors as plain static getters rather than
    // through `Theme.of(context)`, so they don't automatically know to
    // rebuild just because the theme changed somewhere else. Keying the
    // whole tree on the current mode forces Flutter to fully discard and
    // rebuild everything from here down the moment the theme changes —
    // the one guaranteed-correct way to make a real light/dark switch
    // actually reach every screen, at the cost of a full (but rare,
    // user-initiated) rebuild instead of a silent, partially-stale UI.
    return KeyedSubtree(
      key: ValueKey(ThemeController.instance.theme),
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: appRouter,

        // ── RTL + Arabic Localization ─────────────────────────────────────────
        locale: const Locale('ar'),
        supportedLocales: const [
          Locale('ar'),
          Locale('en'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        // ── Global Builder for RTL enforcement ────────────────────────────────
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
