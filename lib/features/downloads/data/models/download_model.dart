enum DownloadCategory { audio, favorite, quran }

extension DownloadCategoryX on DownloadCategory {
  String get label {
    switch (this) {
      case DownloadCategory.audio:
        return 'التنزيلات';
      case DownloadCategory.favorite:
        return 'مفضلات';
      case DownloadCategory.quran:
        return 'القرآن';
    }
  }

  /// NOTE: intentionally still returns the original 'audio' string even
  /// though the user-facing label is now "التنزيلات" — this is the actual
  /// Hive/Supabase storage key for every download already saved by
  /// existing users. Changing this string would silently orphan their
  /// existing downloaded files (new hiveKey wouldn't match the old one).
  /// Only the display label above was renamed.
  String get storageKey {
    switch (this) {
      case DownloadCategory.audio:
        return 'audio';
      case DownloadCategory.favorite:
        return 'favorite';
      case DownloadCategory.quran:
        return 'quran';
    }
  }

  static DownloadCategory fromKey(String key) {
    switch (key) {
      case 'favorite':
        return DownloadCategory.favorite;
      case 'quran':
        return DownloadCategory.quran;
      default:
        return DownloadCategory.audio;
    }
  }
}

class DownloadModel {
  const DownloadModel({
    required this.videoId,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    required this.category,
    required this.downloadedAt,
    required this.localPath,
    required this.fileSizeBytes,
  });

  final String videoId;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final DownloadCategory category;
  final DateTime downloadedAt;
  final String localPath;
  final int fileSizeBytes;

  /// Unique per category+videoId — using the bare [videoId] as the Hive
  /// key let a "favorite" and a real "download" of the same video
  /// silently overwrite each other, since they'd otherwise collide on the
  /// same key.
  String get hiveKey => '${category.storageKey}_$videoId';

  factory DownloadModel.fromMap(Map<String, dynamic> map) {
    return DownloadModel(
      videoId: map['video_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      channelName: map['channel_name']?.toString() ?? '',
      thumbnailUrl: map['thumbnail_url']?.toString() ?? '',
      category: DownloadCategoryX.fromKey(
          map['category']?.toString() ?? 'video'),
      downloadedAt: DateTime.tryParse(
              map['downloaded_at']?.toString() ?? '') ??
          DateTime.now(),
      localPath: map['local_path']?.toString() ?? '',
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'video_id': videoId,
      'title': title,
      'channel_name': channelName,
      'thumbnail_url': thumbnailUrl,
      'category': category.storageKey,
      'downloaded_at': downloadedAt.toIso8601String(),
      'local_path': localPath,
      'file_size_bytes': fileSizeBytes,
      'created_at': downloadedAt.toIso8601String(),
    };
  }

  String get formattedSize {
    if (fileSizeBytes <= 0) return '— م.ب';
    final mb = fileSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} م.ب';
  }
}
