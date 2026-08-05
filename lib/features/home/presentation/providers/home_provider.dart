import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/blacklist_filter.dart';
import '../../../../services/youtube_service.dart';
import '../../../../services/archive_service.dart';
import '../../../../services/hive_service.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/connectivity_service.dart';
import '../../../../services/media_cache_service.dart';
import '../../../../services/piped_service.dart';
import '../../../../services/invidious_service.dart';
import '../../../audio_engine/data/services/audius_service.dart';
import '../../../audio_engine/data/services/audio_content_filter.dart';
import '../../../downloads/data/models/download_model.dart';
import '../../data/repositories/youtube_repository_impl.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/repositories/youtube_repository.dart';
import '../../domain/usecases/search_videos_usecase.dart';

// ─── Service Providers ────────────────────────────────────────────────────────
final youtubeServiceProvider = Provider<YoutubeService>((ref) {
  final service = YoutubeService();
  ref.onDispose(service.dispose);
  return service;
});

final archiveServiceProvider = Provider<ArchiveService>((ref) {
  final service = ArchiveService();
  ref.onDispose(service.dispose);
  return service;
});

final youtubeRepositoryProvider = Provider<YoutubeRepository>((ref) {
  return YoutubeRepositoryImpl(ref.read(youtubeServiceProvider));
});

final searchVideosUseCaseProvider = Provider<SearchVideosUseCase>((ref) {
  return SearchVideosUseCase(ref.read(youtubeRepositoryProvider));
});

// ─── Home State ───────────────────────────────────────────────────────────────
class HomeState {
  const HomeState({
    this.videos = const [],
    this.suggestedVideos = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
    this.hasNoResults = false,
    this.alternativeSuggestions = const [],
    this.recentSearches = const [],
    this.archiveResults = const [],
    this.isArchiveLoading = false,
    this.isOffline = false,
  });

  final List<VideoEntity> videos;
  final List<VideoEntity> suggestedVideos;
  final bool isLoading;
  final String? error;
  final String query;
  final bool hasNoResults;
  final List<String> alternativeSuggestions;
  final List<String> recentSearches;
  final List<ArchiveAudioResult> archiveResults;
  final bool isArchiveLoading;
  final bool isOffline;

