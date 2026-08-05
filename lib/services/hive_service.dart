import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants/app_constants.dart';

class HiveService {
  HiveService._();

  static HiveService? _instance;
  static HiveService get instance => _instance ??= HiveService._();

  late Box _downloadsBox;
  late Box _settingsBox;
  late Box _tasbihBox;
  late Box _quranCacheBox;
  late Box _historyBox;
  late Box _searchHistoryBox;
  late Box _adminNotificationsBox;

  Future<void> initialize() async {
    await Hive.initFlutter();
    _downloadsBox = await _openBoxSafely(AppConstants.hiveBoxDownloads);
    _settingsBox = await _openBoxSafely(AppConstants.hiveBoxSettings);
    _tasbihBox = await _openBoxSafely(AppConstants.hiveBoxTasbih);
    _quranCacheBox = await _openBoxSafely(AppConstants.hiveBoxQuran);
    _historyBox = await _openBoxSafely(AppConstants.hiveBoxHistory);
    _searchHistoryBox = await _openBoxSafely(AppConstants.hiveBoxSearchHistory);
    _adminNotificationsBox = await _openBoxSafely(AppConstants.hiveBoxAdminNotifications);
  }

  /// Opens [name], and if it fails (e.g. corrupted data left over from a
  /// previous version) deletes and recreates it once instead of leaving the
  /// box — and every feature that reads it — permanently unusable. A single
  /// damaged box can no longer take the rest of local storage down with it.
  Future<Box> _openBoxSafely(String name) async {
    try {
      return await Hive.openBox(name);
    } catch (e) {
      try {
        await Hive.deleteBoxFromDisk(name);
        return await Hive.openBox(name);
      } catch (e2) {
        // Last resort: open under a fresh recovery name so callers still
        // get a working Box instance instead of every read/write throwing
        // for the rest of the app's lifetime (old data under [name] is
        // simply not recoverable at that point).
        return Hive.openBox('${name}_recovered');
      }
    }
  }

  // ─── Downloads ────────────────────────────────────────────────────────────
  // NOTE: [key] must be unique per category+videoId (e.g. "favorite_abc123"
  // vs "audio_abc123"), not the bare videoId — otherwise favoriting a video
  // that's also been downloaded (or vice versa) silently overwrites the
  // other entry, since they'd collide on the same key.
  Future<void> saveDownload(String key, Map<String, dynamic> data) async {
    await _downloadsBox.put(key, data);
  }

  Future<void> removeDownload(String key) async {
    await _downloadsBox.delete(key);
  }

  bool hasDownload(String key) => _downloadsBox.containsKey(key);

  List<Map<String, dynamic>> getAllDownloads() {
    return _downloadsBox.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
        .reversed
        .toList();
  }

  // ─── Settings ─────────────────────────────────────────────────────────────
  T? getSetting<T>(String key) {
    return _settingsBox.get(key) as T?;
  }

  Future<void> setSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  bool isFirstLaunch() {
    return _settingsBox.get(AppConstants.prefIsFirstLaunch, defaultValue: true)
        as bool;
  }

  Future<void> markLaunched() async {
    await _settingsBox.put(AppConstants.prefIsFirstLaunch, false);
  }

  double getFontSize() {
    return (_settingsBox.get(AppConstants.prefFontSize, defaultValue: 22.0)
        as num)
        .toDouble();
  }

  Future<void> setFontSize(double size) async {
    await _settingsBox.put(AppConstants.prefFontSize, size);
  }

  double getLineHeight() {
    return (_settingsBox.get(AppConstants.prefLineHeight, defaultValue: 1.8)
        as num)
        .toDouble();
  }

  Future<void> setLineHeight(double height) async {
    await _settingsBox.put(AppConstants.prefLineHeight, height);
  }

  ThemeMode getThemeMode() {
    final raw = _settingsBox.get(AppConstants.prefThemeMode) as String?;
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system; // default: follow the device's own theme
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _settingsBox.put(AppConstants.prefThemeMode, value);
  }

