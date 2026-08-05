import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'video_quality_option.dart';

/// Resolves YouTube videos through community-run Cobalt instances
/// (https://github.com/imputnet/cobalt) — real, currently-maintained
/// resolver servers, verified live via research rather than a guessed or
/// hardcoded list. The official `api.cobalt.tools` instance has been
/// blocked from YouTube since mid-2025 and is confirmed still blocked as
/// of 2026, so this deliberately never calls that one directly — instead
/// it pulls the current list of independent community instances from
/// `instances.cobalt.best`'s own live API and only uses ones a real
/// person can actually use programmatically:
/// - reported online right now
/// - YouTube explicitly reported working (not merely present)
/// - no Turnstile/API-key auth required (this app has no way to solve
///   that challenge)
class CobaltService {
  CobaltService._();
  static final CobaltService instance = CobaltService._();

  static const String _instanceListUrl = 'https://instances.cobalt.best/api';
  final http.Client _client = http.Client();

  // Unlike Piped/Invidious, this directory itself already verifies
  // online/no-auth/youtube-support status live — so a hardcoded fallback
  // here can't be pre-verified the same way and is a genuine long shot,
  // used only if the directory call fails outright. Kept deliberately
  // short. Best-effort as of July 2026 — Cobalt community instances are
  // known to go up/down within days (see status.cobalt.tools), so this
  // list has a shorter useful shelf life than Piped's/Invidious's.
  static const List<String> _fallbackSeedInstances = [
    'https://sunny.imput.net',
  ];

  List<String>? _cachedInstances;
  DateTime? _instancesFetchedAt;

  Future<List<String>> _liveInstances() async {
    if (_cachedInstances != null &&
        _instancesFetchedAt != null &&
        DateTime.now().difference(_instancesFetchedAt!) < const Duration(minutes: 30)) {
      return _cachedInstances!;
    }
    try {
      final response = await _client
          .get(
            Uri.parse(_instanceListUrl),
            // The directory blocks default/generic user-agents to deter
            // scraping — its own FAQ asks for an identifiable one.
            headers: {'User-Agent': 'ZadAlSaireen/1.0 (+https://zad3.pages.dev)'},
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        return (_cachedInstances?.isNotEmpty ?? false)
            ? _cachedInstances!
            : _fallbackSeedInstances;
      }

      final data = json.decode(response.body) as List<dynamic>;
      final usable = <String>[];
      for (final entry in data) {
        final map = entry as Map<String, dynamic>;
        final online = map['online'] == true;
        if (!online) continue;

        final services = map['services'] as Map<String, dynamic>?;
        final youtubeSupport = services?['youtube'];
        // The API reports either `true`/`false`, or a string describing
        // an error/limitation for that service on this instance —
        // anything other than exactly `true` means don't rely on it.
        if (youtubeSupport != true) continue;

        final info = map['info'] as Map<String, dynamic>?;
        final requiresAuth = info?['auth'] == true;
        if (requiresAuth) continue; // can't solve a Turnstile challenge

        final api = map['api']?.toString();
        final protocol = map['protocol']?.toString() ?? 'https';
        if (api == null || api.isEmpty) continue;
        usable.add('$protocol://$api');
      }

      if (usable.isNotEmpty) {
        _cachedInstances = usable;
        _instancesFetchedAt = DateTime.now();
        return _cachedInstances!;
      }
      return (_cachedInstances?.isNotEmpty ?? false) ? _cachedInstances! : _fallbackSeedInstances;
    } catch (_) {
      return (_cachedInstances?.isNotEmpty ?? false) ? _cachedInstances! : _fallbackSeedInstances;
    }
  }

  /// Races several current, working, no-auth instances at once and
  /// returns the first one that resolves a direct, playable stream URL —
  /// same concurrent-race pattern already used for Piped/Invidious,
  /// since these are also independent, volunteer-run servers of varying
  /// reliability at any given moment.
  Future<List<VideoQualityOption>> resolveVideoStreams(String videoId) async {
    final instances = await _liveInstances();
    if (instances.isEmpty) return [];

    final candidates = instances.take(8).toList();
    final completer = Completer<String?>();
    var remaining = candidates.length;

    void finishOne(String? url) {
      if (completer.isCompleted) return;
      if (url != null) {
        completer.complete(url);
      } else {
        remaining--;
        if (remaining == 0) completer.complete(null);
      }
    }

    for (final base in candidates) {
      _resolveOne(base, videoId).then(finishOne).catchError((_) => finishOne(null));
    }

    final resolvedUrl = await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
    if (resolvedUrl == null) return [];

    // Cobalt returns one already-selected quality per request rather than
    // a list of every available one — labeled "تلقائي" since the codec/
    // quality choice already happened server-side (h264, up to 720p,
    // requested below for maximum device compatibility).
    return [VideoQualityOption(label: 'تلقائي', url: resolvedUrl)];
  }

  Future<String?> _resolveOne(String base, String videoId) async {
    final response = await _client
        .post(
          Uri.parse(base),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'url': 'https://www.youtube.com/watch?v=$videoId',
            'videoQuality': '720',
            'downloadMode': 'auto',
            // AV1/VP9 (the modern default) makes many Android devices'
            // hardware decoders choke or stall entirely — h264 is what
            // actually plays smoothly on the widest range of phones.
            'youtubeVideoCodec': 'h264',
          }),
        )
        .timeout(const Duration(seconds: 7));

    if (response.statusCode != 200) return null;
    final data = json.decode(response.body) as Map<String, dynamic>;
    final status = data['status']?.toString();

    if (status == 'error') return null;

    if (status == 'picker') {
      final picker = data['picker'] as List<dynamic>?;
      if (picker == null || picker.isEmpty) return null;
      return (picker.first as Map<String, dynamic>)['url']?.toString();
    }

    // 'tunnel' / 'redirect' / 'stream' style responses all carry the
    // direct URL under `url`.
    return data['url']?.toString();
  }

  /// Cobalt's `downloadMode: 'audio'` extracts just the audio track
  /// server-side — same reliability rationale as the Piped/Invidious
  /// audio-only additions.
  Future<String?> resolveAudioOnly(String videoId) async {
    final instances = await _liveInstances();
    if (instances.isEmpty) return null;

    final candidates = instances.take(8).toList();
    final completer = Completer<String?>();
    var remaining = candidates.length;

    void finishOne(String? url) {
      if (completer.isCompleted) return;
      if (url != null) {
        completer.complete(url);
      } else {
        remaining--;
        if (remaining == 0) completer.complete(null);
      }
    }

    for (final base in candidates) {
      _resolveOneAudio(base, videoId).then(finishOne).catchError((_) => finishOne(null));
    }

    return completer.future.timeout(const Duration(seconds: 8), onTimeout: () => null);
  }

  Future<String?> _resolveOneAudio(String base, String videoId) async {
    final response = await _client
        .post(
          Uri.parse(base),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'url': 'https://www.youtube.com/watch?v=$videoId',
            'downloadMode': 'audio',
            'audioFormat': 'mp3',
          }),
        )
        .timeout(const Duration(seconds: 7));

    if (response.statusCode != 200) return null;
    final data = json.decode(response.body) as Map<String, dynamic>;
    final status = data['status']?.toString();
    if (status == 'error') return null;

    if (status == 'picker') {
      final picker = data['picker'] as List<dynamic>?;
      if (picker == null || picker.isEmpty) return null;
      return (picker.first as Map<String, dynamic>)['url']?.toString();
    }
    return data['url']?.toString();
  }
}
