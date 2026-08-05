import 'dart:convert';
import '../core/constants/app_constants.dart';
import 'admin_service.dart';
import 'hive_service.dart';

/// Rotates through a **database-backed** pool of YouTube API keys — the
/// admin panel's "add/remove key" actions write straight to Supabase, and
/// every installation (not just the admin's own device) picks up the
/// change the next time it syncs, with no new app build ever required.
///
/// The four keys once hardcoded into [AppConstants.youtubeApiKeys] are
/// now only a **last-resort offline fallback**: used solely on the rare
/// chance this exact device has never once successfully synced with the
/// database (e.g. first launch with no internet at all yet). The moment
/// a sync succeeds, the synced list — cached locally — takes over
/// completely, including reflecting a removal of one of those original
/// four keys if the admin ever removes it from the database.
///
/// When a key returns "quota exceeded" (HTTP 403), it's put on a 25-hour
/// cooldown — one hour of buffer past the actual ~24h quota reset — and the
/// next key takes over immediately, with no user-visible interruption.
/// Cooldowns are persisted so a fresh app launch doesn't immediately retry
/// a key that's still exhausted.
class YoutubeKeyRotationManager {
  YoutubeKeyRotationManager._();
  static final YoutubeKeyRotationManager instance = YoutubeKeyRotationManager._();

  static const String _storageKey = 'youtube_key_cooldowns';
  static const Duration _cooldown = Duration(hours: 25);

  /// key -> ISO8601 timestamp of when it becomes usable again.
  Map<String, String> _cooldowns = {};
  bool _loaded = false;
  bool _hasSyncedOnce = false;

  void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = HiveService.instance.getSetting(_storageKey);
      if (raw is String && raw.isNotEmpty) {
        _cooldowns = Map<String, String>.from(json.decode(raw) as Map);
      }
    } catch (_) {
      _cooldowns = {};
    }
    // A non-empty local cache means some previous launch of this
    // installation already synced successfully at least once.
    _hasSyncedOnce = HiveService.instance.getCachedRemoteApiKeys().isNotEmpty;
  }

  void _persist() {
    try {
      HiveService.instance.setSetting(_storageKey, json.encode(_cooldowns));
    } catch (_) {
      // Best-effort — worst case we re-try a still-cooling-down key once
      // after a restart, which just costs one extra 403 before rotating.
    }
  }

  bool _isOnCooldown(String key) {
    final until = _cooldowns[key];
    if (until == null) return false;
    final untilTime = DateTime.tryParse(until);
    if (untilTime == null) return false;
    if (DateTime.now().isAfter(untilTime)) {
      _cooldowns.remove(key);
      return false;
    }
    return true;
  }

  /// Pulls the current key pool from the database and overwrites the
  /// local cache wholesale. Call this on app startup and right after the
  /// admin panel adds/removes a key so this device reflects it instantly
  /// instead of waiting for the next cold start. Silently does nothing on
  /// failure (offline, DNS issue, etc.) — the app keeps working fine on
  /// whatever was last cached.
  Future<void> refreshFromRemote() async {
    try {
      final keys = await AdminService.instance.getApiKeys();
      if (keys.isNotEmpty) {
        await HiveService.instance.setCachedRemoteApiKeys(keys);
        _hasSyncedOnce = true;
      }
    } catch (_) {
      // Offline / unreachable — keep using whatever was cached before.
    }
  }

  /// Returns the keys currently usable, in order, starting after whichever
  /// key was last reported exhausted (simple round-robin) — never returns
  /// an empty list unless every key is on cooldown.
  List<String> availableKeysInOrder() {
    _ensureLoaded();
    final keys = allKeys();
    return keys.where((k) => !_isOnCooldown(k)).toList();
  }

  /// The database-synced pool once at least one sync has ever succeeded
  /// on this device; otherwise the four keys compiled into the app, used
  /// only until the first successful sync ever happens.
  List<String> allKeys() {
    _ensureLoaded();
    if (_hasSyncedOnce) {
      final cached = HiveService.instance.getCachedRemoteApiKeys();
      if (cached.isNotEmpty) return cached;
    }
    return AppConstants.youtubeApiKeys;
  }

  /// Cooldown expiry (or null if usable right now) for [key] — used by
  /// the admin panel to show "متاح الآن" vs "متوقف حتى ...".
  DateTime? cooldownUntil(String key) {
    _ensureLoaded();
    final until = _cooldowns[key];
    if (until == null) return null;
    final untilTime = DateTime.tryParse(until);
    if (untilTime == null) return null;
    if (DateTime.now().isAfter(untilTime)) return null;
    return untilTime;
  }

  bool get hasAvailableKey => availableKeysInOrder().isNotEmpty;

  /// Marks [key] as exhausted for the next ~25 hours.
  void reportQuotaExceeded(String key) {
    _ensureLoaded();
    _cooldowns[key] = DateTime.now().add(_cooldown).toIso8601String();
    _persist();
  }
}
