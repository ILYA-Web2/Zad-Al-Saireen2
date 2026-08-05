import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/utils/blacklist_filter.dart';
import '../features/home/data/models/video_model.dart';
import 'video_quality_option.dart';

/// Free, open-source YouTube front-end instances
/// (https://github.com/TeamPiped/Piped). Used as a fallback once every
/// rotated YouTube API key is quota-exceeded, and as a way to resolve
/// video streams when direct extraction fails.
class PipedService {
  PipedService._();
  static final PipedService instance = PipedService._();

  final http.Client _client = http.Client();
  List<String>? _cachedInstances;

  // piped-instances.kavin.rocks (the live discovery endpoint below) has a
  // documented history of intermittently returning 502 or an empty list
  // (see TeamPiped/Piped issues #4022, #4109) — when that happens, this
  // entire fallback tier used to silently return zero results forever,
  // with no way to recover until the discovery endpoint itself came
  // back. These are real, independently-run Piped API instances (from
  // the project's own published instance list) used only when the live
  // discovery call fails outright — best-effort as of July 2026; Piped
  // instances do come and go, so this list may need refreshing
  // periodically, but even a partially-stale list beats returning nothing.
  static const List<String> _fallbackSeedInstances = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi-libre.kavin.rocks',
    'https://api.piped.yt',
    'https://pipedapi.adminforge.de',
    'https://pipedapi.drgns.space',
  ];

  /// Fetches the current list of live Piped API base URLs. Cached in
  /// memory for the process lifetime so every search doesn't re-fetch the
  /// instance list.
  Future<List<String>> _liveInstances() async {
    if (_cachedInstances != null) return _cachedInstances!;
    try {
      final response = await _client
          .get(Uri.parse(AppConstants.pipedInstancesUrl))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return _fallbackSeedInstances;
      final data = json.decode(response.body) as List<dynamic>;
      final urls = data
          .map((e) => (e as Map<String, dynamic>)['api_url']?.toString() ?? '')
          .where((u) => u.isNotEmpty)
          .toList();
      if (urls.isEmpty) return _fallbackSeedInstances;
      // Merge rather than replace — a handful of known-stable instances
      // as extra racing candidates costs nothing (they're only ever
      // raced, never blocking) and adds resilience if some of the freshly
      // discovered ones happen to be down right now.
      _cachedInstances = {...urls, ..._fallbackSeedInstances}.toList();
      return _cachedInstances!;
    } catch (_) {
      return _fallbackSeedInstances;
    }
  }

  /// Tries several live instances **concurrently** and returns whichever
  /// answers first successfully — public volunteer-run instances come and
  /// go, and trying them one after another (each with its own timeout)
  /// meant the worst case was the *sum* of every instance's timeout
  /// before giving up. Racing them caps the wait at whichever single
  /// instance is fastest to respond.
  Future<http.Response?> _tryInstances(
    Uri Function(String baseUrl) request,
  ) async {
    final instances = await _liveInstances();
    if (instances.isEmpty) return null;

    final candidates = instances.take(8).toList();
    final completer = Completer<http.Response?>();
    var remaining = candidates.length;

    for (final base in candidates) {
      _client
          .get(request(base))
          .timeout(const Duration(seconds: 6))
          .then((response) {
        if (completer.isCompleted) return;
        if (response.statusCode == 200) {
          completer.complete(response);
        } else {
          remaining--;
          if (remaining == 0 && !completer.isCompleted) completer.complete(null);
        }
      }).catchError((_) {
        if (completer.isCompleted) return;
        remaining--;
        if (remaining == 0) completer.complete(null);
      });
    }

    return completer.future;
  }

  Future<List<VideoModel>> search(String query) async {
    final safeQuery = BlacklistFilter.sanitizeQuery(query);
    final response = await _tryInstances((base) => Uri.parse(
        '$base/search?q=${Uri.encodeComponent(safeQuery)}&filter=videos'));
    if (response == null) return [];

    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((i) => VideoModel.fromPipedJson(i as Map<String, dynamic>))
          .where((v) => v.id.isNotEmpty)
          .where((v) => BlacklistFilter.isContentAllowed(v.title, v.description))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Real, direct, quality-labeled video stream URLs from Piped's own
  /// `/streams/{id}` endpoint — used as the video-playback fallback when
  /// direct YouTube extraction fails.
  Future<List<VideoQualityOption>> resolveVideoStreams(String videoId) async {
    final response =
        await _tryInstances((base) => Uri.parse('$base/streams/$videoId'));
    if (response == null) return [];

    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      // Piped's videoStreams are already muxed (video+audio) when the
      // "videoOnly" field is false — those are what a plain video player
      // needs; video-only streams would need a separate audio track muxed
      // in, which this app's player doesn't do.
      final videoStreams = (data['videoStreams'] as List<dynamic>? ?? [])
          .map((s) => s as Map<String, dynamic>)
          .where((s) => s['videoOnly'] != true)
          .toList();
      if (videoStreams.isEmpty) return [];

      return videoStreams
          .map((s) => VideoQualityOption(
                label: s['quality']?.toString() ?? '',
                url: s['url']?.toString() ?? '',
              ))
          .where((q) => q.url.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Audio-only stream URL (no video track at all) — the actual fix for
  /// the reliability problem the muxed video pipeline has: YouTube (and
  /// by extension Piped, which extracts from it) offers audio-only
  /// streams far more consistently than combined video+audio ones, which
  /// have been shrinking in availability industry-wide. Returns the
  /// highest-bitrate option, or null if this instance has none.
  Future<String?> resolveAudioOnly(String videoId) async {
    final response =
        await _tryInstances((base) => Uri.parse('$base/streams/$videoId'));
    if (response == null) return null;

    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final audioStreams = (data['audioStreams'] as List<dynamic>? ?? [])
          .map((s) => s as Map<String, dynamic>)
          .toList();
      if (audioStreams.isEmpty) return null;

      audioStreams.sort((a, b) {
        final ab = (a['bitrate'] as num?)?.toInt() ?? 0;
        final bb = (b['bitrate'] as num?)?.toInt() ?? 0;
        return bb.compareTo(ab);
      });
      final url = audioStreams.first['url']?.toString();
      return (url != null && url.isNotEmpty) ? url : null;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
