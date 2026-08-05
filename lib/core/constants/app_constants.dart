// ignore_for_file: constant_identifier_names
class AppConstants {
  AppConstants._();

  // ─── App Identity ──────────────────────────────────────────────────────────
  static const String appName = 'زاد السائرين';
  static const String appSubName = 'سفينة النجاة';
  static const String developerName = 'جلال (إيليا)';
  static const String appVersion = '1.7.0';

  // ─── YouTube Data API v3 ───────────────────────────────────────────────────
  // ⚠️ SECURITY AUDIT (25 Jul 2026): these 4 keys are compiled straight into
  // the app and are therefore extractable from any published APK in minutes
  // — treat them as already compromised. They must be revoked/regenerated
  // in Google Cloud Console, with the *new* keys added only through the
  // youtube_api_keys Supabase table (see supabase_migration_youtube_api_keys.sql),
  // never back into this source file. This array is kept only as the
  // documented last-resort offline fallback for a device that has never
  // once synced with that table — see YoutubeKeyRotationManager.
  //
  // Multiple keys from separate projects so each has its own daily quota —
  // YoutubeKeyRotationManager cycles through them automatically whenever one
  // returns "quota exceeded" (403), instead of the whole search feature
  // going dark until the next day after just ~100 searches on a single key.
  static const List<String> youtubeApiKeys = [
    'AIzaSyC5GMw9EJmVTC8cEI9WoeeTSGJ2lkNArB0',
    'AIzaSyCDvGEFpnpLkj-lOXf_P5C33rEsp294G-0',
    'AIzaSyAenPo3qveXlSXYkImKuAl-TXdekTWVuFc',
    'AIzaSyDSlmc7giRWhADYH0diztszj7hJxWjXPgg',
  ];
  static const String youtubeBaseUrl = 'https://www.googleapis.com/youtube/v3';
  static const int youtubeMaxResults = 20;

  // ─── Supabase ──────────────────────────────────────────────────────────────
  // The publishable key itself is *meant* to be public (it's the modern
  // equivalent of the old anon key) — it's fine for it to live in client
  // code. What matters is that Row Level Security policies on every table
  // it can reach are correctly scoped (see supabase_migration_urgent_rls_fix.sql
  // and the full Batch-1 security audit for what was wrong and what's fixed).
  static const String supabaseUrl = 'https://rernamtqmbfzdhzgjyps.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_yBTOew3QiE7XBroob1wfYg_85qfMaVU';

  // ─── Telegram (audio engine cloud storage) ─────────────────────────────────
  // Read from --dart-define at build time (see .github/workflows/build_apk.yml)
  // rather than written here as a literal — keeps the token itself out of
  // the source diff/history. Worth being fully honest about what this
  // does and doesn't fix, the same way the earlier security audit was
  // about the YouTube keys: a --dart-define value still ends up compiled
  // directly into the release binary as a plain string, so it is *not*
  // meaningfully harder to extract from a decompiled APK than a literal
  // in this file would be — real protection would mean routing Telegram
  // uploads through a server-side Edge Function that holds the token
  // instead of the client ever seeing it, the same pattern already used
  // for admin writes (see docs on the Edge Function approach). This is a
  // real improvement for keeping the repository's source clean, not a
  // claim that the token becomes unextractable from the app itself.
  static const String telegramBotToken =
      String.fromEnvironment('TELEGRAM_BOT_TOKEN', defaultValue: '');
  static const String telegramChatId =
      String.fromEnvironment('TELEGRAM_CHAT_ID', defaultValue: '');

  // ─── Supabase Table Names ──────────────────────────────────────────────────
  static const String tableFavorites = 'favorites';
  static const String tableDownloads = 'downloads';
  static const String tableSettings = 'user_settings';
  static const String tableMediaCache = 'media_cache';
  static const String tableSearchHistory = 'search_history';

  // ─── Firebase Realtime Database (secondary free cache, REST-only — no
  // native SDK, so this can never affect the Android build) ─────────────────
  static const String firebaseDatabaseUrl =
      'https://zad-alsairin-default-rtdb.firebaseio.com';

  // ─── Piped / Invidious (free, open-source YouTube front-ends used as a
  // last-resort fallback once every YouTube API key is exhausted) ───────────
  static const String pipedInstancesUrl = 'https://piped-instances.kavin.rocks/';
  static const String invidiousInstancesUrl =
      'https://api.invidious.io/instances.json?sort_by=type';

  /// How long a cached search result stays valid before it's treated as
  /// stale and re-fetched from a live source.
  static const Duration mediaCacheTtl = Duration(days: 7);