  HomeState copyWith({
    List<VideoEntity>? videos,
    List<VideoEntity>? suggestedVideos,
    bool? isLoading,
    String? error,
    // `copyWith(error: null)` used to be indistinguishable from "I didn't
    // touch error at all" (Dart can't tell "omitted" from "explicitly
    // null" for a plain optional parameter) — so `error: error` below
    // silently wiped out any real, just-set error message on the very
    // next unrelated state update. The concrete case this broke: the
    // Archive.org search runs concurrently with the main YouTube/Piped/
    // Invidious search, and its `.then()` callback calls
    // `copyWith(archiveResults: ..., isArchiveLoading: false)` — which,
    // without this flag, would erase a real "تعذّر جلب النتائج" error the
    // main search had just set, moments after the user was supposed to
    // see it. Pass `clearError: true` only where the error should
    // actually be cleared.
    bool clearError = false,
    String? query,
    bool? hasNoResults,
    List<String>? alternativeSuggestions,
    List<String>? recentSearches,
    List<ArchiveAudioResult>? archiveResults,
    bool? isArchiveLoading,
    bool? isOffline,
  }) {
    return HomeState(
      videos: videos ?? this.videos,
      suggestedVideos: suggestedVideos ?? this.suggestedVideos,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      query: query ?? this.query,
      hasNoResults: hasNoResults ?? this.hasNoResults,
      alternativeSuggestions: alternativeSuggestions ?? this.alternativeSuggestions,
      recentSearches: recentSearches ?? this.recentSearches,
      archiveResults: archiveResults ?? this.archiveResults,
      isArchiveLoading: isArchiveLoading ?? this.isArchiveLoading,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

// ─── Home Notifier ────────────────────────────────────────────────────────────
class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier(this._useCase, this._archiveService) : super(const HomeState()) {
    _init();
  }

  final SearchVideosUseCase _useCase;
  final ArchiveService _archiveService;

  Future<void> _init() async {
    // Local Hive history is the single source of truth for "my recent
    // searches" — instant, offline-safe, unambiguous. Kick off a
    // best-effort background refresh from the Supabase mirror too, in
    // case this device has history saved from before a reinstall wiped
    // local storage, without ever blocking the UI on network.
    final localRecents = HiveService.instance.getRecentSearchQueries();
    state = state.copyWith(recentSearches: localRecents);

    final deviceId = HiveService.instance.getOrCreateDeviceId();
    SupabaseService.instance.getRecentSearches(deviceId).then((remote) {
      if (!mounted || remote.isEmpty) return;
      final merged = <String>{...state.recentSearches, ...remote}.toList();
      state = state.copyWith(recentSearches: merged.take(20).toList());
    }).catchError((_) {});

    await searchVideos(AppConstants.hussainiKeywords.first);
  }

  Future<void> searchVideos(String query) async {
    if (query.trim().isEmpty) return;

    // Layer 3 of the search safety firewall — checked first, before any
    // network call, so an obviously abusive query never spends bandwidth
    // or API quota at all.
    if (BlacklistFilter.isQueryExplicitlyBlocked(query)) {
      state = state.copyWith(
        videos: [],
        isLoading: false,
        hasNoResults: true,
        error: 'عذراً، محتوى غير مسموح به',
        alternativeSuggestions: BlacklistFilter.buildAlternativeSuggestions(query),
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      isArchiveLoading: true,
      clearError: true,
      isOffline: false,
      query: query,
      hasNoResults: false,
      archiveResults: [],
    );

    // Archive.org runs independently of YouTube — a slow/failed Archive
    // lookup must never block or fail the primary YouTube results.
    _archiveService.search(query).then((results) {
      if (mounted) {
        state = state.copyWith(
          archiveResults: [...state.archiveResults, ...results],
          isArchiveLoading: false,
        );
      }
    }).catchError((_) {
      if (mounted) state = state.copyWith(isArchiveLoading: false);
    });

    // Audius — same independence guarantee as Archive.org above, plus
    // the full 5-layer content filter (see audio_content_filter.dart)
    // before anything from it is ever shown, since it's a general music
    // platform rather than a religious-content one.
    AudiusService.instance.search(query).then((candidates) {
      if (!mounted) return;
      final allowed = AudioContentFilter.apply(candidates);
      final mapped = allowed
          .map((c) => ArchiveAudioResult(
                identifier: c.audioUrl,
                title: c.title,
                fileName: '',
                streamUrl: c.audioUrl,
                artist: c.artist,
                sourceLabel: 'Audius',
              ))
          .toList();
      if (mapped.isNotEmpty) {
        state = state.copyWith(archiveResults: [...state.archiveResults, ...mapped]);
      }
    }).catchError((_) {});

    try {
      // ── Search cascade ────────────────────────────────────────────────
      // 1. Free intermediate cache (Supabase, then Firebase) — no quota,
      //    near-instant, and this is what makes repeated searches for the
      //    same reciter/Dua/poem cost nothing at all.
      // 2. YouTube Data API, rotating across every key on quota-exceeded.
      // 3. Piped (free, open-source YouTube front-end instances).
      // 4. Invidious — final fallback so search never truly goes dark.
      List<VideoEntity> results = await MediaCacheService.instance.getCached(query) ?? [];
      String source = 'cache';

      if (results.isEmpty) {
        try {
          results = await _useCase(query);
          source = 'youtube';
        } catch (_) {
          results = [];
        }
      }

      if (results.isEmpty) {
        try {
          results = await PipedService.instance.search(query);
          source = 'piped';
        } catch (_) {
          results = [];
        }
      }

      if (results.isEmpty) {
        try {
          results = await InvidiousService.instance.search(query);
          source = 'invidious';
        } catch (_) {
          results = [];
        }
      }

      if (source != 'cache' && results.isNotEmpty) {
        // Best-effort — warms both caches for the next person's search.
        MediaCacheService.instance.cacheInBackground(query, results);
      }

      if (results.isEmpty) {
        // Never show "no results" — provide alternatives instead
        final suggestions = BlacklistFilter.buildAlternativeSuggestions(query);
        final fallback = await _useCase(
          suggestions.isNotEmpty ? suggestions.first : 'لطميات حسينية',
        );
        state = state.copyWith(
          videos: fallback,
          isLoading: false,
          hasNoResults: true,
          alternativeSuggestions: suggestions,
        );
      } else {
        state = state.copyWith(
          videos: results,
          isLoading: false,
          hasNoResults: false,
        );
        await _recordSearchQuery(query);
      }
    } catch (e) {
      // The old code showed "تعذّر الاتصال — تحقق من الإنترنت" for *every*
      // failure — including YouTube API errors (quota, bad key, malformed
      // response) that have nothing to do with the network, which is
      // exactly what produced the false "no internet" report even on a
      // fast connection. Confirm with a real probe before blaming the
      // network; otherwise surface the actual failure so it can be fixed.
      final reallyOffline = !(await ConnectivityService.instance.hasRealInternetAccess());
      state = state.copyWith(
        isLoading: false,
        isOffline: reallyOffline,
        error: reallyOffline
            ? null
            : 'تعذّر جلب النتائج، حاول مرة أخرى'
                '${e.toString().contains('403') ? ' (تم تجاوز الحد المسموح مؤقتاً)' : ''}',
      );
    }
  }

  /// Hive write happens first and is what the search bar's suggestion
  /// list reflects immediately — the Supabase mirror is fire-and-forget
  /// and never delays or blocks the UI.
  Future<void> _recordSearchQuery(String query) async {
    await HiveService.instance.addSearchQuery(query);

    final updated = HiveService.instance.getRecentSearchQueries();
    if (mounted) state = state.copyWith(recentSearches: updated);

    final deviceId = HiveService.instance.getOrCreateDeviceId();
    unawaited(SupabaseService.instance.saveSearchQuery(deviceId, query));
  }

  Future<void> toggleFavorite(VideoEntity video) async {
    final hive = HiveService.instance;
    final key = 'favorite_${video.id}';
    final isFav = hive.hasDownload(key);

    final model = DownloadModel(
      videoId: video.id,
      title: video.title,
      channelName: video.channelTitle,
      thumbnailUrl: video.thumbnailUrl,
      category: DownloadCategory.favorite,
      downloadedAt: DateTime.now(),
      localPath: '',
      fileSizeBytes: 0,
    );

    if (isFav) {
      await hive.removeDownload(key);
      try {
        await SupabaseService.instance.removeDownload(video.id);
      } catch (_) {}
    } else {
      await hive.saveDownload(key, model.toMap());
      try {
        await SupabaseService.instance.saveDownload(model);
      } catch (_) {}
    }

    // Refresh videos with updated favorite state
    final updatedVideos = state.videos.map((v) {
      if (v.id == video.id) return v.copyWith(isFavorite: !isFav);
      return v;
    }).toList();
    state = state.copyWith(videos: updatedVideos);
  }

  Future<void> removeRecentSearch(String query) async {
    await HiveService.instance.removeSearchQuery(query);
    state = state.copyWith(recentSearches: HiveService.instance.getRecentSearchQueries());
  }

  Future<void> clearRecentSearches() async {
    await HiveService.instance.clearSearchHistory();
    state = state.copyWith(recentSearches: const []);
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ─── Provider Instances ───────────────────────────────────────────────────────
final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(
    ref.read(searchVideosUseCaseProvider),
    ref.read(archiveServiceProvider),
  );
});

final selectedVideoProvider = StateProvider<VideoEntity?>((ref) => null);
