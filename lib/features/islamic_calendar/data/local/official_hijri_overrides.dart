/// A manually-maintained table of *officially announced* Hijri month
/// start dates (Gregorian equivalent of day 1) — e.g. as announced by
/// the Najaf religious authority or the Imam Hussein/Abbas holy shrines'
/// offices — used to override the pure arithmetic calculation in
/// [HijriDate] whenever a real announcement is known.
///
/// There is no public live API for these announcements to pull from
/// automatically (checked — none of the shrine offices publish one), so
/// this table is updated by hand as announcements come in, and shipped
/// with each app update. Until an entry exists for a given Hijri
/// year/month, the calendar transparently falls back to the pure
/// arithmetic calculation (see ResolvedHijriDate in
/// islamic_calendar_screen.dart), optionally nudged by the user's own
/// manual calibration offset in the meantime.
///
/// Format: key is "hijriYear-hijriMonth" (e.g. '1447-1' = Muharram 1447),
/// value is the confirmed Gregorian date that Hijri day corresponds to.
class OfficialHijriOverrides {
  const OfficialHijriOverrides._();

  static const Map<String, DateTime> monthStarts = {
    // Example once confirmed from an official announcement:
    // '1447-1': DateTime(2025, 6, 27),
    //
    // Add one entry per confirmed month start here. Only the 1st of the
    // month needs to be listed — every other day of that month, and the
    // month's actual length (29 vs 30 days), is derived automatically
    // from the gap to the *next* listed (or arithmetic-fallback) month
    // start.
  };
}
