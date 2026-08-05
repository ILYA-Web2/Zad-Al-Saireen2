import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

/// Talks to Firebase Realtime Database through its plain REST interface
/// (`GET/PUT https://<db>.firebaseio.com/path.json`) instead of the native
/// `firebase_core`/`firebase_database` SDKs.
///
/// This is a deliberate choice: the native SDKs need `google-services.json`
/// plus Gradle plugin changes on the Android side, which can't be verified
/// here without a compiler — getting that wrong risks the exact "black
/// screen after building" class of bug this app has already hit once. The
/// REST API gives the same read/write capability for a simple cache with
/// zero native dependencies and zero Gradle changes, so it can't affect
/// the Android build at all.
class FirebaseRtdbService {
  FirebaseRtdbService._();
  static final FirebaseRtdbService instance = FirebaseRtdbService._();

  final http.Client _client = http.Client();

  /// Firebase RTDB keys can't contain `. # $ [ ]` or `/`, so arbitrary
  /// search queries are hashed into a safe key.
  String _safeKey(String raw) => sha1.convert(utf8.encode(raw)).toString();

  Future<Map<String, dynamic>?> get(String node, String rawKey) async {
    try {
      final uri = Uri.parse(
          '${AppConstants.firebaseDatabaseUrl}/$node/${_safeKey(rawKey)}.json');
      final response = await _client.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      if (response.body == 'null') return null;
      final decoded = json.decode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Best-effort write — never throws, since this is a cache warm-up, not
  /// something playback or search correctness depends on.
  Future<void> put(String node, String rawKey, Map<String, dynamic> value) async {
    try {
      final uri = Uri.parse(
          '${AppConstants.firebaseDatabaseUrl}/$node/${_safeKey(rawKey)}.json');
      await _client
          .put(uri, body: json.encode(value))
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Best-effort only.
    }
  }
}
