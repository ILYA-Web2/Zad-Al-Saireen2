import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'piped_service.dart';
import 'invidious_service.dart';
import 'cobalt_service.dart';

/// The actual core fix for "the video system is broken": resolves a
/// direct **audio-only** stream instead of requiring a combined
/// video+audio (muxed) one. Muxed streams are what the old video player
/// needed and are the specific thing that's been getting harder to find
/// (YouTube has been phasing progressive/muxed formats out industry-wide
/// in favor of separate adaptive video/audio tracks) — audio-only tracks
/// don't have that problem and remain widely available across every
/// resolver here, which is why this succeeds far more often in practice
/// than the old muxed-video resolution ever did.
class AudioStreamResolver {
  AudioStreamResolver._();
  static final AudioStreamResolver instance = AudioStreamResolver._();

  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, _Entry> _recentlyResolved = {};
  static const Duration _ttl = Duration(minutes: 20);

  Future<String?> resolve(String videoId) async {
    final cached = _recentlyResolved[videoId];
    if (cached != null && DateTime.now().difference(cached.at) < _ttl) {
      return cached.url;
    }

    // Race all three server-side extractors at once, same pattern as the
    // muxed-video resolver — independent infrastructure, so one being
    // down doesn't block the others.
    final raced = await Future.wait([
      PipedService.instance.resolveAudioOnly(videoId).catchError((_) => null),
      InvidiousService.instance.resolveAudioOnly(videoId).catchError((_) => null),
      CobaltService.instance.resolveAudioOnly(videoId).catchError((_) => null),
    ]);

    for (final url in raced) {
      if (url != null && url.isNotEmpty) {
        _recentlyResolved[videoId] = _Entry(url, DateTime.now());
        debugPrint('[AudioStreamResolver] resolved $videoId via server-side extractor');
        return url;
      }
    }

    // Last resort: direct on-device extraction, audio-only. Still subject
    // to YouTube's PO-Token requirement on most clients, but androidVr
    // remains a confirmed-working exception for it (same finding that
    // already applies to the Quran audio-extraction path elsewhere in
    // this app).
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(
            videoId,
            ytClients: [
              YoutubeApiClient.androidVr,
              YoutubeApiClient.androidSdkless,
              YoutubeApiClient.ios,
            ],
          )
          .timeout(const Duration(seconds: 10));
      if (manifest.audioOnly.isNotEmpty) {
        // Deliberately not using the package's own "highest bitrate"
        // helper extension here — its name has been spelled two
        // different ways across different versions/docs of this library
        // ("withHighestBitrate" vs "withHigestBitrate"), so picking
        // manually avoids betting on which one this pinned version
        // actually has.
        final sorted = [...manifest.audioOnly]
          ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
        final best = sorted.first;
        debugPrint('[AudioStreamResolver] resolved $videoId via direct extraction');
        _recentlyResolved[videoId] = _Entry(best.url.toString(), DateTime.now());
        return best.url.toString();
      }
    } catch (e) {
      debugPrint('[AudioStreamResolver] direct extraction failed for $videoId: $e');
    }

    return null;
  }
}

class _Entry {
  const _Entry(this.url, this.at);
  final String url;
  final DateTime at;
}
