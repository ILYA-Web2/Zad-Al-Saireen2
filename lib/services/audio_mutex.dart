/// Ensures at most one audio source plays across the entire app at once.
/// Quran (background service), YouTube/Archive video-audio, and
/// dua/latmiya previews are three independent players built at different
/// points in this app's life — without a shared referee, starting one
/// doesn't stop another, and two recitations can end up overlapping.
///
/// Each player registers a "stop me" callback once, then calls
/// [claim] right before it actually starts audible playback. Whichever
/// source last called [claim] is the only one considered "active"; every
/// other registered source is told to pause immediately.
class AudioMutex {
  AudioMutex._();
  static final AudioMutex instance = AudioMutex._();

  final Map<String, Future<void> Function()> _pauseCallbacks = {};
  String? _activeOwner;

  /// Registers a source under a stable [ownerId] (e.g. "quran",
  /// "media_player", "quick_player") with a callback that pauses it.
  /// Safe to call repeatedly (e.g. once per screen instance) — later
  /// registrations for the same id just replace the callback.
  void register(String ownerId, Future<void> Function() pause) {
    _pauseCallbacks[ownerId] = pause;
  }

  void unregister(String ownerId) {
    _pauseCallbacks.remove(ownerId);
    if (_activeOwner == ownerId) _activeOwner = null;
  }

  /// Call this right before [ownerId] starts audible playback. Pauses
  /// every other registered source first.
  Future<void> claim(String ownerId) async {
    if (_activeOwner == ownerId) return;
    _activeOwner = ownerId;

    for (final entry in _pauseCallbacks.entries) {
      if (entry.key == ownerId) continue;
      try {
        await entry.value();
      } catch (_) {
        // A stuck pause on one source must never block the new source
        // from starting.
      }
    }
  }

  void release(String ownerId) {
    if (_activeOwner == ownerId) _activeOwner = null;
  }
}
