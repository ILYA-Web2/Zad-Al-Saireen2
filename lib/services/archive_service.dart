import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/utils/blacklist_filter.dart';

/// A single playable audio result sourced from Archive.org — public-domain
/// / freely-licensed, so unlike YouTube it can be safely cached locally for
/// true offline replay from History.
class ArchiveAudioResult {
  const ArchiveAudioResult({
    required this.identifier,
    required this.title,
    required this.fileName,
    required this.streamUrl,
    this.artist,
    this.customThumbnailUrl,
    this.sourceLabel = 'Archive.org',
  });

  final String identifier;
  final String title;
  final String fileName;
  final String streamUrl;
  // Added so this same result type can represent tracks from sources
  // other than Archive.org (e.g. Audius, which has real artist/artwork
  // metadata that Archive.org items never did) without needing a
  // separate, parallel UI and state list just for that.
  final String? artist;
  final String? customThumbnailUrl;
  final String sourceLabel;

  String get thumbnailUrl =>
      customThumbnailUrl ?? 'https://archive.org/services/img/$identifier';
}

/// Wraps the three Archive.org endpoints needed to go from a text query to
/// a directly-playable MP3 URL:
///   1. advancedsearch.php — find album/item identifiers for the query
///   2. metadata/{identifier} — list that item's files, keep the .mp3 ones
///   3. download/{identifier}/{file} — the direct stream URL for just_audio
class ArchiveService {
  ArchiveService();

  final http.Client _client = http.Client();

  static const String _base = 'https://archive.org';

  /// Step 1 + 2 combined: searches Archive.org for [query] and resolves
  /// each matching item down to its individual playable MP3 tracks.
  /// [maxItems] bounds how many albums we resolve metadata for, since each
  /// one is a second network round-trip.
  Future<List<ArchiveAudioResult>> search(
    String query, {
    int maxItems = 8,
  }) async {
    final safeQuery = BlacklistFilter.sanitizeQuery(query);
    final items = await _searchItems(safeQuery);
    if (items.isEmpty) return [];

    // Resolved concurrently rather than one album after another — with
    // maxItems=8 and a 10s timeout each, the old sequential loop's worst
    // case was ~80s before any result appeared. Running them together
    // caps the wait at whichever single album is slowest, matching the
    // same concurrent pattern already used for Piped/Invidious/Cobalt.
    final perAlbum = await Future.wait(
      items.take(maxItems).map((item) => _resolveTracks(item.identifier, item.title)),
    );
    final results = perAlbum.expand((tracks) => tracks).toList();

    // Archive.org is a fully open, unmoderated public archive — unlike
    // YouTube/Piped/Invidious, nothing here has ever been screened, so the
    // same religious-token requirement used everywhere else must be
    // applied here too. This was previously missing entirely.
    return results
        .where((r) => BlacklistFilter.isContentAllowed(r.title, ''))
        .toList();
  }

  /// Endpoint 1 — https://archive.org/advancedsearch.php
  Future<List<_ArchiveItem>> _searchItems(String query) async {
    final uri = Uri.parse(
      '$_base/advancedsearch.php'
      '?q=subject:(${Uri.encodeComponent(query)}) AND mediatype:(audio)'
      '&fl[]=identifier&fl[]=title'
      '&rows=30'
      '&output=json',
    );

    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final docs = (data['response']?['docs'] as List<dynamic>?) ?? [];

      return docs
          .map((d) => _ArchiveItem(
                identifier: d['identifier']?.toString() ?? '',
                title: d['title']?.toString() ?? '',
              ))
          .where((i) => i.identifier.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Endpoint 2 — https://archive.org/metadata/{identifier}
  /// Filters to .mp3 files only and builds the endpoint-3 direct stream URL
  /// for each.
  Future<List<ArchiveAudioResult>> _resolveTracks(
      String identifier, String albumTitle) async {
    final uri = Uri.parse('$_base/metadata/$identifier');
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final files = (data['files'] as List<dynamic>?) ?? [];

      return files
          .map((f) => f as Map<String, dynamic>)
          .where((f) => (f['name']?.toString() ?? '').toLowerCase().endsWith('.mp3'))
          .map((f) {
            final name = f['name'].toString();
            return ArchiveAudioResult(
              identifier: identifier,
              title: albumTitle.isNotEmpty ? albumTitle : name,
              fileName: name,
              // Endpoint 3 — direct stream URL for just_audio.
              streamUrl: '$_base/download/$identifier/${Uri.encodeComponent(name)}',
            );
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  void dispose() => _client.close();
}

class _ArchiveItem {
  const _ArchiveItem({required this.identifier, required this.title});
  final String identifier;
  final String title;
}
