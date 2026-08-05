enum HistoryType { quran, video, dua }

extension HistoryTypeX on HistoryType {
  String get storageKey {
    switch (this) {
      case HistoryType.quran:
        return 'quran';
      case HistoryType.video:
        return 'video';
      case HistoryType.dua:
        return 'dua';
    }
  }

  static HistoryType fromKey(String key) {
    switch (key) {
      case 'video':
        return HistoryType.video;
      case 'dua':
        return HistoryType.dua;
      default:
        return HistoryType.quran;
    }
  }
}

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.route,
    required this.playedAt,
  });

  /// Stable key so replaying the same item updates its timestamp instead of
  /// duplicating the entry.
  final String id;
  final HistoryType type;
  final String title;
  final String subtitle;
  final String thumbnailUrl;

  /// Deep-link route to resume this item (e.g. `/quran/12` or `/player/xyz`).
  final String route;
  final DateTime playedAt;

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      id: map['id']?.toString() ?? '',
      type: HistoryTypeX.fromKey(map['type']?.toString() ?? 'quran'),
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      thumbnailUrl: map['thumbnail_url']?.toString() ?? '',
      route: map['route']?.toString() ?? '',
      playedAt:
          DateTime.tryParse(map['played_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.storageKey,
      'title': title,
      'subtitle': subtitle,
      'thumbnail_url': thumbnailUrl,
      'route': route,
      'played_at': playedAt.toIso8601String(),
    };
  }
}
