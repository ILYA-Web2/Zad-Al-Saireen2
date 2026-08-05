import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../services/hive_service.dart';
import '../../domain/entities/prayer_times_entity.dart';
import '../models/prayer_times_model.dart';

// Method 7 = University of Islamic Sciences, Karachi (closest to Tehran standard)
// method=7 (Shia Ithna-Ashari, Leva Institute, Qum) is method=0 custom
// Aladhan standard Shia = method=7 (Tehran/MWL)
// school=1 (Hanafi Asr) vs 0 (Standard) — for Shia we use school=0
const int _shiaMethod = 7; // Tehran/Iran
const int _ashariSchool = 0;

class PrayerTimesRepositoryImpl {
  PrayerTimesRepositoryImpl(this._client);
  final http.Client _client;

  static const String _baseUrl = 'https://api.aladhan.com/v1';

  /// Fetch by GPS coordinates
  Future<PrayerTimesEntity> fetchByCoordinates({
    required double latitude,
    required double longitude,
    String cityName = '',
    DateTime? date,
  }) async {
    final d = date ?? DateTime.now();
    final cached = _loadCache(latitude, longitude, d);
    if (cached != null) return cached;

    final uri = Uri.parse(
      '$_baseUrl/timings/${d.millisecondsSinceEpoch ~/ 1000}'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&method=$_shiaMethod'
      '&school=$_ashariSchool'
      '&tune=0,0,0,0,0,0,0,0',
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw PrayerTimesException('فشل تحميل أوقات الصلاة (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final model = PrayerTimesModel.fromAladhanJson(data, cityName);
    _saveCache(latitude, longitude, d, model);
    return model;
  }

  /// Fetch by city name
  Future<PrayerTimesEntity> fetchByCity({
    required String city,
    required String country,
    DateTime? date,
  }) async {
    final d = date ?? DateTime.now();
    final uri = Uri.parse(
      '$_baseUrl/timingsByCity'
      '?city=${Uri.encodeComponent(city)}'
      '&country=${Uri.encodeComponent(country)}'
      '&method=$_shiaMethod'
      '&school=$_ashariSchool',
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw PrayerTimesException('المدينة غير موجودة');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return PrayerTimesModel.fromAladhanJson(data, city);
  }

  PrayerTimesModel? _loadCache(double lat, double lon, DateTime date) {
    try {
      final key = 'pt_${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}_${date.day}${date.month}${date.year}';
      final raw = HiveService.instance.getSetting<Map>(key);
      if (raw == null) return null;
      return PrayerTimesModel.fromCache(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(
      double lat, double lon, DateTime date, PrayerTimesModel model) async {
    final key = 'pt_${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}_${date.day}${date.month}${date.year}';
    await HiveService.instance.setSetting(key, model.toCache());
  }
}

class PrayerTimesException implements Exception {
  PrayerTimesException(this.message);
  final String message;
  @override
  String toString() => 'PrayerTimesException: $message';
}
