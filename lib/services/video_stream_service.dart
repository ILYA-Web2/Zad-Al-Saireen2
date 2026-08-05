import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'piped_service.dart';
import 'invidious_service.dart';
import 'cobalt_service.dart';
import 'video_quality_option.dart';

class VideoStreamInfo {
  const VideoStreamInfo({
    required this.qualities,
    required this.durationSeconds,
  });
  final List<VideoQualityOption> qualities;
  final int durationSeconds;

  VideoQualityOption get best => qualities.first;
}

/// Resolves a YouTube video to real, direct, muxed stream URLs at every
/// available quality. Resolved URLs are signed
/// and expire after a few hours, so this always resolves fresh rather
/// than caching the URL itself long-term — but a short in-memory cache of
/// *already-resolved* results is kept for a few minutes so a mid-playback
/// network blip that triggers a reload doesn't have to re-run the entire
/// direct-extraction → Piped → Invidious chain from scratch every time.
class VideoStreamService {
  VideoStreamService._();
  static final VideoStreamService instance = VideoStreamService._();

  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, _ResolvedEntry> _recentlyResolved = {};
  static const Duration _resolvedTtl = Duration(minutes: 5);

  Future<VideoStreamInfo> resolveQualities(String videoId) async {
    final cached = _recentlyResolved[videoId];
    if (cached != null && DateTime.now().difference(cached.resolvedAt) < _resolvedTtl) {
      debugPrint('[VideoStreamService] reusing recently-resolved streams for $videoId');
      return cached.info;
    }

    // Piped, Invidious, and Cobalt all extract server-side, on
    // infrastructure dedicated to fighting YouTube's current PO-Token/
    // nsig requirements full-time — the same fight even yt-dlp (by far
    // the most resourced extractor that exists) is currently struggling
    // with client-side. Racing all three at once — three independent
    // sets of operators/infrastructure — is more likely to have at least
    // one succeed than relying on any single one.
    final raced = await Future.wait([
      PipedService.instance.resolveVideoStreams(videoId).catchError((_) => <VideoQualityOption>[]),
      InvidiousService.instance.resolveVideoStreams(videoId).catchError((_) => <VideoQualityOption>[]),
      CobaltService.instance.resolveVideoStreams(videoId).catchError((_) => <VideoQualityOption>[]),
    ]);

    final pipedQualities = raced[0];
    if (pipedQualities.isNotEmpty) {
      debugPrint('[VideoStreamService] resolved $videoId via Piped');
      final info = VideoStreamInfo(qualities: pipedQualities, durationSeconds: 0);
      _recentlyResolved[videoId] = _ResolvedEntry(info, DateTime.now());
      return info;
    }

    final invidiousQualities = raced[1];
    if (invidiousQualities.isNotEmpty) {
      debugPrint('[VideoStreamService] resolved $videoId via Invidious');
      final info = VideoStreamInfo(qualities: invidiousQualities, durationSeconds: 0);
      _recentlyResolved[videoId] = _ResolvedEntry(info, DateTime.now());
      return info;
    }

    final cobaltQualities = raced[2];
    if (cobaltQualities.isNotEmpty) {
      debugPrint('[VideoStreamService] resolved $videoId via Cobalt');
      final info = VideoStreamInfo(qualities: cobaltQualities, durationSeconds: 0);
      _recentlyResolved[videoId] = _ResolvedEntry(info, DateTime.now());
      return info;
    }

    // Last resort: direct on-device extraction. Real as of this writing,
    // but genuinely fragile — YouTube increasingly requires a PO Token
    // this library cannot generate, which can make every stream 403
    // regardless of network quality or client spoofing.
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(
            videoId,
            ytClients: [
              YoutubeApiClient.androidSdkless,
              YoutubeApiClient.ios,
              YoutubeApiClient.androidVr,
            ],
          )
          .timeout(const Duration(seconds: 10));
      if (manifest.muxed.isNotEmpty) {
        final sorted = [...manifest.muxed]
          ..sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));

        int durationSeconds = 0;
        try {
          final video = await _yt.videos.get(videoId).timeout(const Duration(seconds: 6));
          durationSeconds = video.duration?.inSeconds ?? 0;
        } catch (_) {
          // Cosmetic only.
        }

        debugPrint('[VideoStreamService] resolved $videoId via direct extraction '
            '(${sorted.length} qualities)');
        final info = VideoStreamInfo(
          qualities: sorted
              .map((s) => VideoQualityOption(
                    label: '${s.videoResolution.height}p',
                    url: s.url.toString(),
                  ))
              .toList(),
          durationSeconds: durationSeconds,
        );
        _recentlyResolved[videoId] = _ResolvedEntry(info, DateTime.now());
        return info;
      }
    } catch (e) {
      debugPrint('[VideoStreamService] direct extraction failed for $videoId: $e');
    }

    throw VideoStreamException('تعذّر تجهيز الفيديو — حاول لاحقاً');
  }

  void dispose() => _yt.close();
}

class _ResolvedEntry {
  _ResolvedEntry(this.info, this.resolvedAt);
  final VideoStreamInfo info;
  final DateTime resolvedAt;
}

class VideoStreamException implements Exception {
  VideoStreamException(this.message);
  final String message;
  @override
  String toString() => message;
}
