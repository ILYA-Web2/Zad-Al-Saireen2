import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../features/home/data/models/video_model.dart';
import '../features/downloads/data/models/download_model.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ─── Initialization ───────────────────────────────────────────────────────
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      // `anonKey` still works but is now the deprecated parameter name as
      // of Supabase's 2025/2026 API-key redesign — the value itself
      // (`sb_publishable_...`) was already in the new format, only the
      // parameter name was stale.
      publishableKey: AppConstants.supabaseAnonKey,
    );
  }

  // ─── Favorites ────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getFavorites() async {
    try {
      final response = await _client
          .from(AppConstants.tableFavorites)
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw SupabaseServiceException('Failed to fetch favorites: $e');
    }
  }

  Future<void> addFavorite(VideoModel video) async {
    try {
      await _client.from(AppConstants.tableFavorites).upsert(
        {
          'video_id': video.id,
          'video_title': video.title,
          'video_thumbnail': video.thumbnailUrl,
          'channel_name': video.channelTitle,
          'description': video.description,
          'created_at': DateTime.now().toIso8601String(),
        },
        // Without this, upsert() defaults to conflicting on the table's
        // primary key (`id`), which is never sent here — so re-saving an
        // already-favorited video_id hit the table's separate `unique`
        // constraint on video_id instead and threw a silently-swallowed
        // "duplicate key value" error on every single re-save.
        onConflict: 'video_id',
      );
    } catch (e) {
      throw SupabaseServiceException('Failed to add favorite: $e');
    }
  }

  Future<void> removeFavorite(String videoId) async {
    try {
      await _client
          .from(AppConstants.tableFavorites)
          .delete()
          .eq('video_id', videoId);
    } catch (e) {
      throw SupabaseServiceException('Failed to remove favorite: $e');
    }
  }

  Future<bool> isFavorite(String videoId) async {
    try {
      final response = await _client
          .from(AppConstants.tableFavorites)
          .select('video_id')
          .eq('video_id', videoId)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  // ─── Downloads Tracking ───────────────────────────────────────────────────
  Future<List<DownloadModel>> getDownloads() async {
    try {
      final response = await _client
          .from(AppConstants.tableDownloads)
          .select()
          .order('created_at', ascending: false);
      return (response as List)
          .map((e) => DownloadModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw SupabaseServiceException('Failed to fetch downloads: $e');
    }
  }

  Future<void> saveDownload(DownloadModel download) async {
    try {
      // Same fix as addFavorite() above: onConflict must target video_id
      // (the column with the actual unique constraint), not the default
      // primary key, or every re-save of an existing video_id throws a
      // duplicate-key error that was previously swallowed silently.
      await _client
          .from(AppConstants.tableDownloads)
          .upsert(download.toMap(), onConflict: 'video_id');
    } catch (e) {
      throw SupabaseServiceException('Failed to save download: $e');
    }
  }

  Future<void> removeDownload(String videoId) async {
    try {
      await _client
          .from(AppConstants.tableDownloads)
          .delete()
          .eq('video_id', videoId);
    } catch (e) {
      throw SupabaseServiceException('Failed to remove download: $e');
    }
  }

  // ─── User Settings ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final response = await _client
          .from(AppConstants.tableSettings)
          .select()
          .maybeSingle();
      return (response as Map<String, dynamic>?) ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      await _client.from(AppConstants.tableSettings).upsert({
        ...settings,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw SupabaseServiceException('Failed to save settings: $e');
    }
  }

  // ─── Media Search Cache (primary — fast, free, no quota) ──────────────────
  /// Returns cached results for [query] if present and not older than
  /// [AppConstants.mediaCacheTtl], else null (cache miss — caller should
  /// fall through to a live source).
  Future<List<VideoModel>?> getCachedResults(String query) async {
    try {
      final response = await _client
          .from(AppConstants.tableMediaCache)
          .select()
          .eq('query', query.trim().toLowerCase())
          .maybeSingle()
          .timeout(const Duration(seconds: 4));
      if (response == null) return null;

      final cachedAt = DateTime.tryParse(response['cached_at']?.toString() ?? '');
      if (cachedAt == null ||
          DateTime.now().difference(cachedAt) > AppConstants.mediaCacheTtl) {
        return null; // stale — treat as a miss so it gets refreshed
      }

      final results = response['results'] as List<dynamic>? ?? [];
      return results
          .map((r) => VideoModel.fromCacheJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null; // cache being unavailable must never block a real search
    }
  }

  /// Best-effort — a failed cache write must never surface to the caller,
  /// since the live search results are already in hand either way.
  Future<void> cacheResults(String query, List<VideoModel> results) async {
    try {
      await _client.from(AppConstants.tableMediaCache).upsert({
        'query': query.trim().toLowerCase(),
        'results': results.map((r) => r.toCacheJson()).toList(),
        'cached_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Best-effort only.
    }
  }

  // ─── Search History (best-effort cloud mirror only) ───────────────────────
  /// [HiveService.getRecentSearchQueries] is what the app actually reads —
  /// this is purely an optional, silently-failing mirror (e.g. for future
  /// admin-side analytics), scoped per [deviceId] so one installation's
  /// searches are never mixed with another's the way the earlier
  /// unscoped version was. Upserts on the (device_id, query) pair so
  /// re-searching the same term updates its timestamp instead of piling
  /// up duplicate rows.
  Future<void> saveSearchQuery(String deviceId, String query) async {
    try {
      await _client.from(AppConstants.tableSearchHistory).upsert(
        {
          'device_id': deviceId,
          'query': query.trim(),
          'searched_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'device_id,query',
      );
    } catch (_) {
      // Non-critical — Hive already has the authoritative copy.
    }
  }

  Future<List<String>> getRecentSearches(String deviceId) async {
    try {
      final response = await _client
          .from(AppConstants.tableSearchHistory)
          .select('query')
          .eq('device_id', deviceId)
          .order('searched_at', ascending: false)
          .limit(20)
          .timeout(const Duration(seconds: 4));
      return (response as List)
          .map((e) => e['query']?.toString() ?? '')
          .where((q) => q.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class SupabaseServiceException implements Exception {
  SupabaseServiceException(this.message);
  final String message;
  @override
  String toString() => 'SupabaseServiceException: $message';
}
