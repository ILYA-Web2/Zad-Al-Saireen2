import '../../domain/entities/prayer_times_entity.dart';

class PrayerTimesModel extends PrayerTimesEntity {
  const PrayerTimesModel({
    required super.fajr,
    required super.sunrise,
    required super.dhuhr,
    required super.asr,
    required super.maghrib,
    required super.isha,
    required super.midnight,
    required super.date,
    required super.hijriDay,
    required super.hijriMonth,
    required super.hijriMonthAr,
    required super.hijriYear,
    required super.cityName,
    super.latitude,
    super.longitude,
  });

  factory PrayerTimesModel.fromAladhanJson(
      Map<String, dynamic> json, String cityName) {
    final timings = json['timings'] as Map<String, dynamic>? ?? {};
    final dateBlock = json['date'] as Map<String, dynamic>? ?? {};
    final hijriBlock =
        dateBlock['hijri'] as Map<String, dynamic>? ?? {};
    final hijriMonthBlock =
        hijriBlock['month'] as Map<String, dynamic>? ?? {};
    final gregorianBlock =
        dateBlock['gregorian'] as Map<String, dynamic>? ?? {};
    // Aladhan includes the coordinates it actually resolved and used for
    // this calculation under `meta` — present on both /timings (GPS) and
    // /timingsByCity, so this is real, always-available data rather than
    // something that only works for one of the two lookup paths.
    final metaBlock = json['meta'] as Map<String, dynamic>? ?? {};

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(
          gregorianBlock['date']?.toString().replaceAll('-', '-') ??
              DateTime.now().toIso8601String());
    } catch (_) {
      parsedDate = DateTime.now();
    }

    // Strip timezone offsets from time strings (e.g. "05:23 (+03)")
    String cleanTime(String? raw) {
      if (raw == null) return '--:--';
      return raw.split(' ').first.trim();
    }

    return PrayerTimesModel(
      fajr: cleanTime(timings['Fajr']?.toString()),
      sunrise: cleanTime(timings['Sunrise']?.toString()),
      dhuhr: cleanTime(timings['Dhuhr']?.toString()),
      asr: cleanTime(timings['Asr']?.toString()),
      maghrib: cleanTime(timings['Maghrib']?.toString()),
      isha: cleanTime(timings['Isha']?.toString()),
      midnight: cleanTime(timings['Midnight']?.toString()),
      date: parsedDate,
      hijriDay: hijriBlock['day']?.toString() ?? '',
      hijriMonth: hijriBlock['month']?.toString() ?? '',
      hijriMonthAr: hijriMonthBlock['ar']?.toString() ?? '',
      hijriYear: hijriBlock['year']?.toString() ?? '',
      cityName: cityName,
      latitude: (metaBlock['latitude'] as num?)?.toDouble(),
      longitude: (metaBlock['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toCache() => {
        'fajr': fajr,
        'sunrise': sunrise,
        'dhuhr': dhuhr,
        'asr': asr,
        'maghrib': maghrib,
        'isha': isha,
        'midnight': midnight,
        'date': date.toIso8601String(),
        'hijriDay': hijriDay,
        'hijriMonth': hijriMonth,
        'hijriMonthAr': hijriMonthAr,
        'hijriYear': hijriYear,
        'cityName': cityName,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory PrayerTimesModel.fromCache(Map<String, dynamic> map) {
    return PrayerTimesModel(
      fajr: map['fajr']?.toString() ?? '--:--',
      sunrise: map['sunrise']?.toString() ?? '--:--',
      dhuhr: map['dhuhr']?.toString() ?? '--:--',
      asr: map['asr']?.toString() ?? '--:--',
      maghrib: map['maghrib']?.toString() ?? '--:--',
      isha: map['isha']?.toString() ?? '--:--',
      midnight: map['midnight']?.toString() ?? '--:--',
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      hijriDay: map['hijriDay']?.toString() ?? '',
      hijriMonth: map['hijriMonth']?.toString() ?? '',
      hijriMonthAr: map['hijriMonthAr']?.toString() ?? '',
      hijriYear: map['hijriYear']?.toString() ?? '',
      cityName: map['cityName']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }
}
