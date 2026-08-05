/// One playable quality option — a direct, muxed (video+audio already
/// combined in one file) stream URL, exactly what a plain video player
/// needs with no extra muxing step.
class VideoQualityOption {
  const VideoQualityOption({required this.label, required this.url});
  final String label; // e.g. "720p", "480p"
  final String url;
}