  // ─── Hive Box Names ────────────────────────────────────────────────────────
  static const String hiveBoxDownloads = 'downloads_box';
  static const String hiveBoxSettings = 'settings_box';
  static const String hiveBoxTasbih = 'tasbih_box';
  static const String hiveBoxQuran = 'quran_cache_box';
  static const String hiveBoxHistory = 'listen_history_box';
  static const String hiveBoxSearchHistory = 'search_history_box';
  static const int historyMaxEntries = 200;
  static const int searchHistoryMaxEntries = 30;

  // ─── SharedPreferences Keys ────────────────────────────────────────────────
  static const String prefIsFirstLaunch = 'is_first_launch';
  static const String prefThemeMode = 'theme_mode'; // 'system' | 'light' | 'dark'
  static const String prefFontSize = 'font_size';
  static const String prefLineHeight = 'line_height';
  static const String prefTasbihCount = 'tasbih_general_count';
  static const String prefDeviceId = 'device_id';
  static const String prefAdminUnlocked = 'admin_panel_unlocked';

  // ─── Hidden Admin Panel ────────────────────────────────────────────────────
  /// Typed into the Quran screen's own search field (not a real search
  /// query) to permanently reveal the admin section for this
  /// installation only. Intentionally long/random so it can't be
  /// triggered by accident.
  ///
  /// ⚠️ SECURITY AUDIT (25 Jul 2026): this string is compiled into the app
  /// and extractable from any APK regardless of length — it is UI-reveal
  /// only, not real access control. Real write protection now depends on
  /// supabase_migration_urgent_rls_fix.sql + the Edge Function in
  /// docs/admin-actions-edge-function.md, not on this code staying secret.
  /// Do not treat unlocking the panel as equivalent to being authorized to
  /// write to the database — those are now two separate things by design.
  static const String adminUnlockCode = 'AAFR58SzUZCX8VhZb548WSvuAmR1ZEodzUn349zZyM';
  static const String tableRemoteConfig = 'app_remote_config';
  static const String tableAdminNotifications = 'admin_notifications';
  static const String tableYoutubeApiKeys = 'youtube_api_keys';
  static const String tableUsers = 'app_users';
  static const String hiveBoxAdminNotifications = 'admin_notifications_box';

  // ─── External APIs ─────────────────────────────────────────────────────────
  static const String quranApiBaseUrl = 'https://api.alquran.cloud/v1';

  // ─── Splash Timings (ms) ──────────────────────────────────────────────────
  static const int splashDurationFirstLaunch = 4500;
  static const int splashDurationReturn = 300;
  static const int splashAnimationDuration = 500;
  static const int headerDeveloperTextDuration = 2500;

  // ─── UI Measurements ──────────────────────────────────────────────────────
  static const double borderRadius = 6.0;
  static const double borderWidth = 1.2;
  static const double blurSigma = 10.0;
  static const double headerHeight = 76.0;
  static const double bottomNavHeight = 72.0;
  static const double tasbihCircleSize = 200.0;
  static const double cardHeight = 180.0;

  // ─── Hussaini Search Keywords ─────────────────────────────────────────────
  static const List<String> hussainiKeywords = [
    'لطميات حسينية',
    'قصائد حسينية',
    'أدعية حسينية',
    'رادود حسيني',
    'نشيد حسيني',
    'عزاء حسيني',
    'مراثي حسينية',
    'أهل البيت',
    'محرم الحرام',
    'عاشوراء كربلاء',
    'زيارة الحسين',
    'كربلاء المقدسة',
    'الإمام الحسين',
    'ليلة عاشوراء',
    'موكب العزاء',
    'مجلس عزاء حسيني',
    'نعي حسيني',
    'باسم الكربلائي',
    'أحمد الساعدي',
    'الحاج عمار الكناني',
  ];