  // ─── AppTheme (4-theme system) ──────────────────────────────────────────────
  // Supersedes the old light/dark/system model above, which only ever
  // supported a single conditional branch per color — see
  // app_theme_definition.dart for why that had to change. The very first
  // time this runs (no 'app_theme' key saved yet), it migrates the old
  // setting once: previous 'dark'/'system-currently-dark' users land on
  // ليل (unchanged from before), previous 'light' users land on فجر.
  String getAppThemeName() {
    final saved = _settingsBox.get('app_theme') as String?;
    if (saved != null) return saved;
    final oldMode = getThemeMode();
    return oldMode == ThemeMode.light ? 'fajr' : 'layl';
  }

  Future<void> setAppThemeName(String themeName) async {
    await _settingsBox.put('app_theme', themeName);
  }

  /// A random identifier generated once and persisted locally forever —
  /// this app has no login/accounts, so this is what "per-user" actually
  /// means here: one identity per installation. Used only to scope search
  /// history so one person's searches never mix with anyone else's, both
  /// locally and in the optional Supabase mirror.
  String getOrCreateDeviceId() {
    final existing = _settingsBox.get(AppConstants.prefDeviceId) as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    final seed = '${DateTime.now().microsecondsSinceEpoch}-'
        '${Random.secure().nextInt(1 << 32)}-${identityHashCode(this)}';
    final id = sha256.convert(utf8.encode(seed)).toString().substring(0, 32);
    _settingsBox.put(AppConstants.prefDeviceId, id);
    return id;
  }

  // ─── Search History (the single source of truth the UI reads from) ───────
  /// Local-first by design: this is what actually answers "what did I
  /// search before" in the UI — instantly, offline-safe, and unambiguous.
  /// [SupabaseService]'s copy of the same data is a best-effort mirror
  /// only, never the read path, so there is exactly one place the app
  /// trusts for "my recent searches" instead of two disagreeing sources.
  ///
  /// Keyed by the normalized (trimmed/lowercased) query so searching the
  /// same term twice bumps its timestamp instead of creating a duplicate
  /// entry, then trimmed to [AppConstants.searchHistoryMaxEntries].
  Future<void> addSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final key = trimmed.toLowerCase();

    await _searchHistoryBox.put(key, {
      'query': trimmed,
      'searched_at': DateTime.now().toIso8601String(),
    });

