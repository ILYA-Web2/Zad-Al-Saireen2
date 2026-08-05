import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../main.dart' show quranAudioHandler;
import '../../../../services/audio_cache_service.dart';
import '../../../../services/hive_service.dart';
import '../../../../services/quran_reciter_service.dart';
import '../../../downloads/data/models/download_model.dart';

/// A small, persistent player bar shown directly above the bottom
/// navigation bar whenever a Surah is loaded — tapping "استماع" on any
/// Surah starts playback here without leaving the current screen. Stays
/// visible (and playback keeps running) while navigating anywhere else in
/// the app, since it's driven by the shared background [quranAudioHandler]
/// rather than any one screen's local state.
class QuranMiniPlayer extends StatefulWidget {
  const QuranMiniPlayer({super.key});

  @override
  State<QuranMiniPlayer> createState() => _QuranMiniPlayerState();
}

class _QuranMiniPlayerState extends State<QuranMiniPlayer> {
  bool _visible = false;
  bool _isPlaying = false;
  bool _isRepeat = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;

  // Explicit "download for offline" — didn't exist before at all: audio
  // only ever got cached silently after being fully listened to once.
  bool _isAudioCached = false;
  bool _isDownloadingAudio = false;
  double _downloadProgress = 0.0;
  int? _lastCheckedSurah;
  ReciterInfo? _lastCheckedReciter;

  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5];

  @override
  void initState() {
    super.initState();
    _playingSub = quranAudioHandler.playingStream.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
          if (quranAudioHandler.currentSurahNumber != null) _visible = true;
        });
      }
    });
    _positionSub = quranAudioHandler.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSub = quranAudioHandler.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }

  void _changeSpeed() {
    HapticFeedback.selectionClick();
    final next = _speeds[(_speeds.indexOf(_speed) + 1) % _speeds.length];
    setState(() => _speed = next);
    quranAudioHandler.setSpeed(next);
  }

  void _toggleRepeat() {
    HapticFeedback.selectionClick();
    final next = !_isRepeat;
    setState(() => _isRepeat = next);
    quranAudioHandler.setRepeatEnabled(next);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _maybeCheckAudioCache(int? surahNumber, ReciterInfo? reciter) {
    if (surahNumber == null || reciter == null) return;
    if (_lastCheckedSurah == surahNumber && _lastCheckedReciter == reciter) return;
    _lastCheckedSurah = surahNumber;
    _lastCheckedReciter = reciter;
    _isAudioCached = false;
    final url = reciter.surahUrl(surahNumber);
    AudioCacheService.instance.isCached(url).then((cached) {
      if (mounted && _lastCheckedSurah == surahNumber) {
        setState(() => _isAudioCached = cached);
      }
    });
  }

  Future<void> _downloadCurrentSurah() async {
    final surahNumber = quranAudioHandler.currentSurahNumber;
    final reciter = quranAudioHandler.currentReciter;
    if (surahNumber == null || reciter == null || _isDownloadingAudio || _isAudioCached) return;
    final url = reciter.surahUrl(surahNumber);
    setState(() {
      _isDownloadingAudio = true;
      _downloadProgress = 0.0;
    });
    try {
      await AudioCacheService.instance.downloadForOffline(
        url,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      if (mounted) setState(() => _isAudioCached = true);

      try {
        final localPath = await AudioCacheService.instance.localPathIfCached(url);
        final size = await AudioCacheService.instance.fileSizeFor(url);
        final surahName = quranAudioHandler.mediaItem.value?.title ?? 'سورة $surahNumber';
        if (localPath != null) {
          final model = DownloadModel(
            videoId: 'surah_${surahNumber}_${reciter.id}',
            title: surahName,
            channelName: reciter.arabicName,
            thumbnailUrl: '',
            category: DownloadCategory.quran,
            downloadedAt: DateTime.now(),
            localPath: localPath,
            fileSizeBytes: size,
          );
          await HiveService.instance.saveDownload(model.hiveKey, model.toMap());
        }
      } catch (_) {}
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر تحميل السورة — تحقق من الاتصال', textDirection: TextDirection.rtl)),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingAudio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || quranAudioHandler.currentSurahNumber == null) {
      return const SizedBox.shrink();
    }

    final reciter = quranAudioHandler.currentReciter;
    _maybeCheckAudioCache(quranAudioHandler.currentSurahNumber, reciter);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: GlassContainer(
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        borderRadius: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: _duration.inMilliseconds > 0
                    ? _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble()
                    : 0.0,
                max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                onChanged: (v) => quranAudioHandler.seek(Duration(milliseconds: v.toInt())),
                activeColor: AppColors.accent,
                inactiveColor: AppColors.glassBorder,
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: _isPlaying ? quranAudioHandler.pause : quranAudioHandler.play,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        quranAudioHandler.mediaItem.value?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${reciter?.arabicName ?? ''} — ${_fmt(_position)} / ${_fmt(_duration)}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _changeSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_speed}x',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _toggleRepeat,
                  child: Icon(
                    Icons.repeat_one_rounded,
                    size: 18,
                    color: _isRepeat ? AppColors.accent : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _isAudioCached ? null : _downloadCurrentSurah,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: _isDownloadingAudio
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              value: _downloadProgress > 0 ? _downloadProgress : null,
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          )
                        : Icon(
                            _isAudioCached ? Icons.download_done_rounded : Icons.download_rounded,
                            size: 18,
                            color: _isAudioCached ? AppColors.accentLight : AppColors.textMuted,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    quranAudioHandler.stop();
                    setState(() => _visible = false);
                  },
                  child: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
