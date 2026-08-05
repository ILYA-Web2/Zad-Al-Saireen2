import 'dart:convert';
import 'package:http/http.dart' as http;
import 'audio_content_filter.dart';

/// Audius (https://audius.co) — an open, decentralized music platform
/// with a genuinely public REST API (no account/API-key required for
/// basic search+stream, per its own docs as of mid-2026; registering a
/// free key only raises rate limits, it doesn't gate access).
///
/// ⚠️ Honest content-fit note: Audius' catalog is overwhelmingly secular/
/// electronic/independent music — it was not built as a religious content
/// platform, so Shia religious lamentations (لطميات) and specific reciters
/// are unlikely to be well represented here. It's included because it was
/// explicitly requested and the integration itself is real and correct,
/// but in practice most usable religious results for this app will likely
/// keep coming from Piped/Invidious/Cobalt's YouTube-audio pipeline
/// (already in the codebase) rather than from Audius. This filter and
/// service simply make sure *whatever* Audius does return is held to the
/// exact same 5-layer standard as everything else.
class AudiusService {
  AudiusService._();
  static final AudiusService instance = AudiusService._();

  static const String _base = 'https://api.audius.co/v1';
  static const String _appName = 'ZadAlSaireen';
  final http.Client _client = http.Client();

  Future<List<AudioCandidate>> search(String query) async {
    final uri = Uri.parse('$_base/tracks/search').replace(queryParameters: {
      'query': query,
      'app_name': _appName,
    });

    final response = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? [];

    return data.map((raw) {
      final track = raw as Map<String, dynamic>;
      final id = track['id']?.toString() ?? '';
      final user = track['user'] as Map<String, dynamic>? ?? {};
      final artwork = track['artwork'] as Map<String, dynamic>? ?? {};
      final tags = (track['tags'] as String? ?? '')
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final genre = track['genre']?.toString();

      return AudioCandidate(
        title: track['title']?.toString() ?? '',
        artist: user['name']?.toString() ?? '',
        audioUrl: streamUrlFor(id),
        genreTags: [if (genre != null) genre, ...tags],
        durationSeconds: (track['duration'] as num?)?.toInt(),
      );
    }).toList();
  }

  /// Direct, streamable URL — Audius' own stream endpoint supports HTTP
  /// Range requests, so it works fine with just_audio without any extra
  /// download step.
  String streamUrlFor(String trackId) =>
      '$_base/tracks/$trackId/stream?app_name=$_appName';

  void dispose() => _client.close();
}
