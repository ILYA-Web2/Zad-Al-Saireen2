/// Parses a video duration that may come in either of the two formats
/// this app's different sources actually use:
/// - YouTube Data API: ISO 8601, e.g. `PT4M13S`, `PT1H2M3S`, `PT45S`.
/// - Piped/Invidious (already used as a fallback elsewhere in the app):
///   a plain integer number of seconds, e.g. `"253"`.
///
/// Returns null for anything unparseable rather than guessing, so the UI
/// can simply hide the badge instead of showing a wrong duration.
int? parseDurationToSeconds(String? raw) {
  if (raw == null || raw.isEmpty) return null;

  if (raw.startsWith('PT') || raw.startsWith('P')) {
    final match = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?').firstMatch(raw);
    if (match == null) return null;
    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
    final total = hours * 3600 + minutes * 60 + seconds;
    return total > 0 ? total : null;
  }

  final asInt = int.tryParse(raw);
  return (asInt != null && asInt > 0) ? asInt : null;
}

/// Formats seconds as YouTube does: `M:SS` under an hour, `H:MM:SS` at or
/// above an hour — always two digits for minutes/seconds once padded.
String formatDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
