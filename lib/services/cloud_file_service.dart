import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Directory, File;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads large religious texts/audio (PDFs, MP3s, plain text) from the
/// project's own GitHub repository **once**, then serves them from local
/// storage forever after — these files are deliberately kept out of the
/// app bundle itself (they'd make the APK far larger for content most
/// people only open occasionally), living instead as plain files in the
/// repo under a path that isn't declared in pubspec.yaml's `assets:` list,
/// so Flutter never packages them into the app at build time.
///
/// IMPORTANT: This assumes the repo is `ILYA-Web2/Zad-Al-Saireen` on the
/// `main` branch (matching the GitHub Actions logs seen so far). If that's
/// wrong, update [_repoRawBase] — everything else works unchanged.
class CloudFileService {
  CloudFileService._();
  static final CloudFileService instance = CloudFileService._();

  static const String _repoRawBase =
      'https://raw.githubusercontent.com/ILYA-Web2/Zad-Al-Saireen/main/';

  final http.Client _client = http.Client();
  Directory? _cacheDir;

  // On web there is no persistent filesystem to cache into (dart:io's
  // File/Directory don't exist there at all) — this in-memory map is the
  // web fallback: content re-fetches once per page session instead of
  // persisting forever like the native disk cache does, which is an
  // honest, acceptable trade-off rather than crashing outright the way
  // touching File/Directory on web would.
  final Map<String, Uint8List> _memoryCache = {};

  Future<Directory> _ensureDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/cloud_content_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  String _keyFor(String repoPath) => sha1.convert(utf8.encode(repoPath)).toString();

  /// [repoPath] is relative to the repo root, e.g.
  /// `cloud_content/duas/pdf/sahifa_sajjadiyya.pdf`.
  String buildUrl(String repoPath) => '$_repoRawBase$repoPath';

  /// Returns the local cached path if already downloaded, else null.
  /// Always null on web (see [_memoryCache] above) — callers needing raw
  /// bytes on every platform, including web, should use [downloadBytes]
  /// instead of this path-based API.
  Future<String?> localPathIfCached(String repoPath) async {
    if (kIsWeb) return null;
    try {
      final dir = await _ensureDir();
      final ext = repoPath.contains('.') ? repoPath.split('.').last : 'bin';
      final file = File('${dir.path}/${_keyFor(repoPath)}.$ext');
      return await file.exists() ? file.path : null;
    } catch (_) {
      return null;
    }
  }

  /// Returns the raw bytes of [repoPath] — cached to disk on native
  /// platforms (persists across app restarts) or held in memory for this
  /// page session on web (see [_memoryCache]). This is the one API that
  /// works identically, and safely, on every platform; prefer it over
  /// [download] for any new caller.
  Future<Uint8List> downloadBytes(
    String repoPath, {
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      final cached = _memoryCache[repoPath];
      if (cached != null) {
        onProgress?.call(1.0);
        return cached;
      }
      final response = await _client
          .get(Uri.parse(buildUrl(repoPath)))
          .timeout(const Duration(minutes: 2));
      if (response.statusCode != 200) {
        throw CloudFileException('تعذّر تحميل الملف (${response.statusCode})');
      }
      onProgress?.call(1.0);
      _memoryCache[repoPath] = response.bodyBytes;
      return response.bodyBytes;
    }

    final path = await download(repoPath, onProgress: onProgress);
    return File(path).readAsBytes();
  }

  /// Downloads [repoPath] if not already cached, reporting progress via
  /// [onProgress] (0.0–1.0), and returns the local file path. Safe to call
  /// repeatedly — returns immediately if already cached.
  ///
  /// Native platforms only — this returns a real filesystem path, which
  /// doesn't exist as a concept on web. Web callers should use
  /// [downloadBytes] instead, which works everywhere.
  Future<String> download(
    String repoPath, {
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      throw CloudFileException(
          'هذه الطريقة تحتاج نظام ملفات حقيقي غير متوفر بالمتصفح — استخدم downloadBytes بدلاً منها.');
    }
    final cached = await localPathIfCached(repoPath);
    if (cached != null) {
      onProgress?.call(1.0);
      return cached;
    }

    final dir = await _ensureDir();
    final ext = repoPath.contains('.') ? repoPath.split('.').last : 'bin';
    final file = File('${dir.path}/${_keyFor(repoPath)}.$ext');
    final tempFile = File('${file.path}.part');

    final request = http.Request('GET', Uri.parse(buildUrl(repoPath)));
    final response = await _client.send(request).timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
      throw CloudFileException('تعذّر تحميل الملف (${response.statusCode})');
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = tempFile.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress?.call(received / total);
    }
    await sink.close();
    await tempFile.rename(file.path);
    return file.path;
  }

  /// Reads a cached (or freshly-downloaded) text file as a UTF-8 string —
  /// for the plain-text duas (like Dua Kumayl) rather than PDFs. Works on
  /// every platform, including web, since it goes through [downloadBytes].
  Future<String> downloadText(String repoPath) async {
    final bytes = await downloadBytes(repoPath);
    return utf8.decode(bytes);
  }

  void dispose() => _client.close();
}

class CloudFileException implements Exception {
  CloudFileException(this.message);
  final String message;
  @override
  String toString() => message;
}
