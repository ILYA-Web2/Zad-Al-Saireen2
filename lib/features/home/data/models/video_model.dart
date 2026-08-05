import '../../domain/entities/video_entity.dart';

class VideoModel extends VideoEntity {
  const VideoModel({
    required super.id,
    required super.title,
    required super.description,
    required super.thumbnailUrl,
    required super.channelTitle,
    required super.publishedAt,
    super.duration,
    super.viewCount,
    super.isFavorite,
    super.isDownloaded,
  });

  factory VideoModel.fromYoutubeJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] as Map<String, dynamic>? ?? {};
    final id = json['id'] as Map<String, dynamic>? ?? {};
    final videoId = id['videoId']?.toString() ?? '';

    final thumbnails =
        snippet['thumbnails'] as Map<String, dynamic>? ?? {};
    final highThumb = thumbnails['high'] as Map<String, dynamic>? ??
        thumbnails['medium'] as Map<String, dynamic>? ??
        {};
    final thumbnailUrl = highThumb['url']?.toString() ??
        'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

    DateTime publishedAt;
    try {
      publishedAt = DateTime.parse(
          snippet['publishedAt']?.toString() ?? DateTime.now().toIso8601String());
    } catch (_) {
      publishedAt = DateTime.now();
    }

    return VideoModel(
      id: videoId,
      title: snippet['title']?.toString() ?? '',
      description: snippet['description']?.toString() ?? '',
      thumbnailUrl: thumbnailUrl,
      channelTitle: snippet['channelTitle']?.toString() ?? '',
      publishedAt: publishedAt,
    );
  }

  factory VideoModel.fromVideoDetailsJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] as Map<String, dynamic>? ?? {};
    final contentDetails =
        json['contentDetails'] as Map<String, dynamic>? ?? {};
    final statistics = json['statistics'] as Map<String, dynamic>? ?? {};
    final videoId = json['id']?.toString() ?? '';

    final thumbnails =
        snippet['thumbnails'] as Map<String, dynamic>? ?? {};
    final maxThumb = thumbnails['maxres'] as Map<String, dynamic>? ??
        thumbnails['high'] as Map<String, dynamic>? ?? {};
    final thumbnailUrl = maxThumb['url']?.toString() ??
        'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

    DateTime publishedAt;
    try {
      publishedAt = DateTime.parse(
          snippet['publishedAt']?.toString() ?? DateTime.now().toIso8601String());
    } catch (_) {
      publishedAt = DateTime.now();
    }

    int? viewCount;
    try {
      viewCount = int.parse(statistics['viewCount']?.toString() ?? '0');
    } catch (_) {
      viewCount = 0;
    }

    return VideoModel(
      id: videoId,
      title: snippet['title']?.toString() ?? '',
      description: snippet['description']?.toString() ?? '',
      thumbnailUrl: thumbnailUrl,
      channelTitle: snippet['channelTitle']?.toString() ?? '',
      publishedAt: publishedAt,
      duration: contentDetails['duration']?.toString(),
      viewCount: viewCount,
    );
  }

  factory VideoModel.fromMap(Map<String, dynamic> map) {
    return VideoModel(
      id: map['video_id']?.toString() ?? '',
      title: map['video_title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      thumbnailUrl: map['video_thumbnail']?.toString() ?? '',
      channelTitle: map['channel_name']?.toString() ?? '',
      publishedAt: DateTime.now(),
      isFavorite: map['is_favorite'] as bool? ?? false,
      isDownloaded: map['is_downloaded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'video_id': id,
      'video_title': title,
      'description': description,
      'video_thumbnail': thumbnailUrl,
      'channel_name': channelTitle,
      'is_favorite': isFavorite,
      'is_downloaded': isDownloaded,
    };
  }

  // ─── Cache serialization (Supabase media_cache / Firebase RTDB) ──────────
  Map<String, dynamic> toCacheJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnail_url': thumbnailUrl,
      'channel_title': channelTitle,
      'published_at': publishedAt.toIso8601String(),
      'duration': duration,
      'view_count': viewCount,
    };
  }

  factory VideoModel.fromCacheJson(Map<String, dynamic> json) {
    DateTime publishedAt;
    try {
      publishedAt = DateTime.parse(json['published_at']?.toString() ?? '');
    } catch (_) {
      publishedAt = DateTime.now();
    }
    return VideoModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      channelTitle: json['channel_title']?.toString() ?? '',
      publishedAt: publishedAt,
      duration: json['duration']?.toString(),
      viewCount: (json['view_count'] as num?)?.toInt(),
    );
  }

  // ─── Piped (https://github.com/TeamPiped/Piped) ───────────────────────────
  factory VideoModel.fromPipedJson(Map<String, dynamic> json) {
    // Piped item "url" looks like "/watch?v=VIDEO_ID".
    final url = json['url']?.toString() ?? '';
    final videoId = Uri.tryParse(url)?.queryParameters['v'] ?? '';
    return VideoModel(
      id: videoId,
      title: json['title']?.toString() ?? '',
      description: json['shortDescription']?.toString() ?? '',
      thumbnailUrl: json['thumbnail']?.toString() ??
          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      channelTitle: json['uploaderName']?.toString() ?? '',
      publishedAt: DateTime.now(),
      duration: json['duration'] != null ? '${json['duration']}' : null,
      viewCount: (json['views'] as num?)?.toInt(),
    );
  }

  // ─── Invidious (https://github.com/iv-org/invidious) ──────────────────────
  factory VideoModel.fromInvidiousJson(Map<String, dynamic> json) {
    final thumbnails = json['videoThumbnails'] as List<dynamic>? ?? [];
    String thumbnailUrl = '';
    if (thumbnails.isNotEmpty) {
      final highRes = thumbnails.firstWhere(
        (t) => t['quality'] == 'high' || t['quality'] == 'medium',
        orElse: () => thumbnails.first,
      );
      thumbnailUrl = highRes['url']?.toString() ?? '';
    }
    final videoId = json['videoId']?.toString() ?? '';
    if (thumbnailUrl.isEmpty) {
      thumbnailUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    }
    return VideoModel(
      id: videoId,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      thumbnailUrl: thumbnailUrl,
      channelTitle: json['author']?.toString() ?? '',
      publishedAt: DateTime.now(),
      duration: json['lengthSeconds'] != null ? '${json['lengthSeconds']}' : null,
      viewCount: (json['viewCount'] as num?)?.toInt(),
    );
  }
}