  // ─── Famous Radods (50+) ──────────────────────────────────────────────────
  static const List<String> famousRadods = [
    'باسم الكربلائي', 'أحمد الساعدي', 'الحاج عمار الكناني',
    'ميثم التمار', 'علي الدلفي', 'جعفر الدوسر',
    'حيدر الكعبي', 'علي الربيعي', 'أحمد الحميري',
    'محمد الجنامي', 'الحاج صادق العبادي', 'علي المزاحم',
    'عباس الكعبي', 'جابر الكاظمي', 'محمد أبو رقية',
    'حسين الأكرف', 'مصطفى الربيعي', 'يحيى العبودي',
    'عامر الكناني', 'هاشم الهلالي', 'حسن الوهيبي',
    'علي فارس', 'صادق الكربلائي', 'مصطفى العبادي',
    'أحمد الربيعي', 'عبد الله الخضراوي', 'علي الحسناوي',
    'كريم سلمان', 'أحمد الصالح', 'حيدر الزبيدي',
    'محمد الميالي', 'أحمد السماوي', 'علي الشجيري',
    'حيدر العبادي', 'مصطفى السيد', 'محمد الموسوي',
    'أحمد البغدادي', 'علي الطرفي', 'حسين الربيعي',
    'محمد الزاملي', 'أحمد اللواتي', 'حسن العبادي',
    'علي الحلاق', 'محمد الشبيبي', 'حيدر المسعودي',
    'أحمد العباسي', 'علي الهاشمي', 'محمد الكناني',
    'حيدر الرئيسي', 'أحمد اليعقوبي', 'محمد صالح العبادي',
  ];

  // ─── Quran Reciters (with everyayah.com identifiers) ──────────────────────
  static const List<Map<String, String>> quranReciters = [
    {'name': 'مشاري راشد العفاسي', 'code': 'Alafasy_128kbps', 'edition': 'ar.alafasy'},
    {'name': 'عبدالرحمن السديس', 'code': 'Abdul_Basit_Murattal_192kbps', 'edition': 'ar.abdurrahmaansudais'},
    {'name': 'محمود خليل الحصري', 'code': 'Husary_128kbps', 'edition': 'ar.husary'},
    {'name': 'محمد صديق المنشاوي', 'code': 'Minshawi_Murattal_128kbps', 'edition': 'ar.minshawi'},
    {'name': 'أبو بكر الشاطري', 'code': 'Abu_Bakr_Ash-Shaatree_128kbps', 'edition': 'ar.shaatree'},
    {'name': 'ماهر المعيقلي', 'code': 'Maher_AlMuaiqly_128kbps', 'edition': 'ar.mahermuaiqly'},
    {'name': 'هاني الرفاعي', 'code': 'Hani_Rifai_192kbps', 'edition': 'ar.hani'},
    {'name': 'سعد الغامدي', 'code': 'Saad_Al-Ghamdi_128kbps', 'edition': 'ar.saoodashgali'},
    {'name': 'عبد الباسط عبد الصمد', 'code': 'Abdul_Basit_Murattal_192kbps', 'edition': 'ar.abdulbasit'},
    {'name': 'عبدالله الجهني', 'code': 'Abdullah_Basfar_192kbps', 'edition': 'ar.aymanswoaid'},
  ];

  // ─── Content Blacklist Keywords ────────────────────────────────────────────
  /// Layer 2 of the search safety firewall: a result must contain at least
  /// one of these in its title/description/tags to be shown at all. This
  /// is what actually stops "قصيدة فاقد +18"-style abuse and generic
  /// non-religious content (English lessons, unrelated clips, etc.)
  /// without needing an ever-growing list of banned words.
  static const List<String> religiousTokens = [
    'رادود', 'قصيدة', 'قصائد', 'لطمية', 'لطميات', 'عزاء', 'مجلس',
    'الشيخ', 'السيد', 'محاضرة', 'ملا', 'الملا', 'الكربلائي', 'نعي',
    'أدعية', 'دعاء', 'زيارة', 'صلوات', 'صلاة', 'حسين', 'حسيني',
    'عباس', 'زينب', 'كربلاء', 'عاشوراء', 'محرم', 'أهل البيت',
    'آل البيت', 'مرثية', 'مقتل', 'فاطمة', 'علي', 'مهدي', 'إمام',
    'أئمة', 'شيعة', 'كميل', 'قرآن', 'إسلامي', 'أنشودة', 'نشيد',
    'شور', 'باسم',
  ];

  static const List<String> contentBlacklist = [
    'سياسي', 'انتخابات', 'كوميدي', 'تمثيل', 'مسلسل',
    'فيلم', 'خرافة', 'بدعة', 'ناصبي', 'وهابي',
    'تكفيري', 'داعش', 'ترفيه', 'رقص', 'اغنية',
    'كليب', 'موسيقى', 'ملاهي', 'قمار', 'خمر',
  ];

  /// Layer 3: an immediate, unambiguous block — generic spam/adult markers
  /// only (deliberately not an exhaustive explicit-content vocabulary list;
  /// Layer 2's positive religious-token requirement above is what actually
  /// keeps explicit content out, since such titles essentially never
  /// contain religious terms in the first place).
  static const List<String> explicitBlockTerms = [
    'xxx', 'porn', '+18', '١٨+', '18+',
  ];
}
