import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../services/hive_service.dart';
import '../../domain/entities/surah_entity.dart';
import '../../domain/repositories/quran_repository.dart';
import '../models/surah_model.dart';

class QuranRepositoryImpl implements QuranRepository {
  QuranRepositoryImpl(this._client);
  final http.Client _client;

  @override
  Future<List<SurahEntity>> getAllSurahs() async {
    final uri = Uri.parse('${AppConstants.quranApiBaseUrl}/surah');
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw QuranApiException('فشل تحميل قائمة السور');
    }

    final Map<String, dynamic> json = jsonDecode(response.body);
    final data = json['data'] as List<dynamic>? ?? [];

    return data
        .map((e) => SurahModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<AyahEntity>> getSurahAyahs(int surahNumber) async {
    final hive = HiveService.instance;
    final cached = hive.getCachedSurah(surahNumber);

    if (cached != null) {
      final ayahs = (cached['ayahs'] as List<dynamic>? ?? [])
          .map((e) => AyahModel.fromJson(
              Map<String, dynamic>.from(e as Map), surahNumber))
          .toList();
      if (ayahs.isNotEmpty) return ayahs;
    }

    final uri = Uri.parse(
        '${AppConstants.quranApiBaseUrl}/surah/$surahNumber/quran-uthmani');
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw QuranApiException('فشل تحميل السورة رقم $surahNumber');
    }

    final Map<String, dynamic> json = jsonDecode(response.body);
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final ayahsJson = data['ayahs'] as List<dynamic>? ?? [];

    hive.cacheSurahData(surahNumber, {'ayahs': ayahsJson});

    return ayahsJson
        .map((e) =>
            AyahModel.fromJson(e as Map<String, dynamic>, surahNumber))
        .toList();
  }

  @override
  Future<List<AyahEntity>> searchAyahs(String query) async {
    final normalizedQuery = _removeDiacritics(query.trim());
    if (normalizedQuery.isEmpty) return [];

    final uri = Uri.parse(
        '${AppConstants.quranApiBaseUrl}/search/${Uri.encodeComponent(normalizedQuery)}/all/ar');
    final response = await _client.get(uri);

    if (response.statusCode != 200) return [];

    final Map<String, dynamic> json = jsonDecode(response.body);
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) return [];

    final matches = data['matches'] as List<dynamic>? ?? [];

    return matches.map((m) {
      final map = m as Map<String, dynamic>;
      final surah = map['surah'] as Map<String, dynamic>? ?? {};
      return AyahModel.fromJson(map, surah['number'] as int? ?? 0);
    }).toList();
  }

  String _removeDiacritics(String text) {
    const diacritics = [
      '\u064B', '\u064C', '\u064D', '\u064E', '\u064F',
      '\u0650', '\u0651', '\u0652', '\u0653', '\u0654',
      '\u0655', '\u0656', '\u0657', '\u0658', '\u0670',
    ];
    String result = text;
    for (final d in diacritics) {
      result = result.replaceAll(d, '');
    }
    return result;
  }
}

class QuranApiException implements Exception {
  QuranApiException(this.message);
  final String message;
  @override
  String toString() => 'QuranApiException: $message';
}
