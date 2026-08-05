import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../core/constants/app_constants.dart';
import 'audio_cache_service.dart';
import 'audio_mutex.dart';
import 'quran_reciter_service.dart';

/// Background-capable Quran playback, rebuilt from scratch on a much
/// simpler and inherently more robust foundation: each Surah is ONE
/// continuous audio file from quranicaudio.com (the same CDN quran.com
/// itself uses), not hundreds of individually-fetched per-Ayah files
/// stitched together at runtime.
///
/// The earlier per-Ayah design needed to transition the player from one
/// track to the next up to 286 times per Surah, and that transition logic
/// — however carefully guarded — was where the repeated "stops on the
/// second Ayah" crash kept originating. Removing the transitions removes
/// the entire bug class: there is now exactly one `setUrl` + `play()` per
/// Surah, and normal seek/speed controls work on that single file exactly
/// like any other audio player.
class QuranAudioHandler extends BaseAudioHandler with SeekHandler {
  static const String _mutexOwnerId = 'quran';

  QuranAudioHandler() {
    AudioMutex.instance.register(_mutexOwnerId, () => _player.pause());

    _player.playingStream.listen((_) => _broadcastState());
    _player.positionStream.listen((_) => _broadcastState());
    _player.processingStateStream.listen((_) => _broadcastState());

    _player.playbackEventStream.listen((_) {}, onError: (e, st) {
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.error,
      ));
    });
  }

  final AudioPlayer _player = AudioPlayer();

  int? _currentSurahNumber;
  ReciterInfo? _currentReciter;
  String? _currentTrackId;

  int? get currentSurahNumber => _currentSurahNumber;
  ReciterInfo? get currentReciter => _currentReciter;
  String? get currentTrackId => _currentTrackId;

  bool _isLoadingSurah = false;

  /// Loads and plays [surahNumber] recited by [reciter] as one continuous
  /// file. Cached locally after the first listen (via [AudioCacheService])
  /// so replaying the same Surah/reciter combination needs zero network.
  Future<void> loadSurah({
    required int surahNumber,
    required String surahNameArabic,
    required ReciterInfo reciter,
  }) async {
    _currentSurahNumber = surahNumber;
    _currentReciter = reciter;
    _currentTrackId = null;
    await _loadUrl(
      url: reciter.surahUrl(surahNumber),
      title: surahNameArabic,
      artist: reciter.arabicName,
      logLabel: 'Surah $surahNumber (${reciter.arabicName})',
    );
  }

  /// The general-purpose counterpart to [loadSurah] — plays any resolved
  /// audio URL (search results, lamentations, etc.) through the exact same
  /// engine: same concurrency guard, same stop-before-load safety, same
  /// cache-first lookup, same timeout/error handling. This is what makes
  /// a dedicated, always-reliable audio player possible in the first
  /// place — every one of those hard-won fixes above now covers *all*
  /// playback in the app, not just Quran.
  Future<void> loadTrack({
    required String id,
    required String title,
    required String artist,
    required String streamUrl,
  }) async {
    _currentSurahNumber = null;
    _currentReciter = null;
    _currentTrackId = id;
    await _loadUrl(
      url: streamUrl,
      title: title,
      artist: artist,
      logLabel: 'track $id ($title)',
    );
  }

  Future<void> _loadUrl({
    required String url,
    required String title,
    required String artist,
    required String logLabel,
  }) async {
    // Switching tracks while one is already playing/loading used to call
    // setUrl()/setFilePath() on the player while it was still actively
    // playing the previous one, with no guard against a second tap firing
    // before the first load finished — either of which could leave the
    // underlying player in an inconsistent state and crash. Both are
    // closed off now: overlapping calls are dropped, and the player is
    // always fully stopped before a new source is loaded into it.
    if (_isLoadingSurah) return;
    _isLoadingSurah = true;

    try {
      mediaItem.add(MediaItem(
        id: url,
        album: AppConstants.appName,
        title: title,
        artist: artist,
      ));

      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.loading,
      ));

      try {
        await _player.stop();
      } catch (_) {
        // Nothing was loaded yet (first play ever) — fine to ignore.
      }

      try {
        final localPath = await AudioCacheService.instance.localPathIfCached(url);
        if (localPath != null) {
          await _player.setFilePath(localPath).timeout(const Duration(seconds: 15));
        } else {
          await _player.setUrl(url).timeout(const Duration(seconds: 20));
          AudioCacheService.instance.cacheInBackground(url);
        }
      } catch (e, st) {
        debugPrint('[QuranAudioHandler] load failed for $logLabel url=$url: $e\n$st');
        playbackState.add(playbackState.value.copyWith(
          playing: false,
          processingState: AudioProcessingState.error,
        ));
        rethrow;
      }
      await play();
    } finally {
      _isLoadingSurah = false;
    }
  }

  @override
  Future<void> play() async {
    await AudioMutex.instance.claim(_mutexOwnerId);
    await _player.play();
  }

  @override
  Future<void> pause() {
    AudioMutex.instance.release(_mutexOwnerId);
    return _player.pause();
  }

  @override
  Future<void> stop() async {
    AudioMutex.instance.release(_mutexOwnerId);
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  /// Repeats the current Surah indefinitely when [enabled] — useful for
  /// memorization/repetition, per the request. just_audio's own
  /// `LoopMode.one` handles the actual looping internally (no manual
  /// "detect completion and restart" logic needed, which would reintroduce
  /// exactly the kind of player-mutating-from-a-callback risk that caused
  /// the original crash).
  Future<void> setRepeatEnabled(bool enabled) =>
      _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
  bool get isRepeatEnabled => _player.loopMode == LoopMode.one;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  Future<void> dispose() async {
    AudioMutex.instance.unregister(_mutexOwnerId);
    await _player.dispose();
  }
}
