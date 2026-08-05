import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/blacklist_filter.dart';

/// A candidate audio result before it passes (or fails) the 5-layer
/// filter pipeline below.
class AudioCandidate {
  const AudioCandidate({
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.genreTags = const [],
    this.mimeType,
    this.durationSeconds,
  });

  final String title;
  final String artist;
  final String audioUrl;
  final List<String> genreTags;
  final String? mimeType;
  final int? durationSeconds;
}

/// The 5-layer filtering pipeline: every search result — regardless of
/// which upstream source it came from (Audius, Piped, a manually-curated
/// track) — passes through all 5 layers before ever reaching the UI.
///
/// Layers 1–2 (query sanitizing, religious-token whitelist + blacklist)
/// already existed in [BlacklistFilter] from the video-search era and are
/// reused here unchanged rather than duplicated. Layers 3–5 (genre-tag
/// rejection, duration/MIME validation, known-reciter re-ranking) are new
/// — audio platforms like Audius expose real genre metadata that video
/// platforms didn't, so this is a strictly stronger filter than before,
/// not a weaker replacement.
class AudioContentFilter {
  AudioContentFilter._();

  /// Genre tags that immediately disqualify a track regardless of what
  /// its title says — these come from the *platform's own classification*
  /// of the track, which is far harder to game than title text alone.
  static const Set<String> _disallowedGenres = {
    'pop', 'rock', 'dance', 'hip-hop', 'hiphop', 'rap', 'electronic',
    'edm', 'metal', 'punk', 'r&b', 'rnb', 'reggae', 'country', 'jazz',
    'blues', 'disco', 'house', 'techno', 'trance', 'dubstep',
  };

  /// Reciters/reciting styles that get a visibility boost when they
  /// appear in the artist field — a small, known-good list, not an
  /// attempt to enumerate every legitimate reciter (that's what the
  /// religious-token whitelist in [BlacklistFilter] already does; this
  /// list only affects *ordering*, never inclusion/exclusion).
  static const List<String> _knownReciters = [
    'الكربلائي', 'الوائلي', 'الموسوي', 'الساعدي', 'البصري', 'الحلي',
    'العبادي', 'المياحي', 'البديري', 'الحسيني', 'كربلائي', 'وائلي',
  ];

  static const int _minDurationSeconds = 30;

  /// Runs the full pipeline. Returns the allowed subset, already
  /// re-ranked (layer 5) — nothing further needs to be done by the
  /// caller before displaying results.
  static List<AudioCandidate> apply(List<AudioCandidate> candidates) {
    final survivors = candidates.where(_passesLayers1to4).toList();
    survivors.sort((a, b) => _rerankScore(b).compareTo(_rerankScore(a)));
    return survivors;
  }

  static bool _passesLayers1to4(AudioCandidate c) {
    // Layer 1+2 — reuse the existing query/content whitelist+blacklist.
    if (!BlacklistFilter.isContentAllowed(c.title, c.artist)) return false;

    // Layer 3 — genre-tag rejection using real platform metadata.
    for (final tag in c.genreTags) {
      if (_disallowedGenres.contains(tag.toLowerCase().trim())) return false;
    }

    // Layer 4 — structural validation: reject anything without a real
    // audio URL, suspiciously short clips, or a non-audio MIME type when
    // that metadata is actually available (many sources don't report
    // MIME at all, in which case this check is skipped rather than
    // wrongly rejecting a track just for missing metadata).
    if (c.audioUrl.trim().isEmpty) return false;
    if (c.durationSeconds != null && c.durationSeconds! < _minDurationSeconds) return false;
    if (c.mimeType != null && !c.mimeType!.startsWith('audio/')) return false;

    return true;
  }

  // Layer 5 — re-ranking only, never a pass/fail gate.
  static int _rerankScore(AudioCandidate c) {
    final artistLower = c.artist.toLowerCase();
    final titleLower = c.title.toLowerCase();
    var score = 0;
    for (final reciter in _knownReciters) {
      if (artistLower.contains(reciter) || titleLower.contains(reciter)) {
        score += 10;
        break;
      }
    }
    for (final keyword in AppConstants.hussainiKeywords) {
      if (titleLower.contains(keyword.toLowerCase())) score += 1;
    }
    return score;
  }
}
