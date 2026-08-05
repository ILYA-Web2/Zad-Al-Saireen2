import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/hive_service.dart';

/// A reciter with a full-Surah audio file per chapter (not split into
/// individual Ayah files) — either from the quranicaudio.com CDN, or (for
/// reciters more specific to the Hussaini/Iraqi community who aren't on
/// that CDN) a verified Archive.org item hosting the same one-file-per-Surah
/// layout.
class ReciterInfo {
  const ReciterInfo({
    required this.id,
    required this.name,
    required this.arabicName,
    this.relativePath = '',
    this.archiveIdentifier,
    this.fileExtension = 'mp3',
  });

  final int id;
  final String name;
  final String arabicName;

  /// quranicaudio.com path, e.g. "mishaari_raashid_al_3afaasee/".
  final String relativePath;

  /// Archive.org item identifier, when this reciter's Surahs come from a
  /// verified Archive.org upload instead (e.g. Maytham al-Tammar, who
  /// isn't on quranicaudio.com's roster).
  final String? archiveIdentifier;

  /// Different Archive.org items store their per-Surah files in different
  /// formats — verified per reciter rather than assumed, since guessing
  /// wrong here means every single request 404s.
  final String fileExtension;

  String surahUrl(int surahNumber) {
    final padded = surahNumber.toString().padLeft(3, '0');
    if (archiveIdentifier != null) {
      return 'https://archive.org/download/$archiveIdentifier/$padded.$fileExtension';
    }
    return 'https://download.quranicaudio.com/quran/$relativePath$padded.mp3';
  }

  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'name': name,
        'arabic_name': arabicName,
        'relative_path': relativePath,
        'archive_identifier': archiveIdentifier,
        'file_extension': fileExtension,
      };

  factory ReciterInfo.fromJson(Map<String, dynamic> json) => ReciterInfo(
        id: json['id'] as int? ?? 0,
        name: json['name']?.toString() ?? '',
        arabicName: json['arabic_name']?.toString() ?? json['name']?.toString() ?? '',
        relativePath: json['relative_path']?.toString() ?? '',
        archiveIdentifier: json['archive_identifier']?.toString(),
        fileExtension: json['file_extension']?.toString() ?? 'mp3',
      );
}

/// Fetches the real, current reciter list from quranicaudio.com's public
/// API (no API key, no auth) — no hardcoded/guessed reciter data, since a
/// wrong guessed URL slug would silently 404 for that reciter's every
/// Surah. Falls back to the small set of reciters this app has separately
/// confirmed only if the live fetch itself fails (e.g. no connection on
/// first launch), so reciter selection never comes up completely empty.
class QuranReciterService {
  QuranReciterService._();
  static final QuranReciterService instance = QuranReciterService._();

  static const String _cacheKey = 'quran_reciters_cache';
  final http.Client _client = http.Client();

  static const List<ReciterInfo> _confirmedFallback = [
    ReciterInfo(
      id: 5,
      name: 'Mishari Rashid al-Afasy',
      arabicName: 'مشاري راشد العفاسي',
      relativePath: 'mishaari_raashid_al_3afaasee/',
    ),
    ReciterInfo(
      id: 1,
      name: 'AbdulBaset AbdulSamad',
      arabicName: 'عبد الباسط عبد الصمد',
      relativePath: 'abdulbaset_abdulsamad_mujawwad/',
    ),
    ReciterInfo(
      id: 4,
      name: "Sa'ud ash-Shuraym",
      arabicName: 'سعود الشريم',
      relativePath: 'sa3ood_al-shuraym/',
    ),
    ReciterInfo(
      id: 3,
      name: 'Abu Bakr al-Shatri',
      arabicName: 'أبو بكر الشاطري',
      relativePath: 'abu_bakr_ash-shaatree/',
    ),
  ];

  /// Reciters verified via other sources (e.g. Archive.org) that aren't on
  /// quranicaudio.com's own roster — always appended, not just used when
  /// the live fetch fails, so they're genuinely available rather than an
  /// emergency-only fallback.
  static const List<ReciterInfo> _verifiedExtras = [];

  Future<List<ReciterInfo>> getReciters() async {
    try {
      final response = await _client
          .get(Uri.parse('https://quranicaudio.com/api/qaris'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        final reciters = data
            .map((e) => ReciterInfo.fromJson(e as Map<String, dynamic>))
            .where((r) => r.relativePath.isNotEmpty && r.name.isNotEmpty)
            .toList();
        if (reciters.isNotEmpty) {
          final combined = [..._verifiedExtras, ...reciters];
          _cacheReciters(combined);
          return combined;
        }
      }
    } catch (_) {
      // Fall through to cache, then the confirmed fallback below.
    }

    final cached = _cachedReciters();
    if (cached != null && cached.isNotEmpty) return cached;

    return [..._verifiedExtras, ..._confirmedFallback];
  }

  void _cacheReciters(List<ReciterInfo> reciters) {
    try {
      HiveService.instance.setSetting(
        _cacheKey,
        json.encode(reciters.map((r) => r.toCacheJson()).toList()),
      );
    } catch (_) {
      // Best-effort — the live list is already in hand either way.
    }
  }

  List<ReciterInfo>? _cachedReciters() {
    try {
      final raw = HiveService.instance.getSetting<String>(_cacheKey);
      if (raw == null || raw.isEmpty) return null;
      final data = json.decode(raw) as List<dynamic>;
      return data
          .map((e) => ReciterInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
