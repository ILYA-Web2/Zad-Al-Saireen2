import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/utils/blacklist_filter.dart';
import '../features/home/data/models/video_model.dart';
import 'youtube_key_rotation_manager.dart';

class YoutubeService {
  YoutubeService();

  final http.Client _client = http.Client();

  /// GETs [buildUri] (given a YouTube API key), automatically rotating to
  /// the next available key and retrying if the current one comes back
  /// quota-exceeded (403) — the request only fails once every key in
  /// [AppConstants.youtubeApiKeys] is exhausted.
  Future<http.Response> _getWithRotation(
    Uri Function(String apiKey) buildUri,
  ) async {
    final keys = YoutubeKeyRotationManager.instance.availableKeysInOrder();
    if (keys.isEmpty) {
      throw YoutubeApiException('كل مفاتيح YouTube API مستنفدة حالياً');
    }

    http.Response? lastResponse;
    for (final key in keys) {
      final http.Response response;
      try {
        response = await _client
            .get(buildUri(key), headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // This key's request timed out or errored — try the next one
        // immediately rather than let the whole search stall.
        continue;
      }
      lastResponse = response;

      // Google returns 403 for several distinct key-related reasons, not
      // just "quotaExceeded" (e.g. keyInvalid, accessNotConfigured,
      // ipRefererBlocked, dailyLimitExceededUnreg). Previously only the
      // literal "quotaExceeded" string rotated to the next key — any other
      // 403 reason on the *first* key tried was returned straight to the
      // caller as a failure, even if the remaining 3 keys were perfectly
      // usable. Any 403 here is worth trying the next key for.
      if (response.statusCode == 403) {
        if (response.body.contains('quotaExceeded') ||
            response.body.contains('dailyLimit')) {
          YoutubeKeyRotationManager.instance.reportQuotaExceeded(key);
        }
        continue; // try the next key immediately, transparently to the user
      }
      return response;
    }
    // Every key hit quota-exceeded, or every attempt timed out.
    if (lastResponse == null) {
      throw YoutubeApiException('تعذّر الاتصال بخوادم يوتيوب');
    }
    return lastResponse;
  }

  // ─── Search Videos ────────────────────────────────────────────────────────
  Future<List<VideoModel>> searchVideos({
    required String query,
    String? pageToken,
    int maxResults = AppConstants.youtubeMaxResults,
  }) async {
    final safeQuery = BlacklistFilter.sanitizeQuery(query);

    final response = await _getWithRotation((apiKey) => Uri.parse(
          '${AppConstants.youtubeBaseUrl}/search'
          '?part=snippet'
          '&q=${Uri.encodeComponent(safeQuery)}'
          '&type=video'
          '&maxResults=$maxResults'
          '&safeSearch=strict'
          '&relevanceLanguage=ar'
          '&key=$apiKey'
          '${pageToken != null ? '&pageToken=$pageToken' : ''}',
        ));

    if (response.statusCode != 200) {
      throw YoutubeApiException(
          'YouTube API error: ${response.statusCode} — ${response.body}');
    }

    final Map<String, dynamic> data = json.decode(response.body);
    final items = data['items'] as List<dynamic>? ?? [];

    final videos = items
        .map((item) => VideoModel.fromYoutubeJson(item as Map<String, dynamic>))
        .where((video) => video.id.isNotEmpty)
        .where((video) =>
            BlacklistFilter.isContentAllowed(video.title, video.description))
        .toList();

    return videos;
  }

  // ─── Get Video Details ────────────────────────────────────────────────────
  Future<VideoModel?> getVideoDetails(String videoId) async {
    final response = await _getWithRotation((apiKey) => Uri.parse(
          '${AppConstants.youtubeBaseUrl}/videos'
          '?part=snippet,contentDetails,statistics'
          '&id=$videoId'
          '&key=$apiKey',
        ));

    if (response.statusCode != 200) {
      throw YoutubeApiException('Failed to fetch video details: $videoId');
    }

    final Map<String, dynamic> data = json.decode(response.body);
    final items = data['items'] as List<dynamic>? ?? [];

    if (items.isEmpty) return null;

    return VideoModel.fromVideoDetailsJson(
        items.first as Map<String, dynamic>);
  }

  // ─── Get Related Videos ───────────────────────────────────────────────────
  // YouTube deprecated `relatedToVideoId` on the Data API years ago — it no
  // longer returns real results, which is exactly why "related videos"
  // never appeared. The standard workaround since then is a proxy search
  // (channel name / title) with the current video excluded.
  Future<List<VideoModel>> getRelatedVideos(
    String videoId, {
    String? channelTitle,
    String? title,
  }) async {
    final proxyQuery = (channelTitle != null && channelTitle.isNotEmpty)
        ? channelTitle
        : (title ?? '');
    if (proxyQuery.isEmpty) return [];

    final response = await _getWithRotation((apiKey) => Uri.parse(
          '${AppConstants.youtubeBaseUrl}/search'
          '?part=snippet'
          '&q=${Uri.encodeComponent(proxyQuery)}'
          '&type=video'
          '&maxResults=12'
          '&safeSearch=strict'
          '&key=$apiKey',
        ));

    if (response.statusCode != 200) return [];

    final Map<String, dynamic> data = json.decode(response.body);
    final items = data['items'] as List<dynamic>? ?? [];

    return items
        .map((item) => VideoModel.fromYoutubeJson(item as Map<String, dynamic>))
        .where((v) => v.id.isNotEmpty)
        .where((v) => v.id != videoId)
        .where((v) => BlacklistFilter.isContentAllowed(v.title, v.description))
        .toList();
  }

  // ─── Build YouTube Watch URL ──────────────────────────────────────────────
  static String buildWatchUrl(String videoId) {
    return 'https://www.youtube.com/watch?v=$videoId';
  }

  // ─── Build Thumbnail URL ──────────────────────────────────────────────────
  static String buildThumbnailUrl(String videoId,
      {ThumbnailQuality quality = ThumbnailQuality.high}) {
    switch (quality) {
      case ThumbnailQuality.max:
        return 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
      case ThumbnailQuality.high:
        return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      case ThumbnailQuality.medium:
        return 'https://img.youtube.com/vi/$videoId/mqdefault.jpg';
      case ThumbnailQuality.standard:
        return 'https://img.youtube.com/vi/$videoId/sddefault.jpg';
    }
  }

  void dispose() {
    _client.close();
  }
}

enum ThumbnailQuality { max, high, medium, standard }

class YoutubeApiException implements Exception {
  YoutubeApiException(this.message);
  final String message;
  @override
  String toString() => 'YoutubeApiException: $message';
}
