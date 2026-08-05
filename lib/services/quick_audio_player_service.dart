import 'package:just_audio/just_audio.dart';
import 'audio_cache_service.dart';
import 'audio_mutex.dart';

/// A single shared, lightweight [AudioPlayer] for previewing Archive.org
/// search results inline in the search results grid. Kept intentionally
/// separate from [QuranAudioHandler] — this is a foreground-only preview
/// player (no lock-screen/notification controls), matching its much
/// shorter-lived use case.
class QuickAudioPlayerService {
  QuickAudioPlayerService._() {
    AudioMutex.instance.register(_mutexOwnerId, () => player.pause());
  }
  static final QuickAudioPlayerService instance = QuickAudioPlayerService._();

  static const String _mutexOwnerId = 'quick_player';

  final AudioPlayer player = AudioPlayer();
  String? _currentUrl;

  String? get currentUrl => _currentUrl;
  Stream<bool> get playingStream => player.playingStream;
  Stream<Duration> get positionStream => player.positionStream;

  Future<void> playOrToggle(String url) async {
    if (_currentUrl == url) {
      if (player.playing) {
        await player.pause();
      } else {
        await AudioMutex.instance.claim(_mutexOwnerId);
        await player.play();
      }
      return;
    }
    final previousUrl = _currentUrl;
    _currentUrl = url;
    try {
      final source = await AudioCacheService.instance.playbackSource(url);
      final isLocal = source != url;
      if (isLocal) {
        await player.setFilePath(source);
      } else {
        await player.setUrl(source);
        AudioCacheService.instance.cacheInBackground(url);
      }
      await AudioMutex.instance.claim(_mutexOwnerId);
      await player.play();
    } catch (e) {
      // A dead/expired stream link (common with these sources) must not
      // leave `_currentUrl` pointing at a URL that never actually loaded —
      // otherwise the next tap on the same item thinks it's already
      // loaded and just calls play() on an empty player instead of
      // retrying the load.
      _currentUrl = previousUrl;
      rethrow;
    }
  }

  Future<void> stop() async {
    AudioMutex.instance.release(_mutexOwnerId);
    await player.stop();
    _currentUrl = null;
  }
}