    if (_searchHistoryBox.length > AppConstants.searchHistoryMaxEntries) {
      final entries = _searchHistoryBox.toMap().entries.toList()
        ..sort((a, b) => ((a.value as Map)['searched_at']?.toString() ?? '')
            .compareTo((b.value as Map)['searched_at']?.toString() ?? ''));
      final overflow = entries.length - AppConstants.searchHistoryMaxEntries;
      for (var i = 0; i < overflow; i++) {
        await _searchHistoryBox.delete(entries[i].key);
      }
    }
  }

  List<String> getRecentSearchQueries({int limit = 10}) {
    final entries = _searchHistoryBox.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
      ..sort((a, b) => (b['searched_at']?.toString() ?? '')
          .compareTo(a['searched_at']?.toString() ?? ''));
    return entries
        .map((e) => e['query']?.toString() ?? '')
        .where((q) => q.isNotEmpty)
        .take(limit)
        .toList();
  }

  Future<void> removeSearchQuery(String query) async {
    await _searchHistoryBox.delete(query.trim().toLowerCase());
  }

  Future<void> clearSearchHistory() async => _searchHistoryBox.clear();

  // ─── Hidden Admin Panel ────────────────────────────────────────────────────
  /// Once unlocked (by typing the secret code into the Quran search box)
  /// it stays unlocked forever on this installation — there is no logout,
  /// matching "يفتح فقط... ويضهر لة بشكل دائم" from the spec.
  bool isAdminUnlocked() =>
      (_settingsBox.get(AppConstants.prefAdminUnlocked) as bool?) ?? false;

  Future<void> unlockAdminPanel() async {
    await _settingsBox.put(AppConstants.prefAdminUnlocked, true);
  }

  /// A local cache of the last successful sync from the [AdminService]
  /// database-backed key pool — used only so a device with no internet
  /// at this exact moment can still rotate through whatever it last saw.
  /// The database is authoritative; this is never written to directly by
  /// "add"/"remove" actions anymore (unlike the old per-device-only
  /// design), only ever overwritten wholesale by a successful sync.
  List<String> getCachedRemoteApiKeys() {
    final raw = _settingsBox.get('cached_remote_youtube_api_keys');
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }

  Future<void> setCachedRemoteApiKeys(List<String> keys) async {
    await _settingsBox.put('cached_remote_youtube_api_keys', keys);
  }

  /// Admin-broadcast notifications this installation has already
  /// dismissed — so a closed notification never reappears, matching the
  /// "once closed, never shown again" behavior described for the
  /// game-style popup.
  Set<String> getDismissedNotificationIds() =>
      _adminNotificationsBox.keys.map((k) => k.toString()).toSet();

  Future<void> markNotificationDismissed(String id) async {
    await _adminNotificationsBox.put(id, DateTime.now().toIso8601String());
  }

  // ─── Tasbih ───────────────────────────────────────────────────────────────
  int getTasbihCount() {
    return (_tasbihBox.get('general_count', defaultValue: 0) as int);
  }

  Future<void> saveTasbihCount(int count) async {
    await _tasbihBox.put('general_count', count);
  }

  // Fatima's Tasbih cycle count used to live only in the provider's
  // in-memory state — closing the app (or navigating away long enough
  // for the .autoDispose-free but still process-lifetime provider to be
  // recreated) silently reset it back to 0, discarding real history with
  // no way to ever see it again.
  int getFatimaTotalCompleted() {
    return (_tasbihBox.get('fatima_total_completed', defaultValue: 0) as int);
  }

  Future<void> saveFatimaTotalCompleted(int count) async {
    await _tasbihBox.put('fatima_total_completed', count);
  }

  /// Logs [count] tasbih beads counted "just now" against today's date,
  /// for the daily/weekly/monthly stats view. Kept as a simple
  /// date-string-keyed int map — small, and older entries are pruned
  /// automatically (see [_pruneOldTasbihLog]) so this box can't grow
  /// unbounded over months/years of daily use.
  Future<void> logTasbihActivity(int count) async {
    if (count <= 0) return;
    final key = _tasbihLogKeyFor(DateTime.now());
    final current = (_tasbihBox.get(key, defaultValue: 0) as int);
    await _tasbihBox.put(key, current + count);
    unawaited(_pruneOldTasbihLog());
  }

  String _tasbihLogKeyFor(DateTime date) =>
      'log_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Returns the count logged for each of the last [days] days, oldest
  /// first, today last — always [days] entries long (0 for days with no
  /// activity) so a chart can size itself without special-casing gaps.
  List<int> getTasbihActivityForLastDays(int days) {
    final now = DateTime.now();
    return List.generate(days, (i) {
      final date = now.subtract(Duration(days: days - 1 - i));
      return (_tasbihBox.get(_tasbihLogKeyFor(date), defaultValue: 0) as int);
    });
  }

  Future<void> _pruneOldTasbihLog() async {
    const keepDays = 90; // enough for a monthly view with headroom
    final cutoff = DateTime.now().subtract(const Duration(days: keepDays));
    for (final key in _tasbihBox.keys.toList()) {
      if (key is! String || !key.startsWith('log_')) continue;
      final dateStr = key.substring(4);
      final date = DateTime.tryParse(dateStr);
      if (date != null && date.isBefore(cutoff)) {
        await _tasbihBox.delete(key);
      }
    }
  }

  // ─── Local content favorites (Hadith, etc.) ────────────────────────────────
  // A lightweight local-only favorites list (distinct from the Supabase-
  // backed video favorites) for static, on-device content like Hadith —
  // no network needed since the content itself never changes.
  Set<int> getFavoriteHadithIds() {
    final stored = getSetting<List<dynamic>>('favorite_hadith_ids') ?? [];
    return stored.map((e) => e as int).toSet();
  }

  Future<void> toggleFavoriteHadith(int hadithId) async {
    final current = getFavoriteHadithIds();
    if (!current.remove(hadithId)) current.add(hadithId);
    await setSetting('favorite_hadith_ids', current.toList());
  }

  // Same idea, for the Infallibles ("المعصومون") biography section — IDs
  // here are strings (e.g. 'prophet', 'imam-ali') rather than ints.
  Set<String> getBookmarkedInfallibleIds() {
    final stored = getSetting<List<dynamic>>('bookmarked_infallible_ids') ?? [];
    return stored.map((e) => e as String).toSet();
  }

  Future<void> toggleBookmarkedInfallible(String id) async {
    final current = getBookmarkedInfallibleIds();
    if (!current.remove(id)) current.add(id);
    await setSetting('bookmarked_infallible_ids', current.toList());
  }

  // Same idea again, for general audio tracks played through
  // AudioPlayerScreen (search results, lamentations, etc.) — kept
  // separate from the Hadith bucket above rather than reusing it via a
  // hashed key, since track IDs are already real strings and mixing two
  // unrelated content types into one bucket via hashCode would only
  // invite confusion later.
  Set<String> getFavoriteTrackIds() {
    final stored = getSetting<List<dynamic>>('favorite_track_ids') ?? [];
    return stored.map((e) => e as String).toSet();
  }

  Future<void> toggleFavoriteTrack(String trackId) async {
    final current = getFavoriteTrackIds();
    if (!current.remove(trackId)) current.add(trackId);
    await setSetting('favorite_track_ids', current.toList());
  }

  // ─── Hijri calendar calibration ─────────────────────────────────────────────
  // See HijriDate.calibrationOffsetDays for the full explanation — this is
  // the persisted value, loaded into that static field once at app start.
  int getHijriCalibrationOffset() {
    return (_settingsBox.get('hijri_calibration_offset_days', defaultValue: 0) as int);
  }

  Future<void> saveHijriCalibrationOffset(int days) async {
    await _settingsBox.put('hijri_calibration_offset_days', days);
  }

  // ─── Quran Cache ──────────────────────────────────────────────────────────
  void cacheSurahData(int surahNumber, Map<String, dynamic> data) {
    _quranCacheBox.put('surah_$surahNumber', data);
  }

  Map<String, dynamic>? getCachedSurah(int surahNumber) {
    final data = _quranCacheBox.get('surah_$surahNumber');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  // ─── Listen / Watch History ────────────────────────────────────────────────
  /// Logs a play event (Quran Surah, video, dua, etc). Entries are keyed by
  /// [entryId] so repeat plays of the same item bump it to the top instead
  /// of duplicating, and the log is capped at
  /// [AppConstants.historyMaxEntries] to keep local storage bounded.
  Future<void> addHistoryEntry(String entryId, Map<String, dynamic> data) async {
    await _historyBox.put(entryId, data);
    if (_historyBox.length > AppConstants.historyMaxEntries) {
      final entries = _historyBox.toMap().entries.toList()
        ..sort((a, b) {
          final aTime = (a.value as Map)['played_at']?.toString() ?? '';
          final bTime = (b.value as Map)['played_at']?.toString() ?? '';
          return aTime.compareTo(bTime);
        });
      final overflow = entries.length - AppConstants.historyMaxEntries;
      for (var i = 0; i < overflow; i++) {
        await _historyBox.delete(entries[i].key);
      }
    }
  }

  List<Map<String, dynamic>> getAllHistory() {
    final entries = _historyBox.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    entries.sort((a, b) => (b['played_at']?.toString() ?? '')
        .compareTo(a['played_at']?.toString() ?? ''));
    return entries;
  }

  Future<void> removeHistoryEntry(String entryId) async =>
      _historyBox.delete(entryId);

  Future<void> clearHistory() async => _historyBox.clear();

  /// Same id convention `_load()` in the player already uses
  /// (`'video_$videoId'`) when it logs a play — reused here so a result
  /// card can show a real "already watched" mark instead of guessing.
  bool hasWatched(String entryId) => _historyBox.containsKey(entryId);

  // ─── Cleanup ──────────────────────────────────────────────────────────────
  Future<void> clearAllDownloads() async => _downloadsBox.clear();
  Future<void> clearCache() async => _quranCacheBox.clear();
}
