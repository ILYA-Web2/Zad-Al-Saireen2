import 'dart:math' as math;

class PrayerTimesEntity {
  const PrayerTimesEntity({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.midnight,
    required this.date,
    required this.hijriDay,
    required this.hijriMonth,
    required this.hijriMonthAr,
    required this.hijriYear,
    required this.cityName,
    this.latitude,
    this.longitude,
  });

  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String midnight;
  final DateTime date;
  final String hijriDay;
  final String hijriMonth;
  final String hijriMonthAr;
  final String hijriYear;
  final String cityName;
  // Aladhan's response already includes the resolved coordinates it
  // actually used (`data.meta.latitude/longitude`) for both the
  // GPS-coordinates and the by-city endpoints — so this is real data,
  // not an approximation, and works identically whether the user picked
  // GPS or typed a city name. Used to compute a real Qibla bearing
  // instead of the placeholder 0.0 that shipped before.
  final double? latitude;
  final double? longitude;

  /// Great-circle initial bearing from here to the Kaaba (Mecca), in
  /// degrees clockwise from true north — the actual "direction" a
  /// magnetic compass needs to be rotated to for the Qibla arrow to be
  /// correct. Returns null (rather than a misleading 0°) when no real
  /// coordinates are available yet.
  double? get qiblaBearing {
    if (latitude == null || longitude == null) return null;
    const kaabaLat = 21.4225;
    const kaabaLon = 39.8262;
    final lat1 = latitude! * (math.pi / 180);
    final lat2 = kaabaLat * (math.pi / 180);
    final deltaLon = (kaabaLon - longitude!) * (math.pi / 180);

    final y = math.sin(deltaLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);
    final bearingRad = math.atan2(y, x);
    final bearingDeg = bearingRad * (180 / math.pi);
    return (bearingDeg + 360) % 360;
  }

  String get hijriDateFull => '$hijriDay $hijriMonthAr $hijriYear هـ';

  List<PrayerEntry> get allPrayers => [
        PrayerEntry('الفجر', fajr, PrayerIcon.fajr),
        PrayerEntry('الشروق', sunrise, PrayerIcon.sunrise),
        PrayerEntry('الظهر', dhuhr, PrayerIcon.dhuhr),
        PrayerEntry('العصر', asr, PrayerIcon.asr),
        PrayerEntry('المغرب', maghrib, PrayerIcon.maghrib),
        PrayerEntry('العشاء', isha, PrayerIcon.isha),
        PrayerEntry('منتصف الليل', midnight, PrayerIcon.midnight),
      ];

  /// Returns the next upcoming prayer from [now].
  PrayerEntry? nextPrayer(DateTime now) {
    for (final prayer in allPrayers) {
      if (prayer.name == 'الشروق') continue;
      final parts = prayer.time.split(':');
      if (parts.length < 2) continue;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final prayerDt =
          DateTime(now.year, now.month, now.day, h, m);
      if (prayerDt.isAfter(now)) return prayer;
    }
    return null;
  }

  Duration? timeUntilNextPrayer(DateTime now) {
    final next = nextPrayer(now);
    if (next == null) return null;
    final parts = next.time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final prayerDt = DateTime(now.year, now.month, now.day, h, m);
    return prayerDt.difference(now);
  }
}

class PrayerEntry {
  const PrayerEntry(this.name, this.time, this.icon);
  final String name;
  final String time;
  final PrayerIcon icon;
}

enum PrayerIcon { fajr, sunrise, dhuhr, asr, maghrib, isha, midnight }
