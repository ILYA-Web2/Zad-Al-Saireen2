// ─── Domain Entity ────────────────────────────────────────────────────────────
class VideoEntity {
  const VideoEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.channelTitle,
    required this.publishedAt,
    this.duration,
    this.viewCount,
    this.isFavorite = false,
    this.isDownloaded = false,
  });

  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String channelTitle;
  final DateTime publishedAt;
  final String? duration;
  final int? viewCount;
  final bool isFavorite;
  final bool isDownloaded;

  VideoEntity copyWith({
    String? id,
    String? title,
    String? description,
    String? thumbnailUrl,
    String? channelTitle,
    DateTime? publishedAt,
    String? duration,
    int? viewCount,
    bool? isFavorite,
    bool? isDownloaded,
  }) {
    return VideoEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      channelTitle: channelTitle ?? this.channelTitle,
      publishedAt: publishedAt ?? this.publishedAt,
      duration: duration ?? this.duration,
      viewCount: viewCount ?? this.viewCount,
      isFavorite: isFavorite ?? this.isFavorite,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$id';
  String get embedUrl =>
      'https://www.youtube.com/embed/$id?autoplay=1&rel=0&modestbranding=1';
}
