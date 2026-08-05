import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/utils/blacklist_filter.dart';
import '../features/home/data/models/video_model.dart';
import 'video_quality_option.dart';

/// Free, open-source YouTube front-end instances
/// (https://github.com/iv-org/invidious) — the last line of defense once
/// every YouTube API key AND every Piped instance have failed, so the app
/// never truly goes dark for search.
class InvidiousService {
  InvidiousService._();
  static final InvidiousService instance = InvidiousService._();

  final http.Client _client = http.Client();
  List<String>? _cachedInstances;

  // Same reasoning as PipedService's fallback list: api.invidious.io's own
  // documentation notes its public instance list has gotten short due to
  // YouTube's anti-scraping pressure through 2025-2026, and the endpoint
  // itself can be flaky. These are current, officially-documented public
  // instances (iv-org/documentation) kept as a last-resort seed — best
  // effort as of July 2026, may need refreshing over time.
  static const List<String> _fallbackSeedInstances = [
    'https://yewtu.be',
    'https://inv.nadeko.net',
    'https://invidious.tiekoetter.com',
    'https://inv.thepixora.com',
  ];

  Future<List<String>> _liveInstances() async {
    if (_cachedInstances != null) return _cachedInstances!;
    try {
      final response = await _client
          .get(Uri.parse(AppConstants.invidiousInstancesUrl))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return _fallbackSeedInstances;
      // Format: [["name", {"uri": "https://...", "type": "https", ...}], ...]
      final data = json.decode(response.body) as List<dynamic>;
      final urls = <String>[];
      for (final entry in data) {
        if (entry is List && entry.length >= 2 && entry[1] is Map) {
          final info = entry[1] as Map<String, dynamic>;
          final uri = info['uri']?.toString();
          if (uri != null && uri.startsWith('https://')) urls.add(uri);
        }
      }
      if (urls.isEmpty) return _fallbackSeedInstances;
      _cachedInstances = {...urls, ..._fallbackSeedInstances}.toList();
      return _cachedInstances!;
    } catch (_) {
      return _fallbackSeedInstances;
    }
  }

  /// Same concurrent-race approach as [PipedService]'s equivalent method —
  /// races several instances at once instead of summing up each one's
  /// timeout sequentially.
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
        '$base/api/v1/search?q=${Uri.encodeComponent(safeQuery)}&type=video'));
    if (response == null) return [];

    try {
      final data = json.decode(response.body) as List<dynamic>;
      return data
          .map((i) => VideoModel.fromInvidiousJson(i as Map<String, dynamic>))
          .where((v) => v.id.isNotEmpty)
          .where((v) => BlacklistFilter.isContentAllowed(v.title, v.description))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Real, direct, quality-labeled video stream URLs from Invidious's
  /// `formatStreams` field — unlike `adaptiveFormats` (which splits video
  /// and audio into separate streams), these are already muxed together,
  /// exactly what a plain video player needs.
  Future<List<VideoQualityOption>> resolveVideoStreams(String videoId) async {
    final response =
        await _tryInstances((base) => Uri.parse('$base/api/v1/videos/$videoId'));
    if (response == null) return [];

    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final formatStreams = data['formatStreams'] as List<dynamic>? ?? [];
      if (formatStreams.isEmpty) return [];

      return formatStreams
          .map((f) => f as Map<String, dynamic>)
          .map((f) => VideoQualityOption(
                label: f['qualityLabel']?.toString() ?? '',
                url: f['url']?.toString() ?? '',
              ))
          .where((q) => q.url.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Same reasoning as PipedService.resolveAudioOnly — Invidious exposes
  /// audio-only tracks separately under `adaptiveFormats`, which is a
  /// meaningfully more reliable source than `formatStreams` (muxed).
  Future<String?> resolveAudioOnly(String videoId) async {
    final response =
        await _tryInstances((base) => Uri.parse('$base/api/v1/videos/$videoId'));
    if (response == null) return null;

    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final adaptive = (data['adaptiveFormats'] as List<dynamic>? ?? [])
          .map((f) => f as Map<String, dynamic>)
          .where((f) => (f['type']?.toString() ?? '').startsWith('audio/'))
          .toList();
      if (adaptive.isEmpty) return null;

      adaptive.sort((a, b) {
        final ab = int.tryParse(a['bitrate']?.toString() ?? '') ?? 0;
        final bb = int.tryParse(b['bitrate']?.toString() ?? '') ?? 0;
        return bb.compareTo(ab);
      });
      final url = adaptive.first['url']?.toString();
      return (url != null && url.isNotEmpty) ? url : null;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
