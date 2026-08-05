import '../core/utils/blacklist_filter.dart';
import '../features/home/domain/entities/video_entity.dart';
import '../features/home/data/models/video_model.dart';
import 'supabase_service.dart';
import 'firebase_rtdb_service.dart';

/// Sits in front of every live source (YouTube, Piped, Invidious): checks
/// the free, fast, quota-free intermediate caches first — Supabase, then
/// Firebase Realtime Database — so a repeated search for the same term
/// never needs to spend YouTube quota or hit a public Piped/Invidious
/// instance at all.
class MediaCacheService {
  MediaCacheService._();
  static final MediaCacheService instance = MediaCacheService._();

  Future<List<VideoModel>?> getCached(String query) async {
    final key = query.trim().toLowerCase();
    if (key.isEmpty) return null;

    // Both are independent, quota-free lookups with their own short
    // timeouts (4s / 6s) — running them one after another meant every
    // cache-miss search paid the sum of both (~10s) before even starting
    // the live YouTube/Piped/Invidious fallback. Running them together
    // caps that dead time at whichever one is slower instead.
    final results = await Future.wait([
      SupabaseService.instance.getCachedResults(key),
      FirebaseRtdbService.instance.get('media_cache', key),
    ]);

    final fromSupabase = results[0] as List<VideoModel>?;
    if (fromSupabase != null && fromSupabase.isNotEmpty) {
      return _revalidate(fromSupabase);
    }

    final fromFirebase = results[1] as Map<String, dynamic>?;
    if (fromFirebase != null) {
      final resultsRaw = fromFirebase['results'];
      final cachedAtRaw = fromFirebase['cached_at']?.toString();
      final cachedAt = cachedAtRaw != null ? DateTime.tryParse(cachedAtRaw) : null;
      final isFresh = cachedAt != null &&
          DateTime.now().difference(cachedAt).inDays < 7;
      if (isFresh && resultsRaw is List) {
        try {
          final parsed = resultsRaw
              .map((r) => VideoModel.fromCacheJson(r as Map<String, dynamic>))
              .toList();
          return _revalidate(parsed);
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  /// Re-checks every cached result against the *current* safety filter
  /// before returning it — a cheap, defense-in-depth safety net in case
  /// anything was ever cached before a filter existed or before a gap in
  /// one of the source-specific filters (like Archive.org's, which was
  /// missing entirely at one point) was fixed.
  List<VideoModel> _revalidate(List<VideoModel> results) {
    return results
        .where((v) => BlacklistFilter.isContentAllowed(v.title, v.description))
        .toList();
  }

  /// Fire-and-forget: warms both caches after a live search succeeds so
  /// the *next* person searching the same term gets an instant, free hit.
  void cacheInBackground(String query, List<VideoEntity> results) {
    final asModels = results.whereType<VideoModel>().toList();
    if (asModels.isEmpty) return;
    final key = query.trim().toLowerCase();

    SupabaseService.instance.cacheResults(key, asModels);
    FirebaseRtdbService.instance.put('media_cache', key, {
      'results': asModels.map((r) => r.toCacheJson()).toList(),
      'cached_at': DateTime.now().toIso8601String(),
    });
  }
}
