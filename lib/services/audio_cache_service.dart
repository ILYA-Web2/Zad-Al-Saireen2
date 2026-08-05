import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Caches freely-licensed audio (Quran Ayah recitations, Archive.org public
/// domain tracks) to local storage the first time it is played, so it can
/// be replayed from the History tab with **zero internet use** afterwards.
///
/// YouTube-sourced audio is the one exception to "cache on first play":
/// it only ever enters this cache via [adoptExistingFile], called from the
/// player screen's explicit "Download" button — never silently on play —
/// since re-hosting YouTube media outside a user-initiated download isn't
/// appropriate.
class AudioCacheService {
  AudioCacheService._();
  static final AudioCacheService instance = AudioCacheService._();

  Directory? _cacheDir;

  Future<Directory> _ensureDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/audio_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  String _keyFor(String url) => sha1.convert(utf8.encode(url)).toString();

  /// Returns a local file path if [url] was already cached. Never throws —
  /// a failure here (e.g. a transient path_provider/filesystem hiccup)
  /// must fall through to streaming from the network instead of failing
  /// playback outright, since this runs before any network call is even
  /// attempted.
  Future<String?> localPathIfCached(String url) async {
    try {
      final dir = await _ensureDir();
      final file = File('${dir.path}/${_keyFor(url)}.mp3');
      return await file.exists() ? file.path : null;
    } catch (_) {
      return null;
    }
  }

  /// Returns a playable path for [url]: the cached local file if present,
  /// otherwise the original remote [url] unchanged (never blocks playback
  /// waiting for a download — caching happens in the background via
  /// [cacheInBackground]).
  Future<String> playbackSource(String url) async {
    final cached = await localPathIfCached(url);
    return cached ?? url;
  }

  /// True if [url] is already fully cached locally (safe to play with
  /// zero network use).
  Future<bool> isCached(String url) async => (await localPathIfCached(url)) != null;

  /// Size in bytes of the cached file for [url], or 0 if not cached.
  Future<int> fileSizeFor(String url) async {
    final path = await localPathIfCached(url);
    if (path == null) return 0;
    try {
      return await File(path).length();
    } catch (_) {
      return 0;
    }
  }

  /// Explicit, user-initiated "download for offline" — unlike
  /// [cacheInBackground] this is awaited and reports real progress, for a
  /// visible download button (e.g. a Dua's audio) rather than the silent
  /// after-first-play caching used elsewhere.
  Future<void> downloadForOffline(String url, {void Function(double progress)? onProgress}) async {
    final dir = await _ensureDir();
    final file = File('${dir.path}/${_keyFor(url)}.mp3');
    if (await file.exists()) {
      onProgress?.call(1.0);
      return;
    }
    final tmp = File('${file.path}.part');

    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send().timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('تعذّر تحميل الملف الصوتي (${response.statusCode})');
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = tmp.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress?.call(received / total);
    }
    await sink.close();
    await tmp.rename(file.path);
  }

  /// Downloads [url] into the local cache without blocking the caller.
  /// Safe to call repeatedly — skips work if already cached or already
  /// mid-download. Any network failure is swallowed silently since this is
  /// a best-effort background optimization, not a required step.
  void cacheInBackground(String url) {
    () async {
      try {
        final dir = await _ensureDir();
        final file = File('${dir.path}/${_keyFor(url)}.mp3');
        if (await file.exists()) return;
        final tmp = File('${file.path}.part');
        if (await tmp.exists()) return; // already mid-download

        // A single http.get() with one fixed short timeout used to fail
        // silently on anything but a short file — a full, long Surah
        // recitation can easily be 50-100+ MB, which routinely couldn't
        // finish inside 30 seconds on an ordinary connection, so caching
        // quietly never completed. Streaming it in chunks with only a
        // per-connection-open timeout (not a total-download timeout)
        // lets it actually finish regardless of file size or speed.
        final request = http.Request('GET', Uri.parse(url));
        final response = await request.send().timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) return;

        final sink = tmp.openWrite();
        await for (final chunk in response.stream) {
          sink.add(chunk);
        }
        await sink.close();
        await tmp.rename(file.path);
      } catch (_) {
        // Best-effort only — the user already heard it once over the
        // network; failing to cache just means next time re-streams.
      }
    }();
  }

  /// Registers a file that was already downloaded through some other,
  /// explicit flow (e.g. the player screen's "Download" button) under
  /// [key], so future [localPathIfCached]/[playbackSource] lookups for that
  /// same key find it — without this being a second, separate download.
  /// This is how YouTube-sourced audio becomes offline-capable: only via
  /// the user's own explicit download tap, consistent with the policy
  /// above, never a silent background fetch.
  Future<void> adoptExistingFile(String key, String existingPath) async {
    try {
      final dir = await _ensureDir();
      final dest = File('${dir.path}/${_keyFor(key)}.mp3');
      if (await dest.exists()) return;
      await File(existingPath).copy(dest.path);
    } catch (_) {
      // Best-effort — the file the user downloaded is still directly
      // playable from its own path even if this registration fails.
    }
  }

  Future<int> cacheSizeBytes() async {
    try {
      final dir = await _ensureDir();
      int total = 0;
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File) total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearCache() async {
    try {
      final dir = await _ensureDir();
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Best-effort.
    }
  }
}
