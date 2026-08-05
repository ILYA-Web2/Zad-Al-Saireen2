/// A small, dependency-free Gregorian ↔ Hijri date converter using the
/// well-established "Kuwaiti algorithm" (a.k.a. the tabular Islamic
/// calendar) — the same arithmetic method used by most simple Hijri
/// converters and historically by Microsoft's own HijriCalendar class.
///
/// Deliberately implemented as plain arithmetic rather than pulling in a
/// new package: it's pure `dart:core` integer math with no platform
/// channels or native code, so there's nothing here that can fail to
/// resolve or conflict with another dependency at build time.
///
/// Accuracy note: like every arithmetic Hijri calendar, this can differ
/// by about ±1 day from a real moon-sighting-based calendar — the actual
/// Hijri calendar used by religious authorities (e.g. the Najaf, Karbala
/// Hussein, and Karbala Abbas shrines' offices) is based on real
/// crescent-moon visibility, which this pure calculation cannot predict.
/// [calibrationOffsetDays] exists specifically to bridge that gap — see
/// its own doc comment.
class HijriDate {
  const HijriDate({required this.day, required this.month, required this.year});

  final int day;
  final int month;
  final int year;

  /// A user-adjustable number of days added to every conversion in this
  /// class, to realign the pure arithmetic calendar with an official
  /// moon-sighting announcement (from a marja' office or one of the holy
  /// shrines) once it's been published for a given month — which is
  /// the only way to get real Najaf-horizon accuracy, since there is no
  /// public live feed of those announcements this app can call. See the
  /// calibration control in the Islamic Calendar screen.
  ///
  /// +1 means "the real month started one day later than the pure
  /// calculation predicts" (so today's real Hijri date is one day
  /// earlier than the raw calculation); -1 means the opposite. Persisted
  /// via HiveService and loaded once at app start — see main.dart.
  static int calibrationOffsetDays = 0;

  static HijriDate fromGregorian(DateTime date) {
    final shifted = date.subtract(Duration(days: calibrationOffsetDays));
    final day = shifted.day;
    final month = shifted.month;
    final year = shifted.year;

    // Gregorian calendar date -> Julian Day Number
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    final jdn = day +
        ((153 * m + 2) ~/ 5) +
        365 * y +
        (y ~/ 4) -
        (y ~/ 100) +
        (y ~/ 400) -
        32045;

    // Julian Day Number -> Hijri (tabular / Kuwaiti algorithm)
    var l = jdn - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final hMonth = (24 * l) ~/ 709;
    final hDay = l - (709 * hMonth) ~/ 24;
    final hYear = 30 * n + j - 30;

    return HijriDate(day: hDay, month: hMonth, year: hYear);
  }

  /// The inverse of [fromGregorian] — approximate Gregorian date for a
  /// given Hijri (year, month, day), using the matching inverse of the
  /// same tabular/Kuwaiti algorithm. Needed to lay out a full calendar
  /// grid (which Gregorian date does Hijri day N fall on).
  static DateTime toGregorian({required int year, required int month, required int day}) {
    final jdn = (11 * year + 3) ~/ 30 +
        354 * year +
        30 * month -
        (month - 1) ~/ 2 +
        day +
        1948440 -
        385;

    // Julian Day Number -> Gregorian calendar date (standard inverse)
    var l = jdn + 68569;
    final n = (4 * l) ~/ 146097;
    l = l - (146097 * n + 3) ~/ 4;
    final i = (4000 * (l + 1)) ~/ 1461001;
    l = l - (1461 * i) ~/ 4 + 31;
    final j = (80 * l) ~/ 2447;
    final gDay = l - (2447 * j) ~/ 80;
    l = j ~/ 11;
    final gMonth = j + 2 - 12 * l;
    final gYear = 100 * (n - 49) + i + l;

    return DateTime(gYear, gMonth, gDay).add(Duration(days: calibrationOffsetDays));
  }

  /// Number of days in this Hijri month (29 or 30), derived by finding
  /// the Gregorian gap to the 1st of the following month rather than a
  /// fixed alternating pattern — some tabular-calendar years shift which
  /// months are long/short, so this stays correct rather than guessing.
  static int daysInMonth(int year, int month) {
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final start = toGregorian(year: year, month: month, day: 1);
    final nextStart = toGregorian(year: nextYear, month: nextMonth, day: 1);
    return nextStart.difference(start).inDays;
  }
}
