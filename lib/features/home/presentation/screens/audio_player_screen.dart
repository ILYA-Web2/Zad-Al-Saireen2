import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/universal_share_sheet.dart';
import '../../../../main.dart' show quranAudioHandler;
import '../../../../services/audio_stream_resolver.dart';
import '../../../../services/audio_cache_service.dart';
import '../../../../services/hive_service.dart';
import '../../../downloads/data/models/download_model.dart';

/// Replaces the old video player as the destination for every search
/// result, download, and history item in the app. Deliberately audio-only
/// — no video decoder, no muxed-stream requirement, and therefore none of
/// the specific reliability problems (long load times, "no compatible
/// stream found" failures) that came from needing a combined video+audio
/// track. See AudioStreamResolver for the actual mechanism.
///
/// Design promise for failures: this screen never shows a dead-end
/// "فشل التشغيل" wall. A failed resolution retries automatically in the
/// background (up to 3 times with backoff) while the player chrome stays
/// fully visible the whole time; only after that does it fall back to a
/// small inline retry affordance *within* the same screen, never a
/// separate error page.
class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
  });

  final String videoId;
  final String title;
  final String artist;
  final String thumbnailUrl;

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

enum _LoadState { loading, ready, retrying }

class _AudioPlayerScreenState extends State<AudioPlayerScreen>
    with SingleTickerProviderStateMixin {
  _LoadState _loadState = _LoadState.loading;
  int _attempt = 0;
  static const _maxAttempts = 3;

  bool _isFavorite = false;
  bool _isCached = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  double _speed = 1.0;
  Duration? _sleepTimerRemaining;
  Timer? _sleepTimerTicker;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _load();
    _positionSub = quranAudioHandler.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _playingSub = quranAudioHandler.playingStream.listen((p) {
      if (mounted) setState(() => _isPlaying = p);
    });
    _isFavorite = HiveService.instance.getFavoriteTrackIds().contains(widget.videoId);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playingSub?.cancel();
    _sleepTimerTicker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadState = _attempt == 0 ? _LoadState.loading : _LoadState.retrying);
    _attempt++;

    final url = await AudioStreamResolver.instance.resolve(widget.videoId);
    if (!mounted) return;

    if (url == null) {
      if (_attempt < _maxAttempts) {
        // Silent, automatic retry — the whole point is that the person
        // never sees a dead "failed" screen for what's usually just one
        // of several community servers being briefly unavailable.
        await Future.delayed(Duration(seconds: _attempt * 2));
        if (mounted) _load();
        return;
      }
      setState(() => _loadState = _LoadState.retrying);
      return;
    }

    try {
      await quranAudioHandler.loadTrack(
        id: widget.videoId,
        title: widget.title,
        artist: widget.artist,
        streamUrl: url,
      );
      final cached = await AudioCacheService.instance.isCached(url);
      if (mounted) {
        setState(() {
          _loadState = _LoadState.ready;
          _isCached = cached;
          _duration = quranAudioHandler.duration;
        });
      }
    } catch (_) {
      if (_attempt < _maxAttempts) {
        await Future.delayed(Duration(seconds: _attempt * 2));
        if (mounted) _load();
      } else if (mounted) {
        setState(() => _loadState = _LoadState.retrying);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.lightImpact();
    setState(() => _isFavorite = !_isFavorite);
    await HiveService.instance.toggleFavoriteTrack(widget.videoId);
  }

  Future<void> _download() async {
    if (_isDownloading || _isCached) return;
    final url = await AudioStreamResolver.instance.resolve(widget.videoId);
    if (url == null) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
    try {
      await AudioCacheService.instance.downloadForOffline(
        url,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      final size = await AudioCacheService.instance.fileSizeFor(url);
      final localPath = await AudioCacheService.instance.localPathIfCached(url);
      if (mounted) setState(() => _isCached = true);
      if (localPath != null) {
        final model = DownloadModel(
          videoId: widget.videoId,
          title: widget.title,
          channelName: widget.artist,
          thumbnailUrl: widget.thumbnailUrl,
          category: DownloadCategory.audio,
          downloadedAt: DateTime.now(),
          localPath: localPath,
          fileSizeBytes: size,
        );
        await HiveService.instance.saveDownload(model.hiveKey, model.toMap());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر التحميل — تحقق من الاتصال', textDirection: TextDirection.rtl)),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _setSpeed(double speed) {
    setState(() => _speed = speed);
    quranAudioHandler.setSpeed(speed);
  }

  void _seekRelative(int seconds) {
    final target = _position + Duration(seconds: seconds);
    quranAudioHandler.seek(
      target < Duration.zero
          ? Duration.zero
          : (_duration != null && target > _duration! ? _duration! : target),
    );
  }

  void _setSleepTimer(Duration duration) {
    _sleepTimerTicker?.cancel();
    setState(() => _sleepTimerRemaining = duration);
    _sleepTimerTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _sleepTimerRemaining;
      if (remaining == null || remaining.inSeconds <= 1) {
        timer.cancel();
        setState(() => _sleepTimerRemaining = null);
        quranAudioHandler.pause();
      } else {
        setState(() => _sleepTimerRemaining = remaining - const Duration(seconds: 1));
      }
    });
  }

  void _openSleepTimerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.backgroundDeep,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
        ),
        child: Wrap(
          children: [
            Text('مؤقّت النوم', style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ...[5, 15, 30, 60].map((m) => ListTile(
                  title: Text('$m دقيقة', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                  onTap: () {
                    Navigator.pop(context);
                    _setSleepTimer(Duration(minutes: m));
                  },
                )),
            if (_sleepTimerRemaining != null)
              ListTile(
                title: Text('إلغاء المؤقّت', style: TextStyle(fontFamily: 'Cairo', color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _sleepTimerTicker?.cancel();
                  setState(() => _sleepTimerRemaining = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_downward_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  if (_sleepTimerRemaining != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(_fmt(_sleepTimerRemaining!), style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.accentLight)),
                    ),
                  IconButton(
                    icon: Icon(Icons.bedtime_outlined, color: AppColors.textSecondary),
                    onPressed: _openSleepTimerPicker,
                  ),
                  IconButton(
                    icon: Icon(Icons.share_rounded, color: AppColors.textSecondary),
                    onPressed: () => showUniversalShareSheet(
                      context,
                      title: widget.title,
                      body: widget.artist,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // ── Artwork ─────────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: widget.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.thumbnailUrl,
                        width: 260,
                        height: 260,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => _ArtworkPlaceholder(),
                      )
                    : _ArtworkPlaceholder(),
              ),
              const SizedBox(height: 28),

              Text(
                widget.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                widget.artist,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textMuted),
              ),

              const Spacer(),

              // ── Loading / retry (inline, never a separate error page) ──
              if (_loadState != _LoadState.ready)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _loadState == _LoadState.retrying
                      ? GestureDetector(
                          onTap: () {
                            setState(() => _attempt = 0);
                            _load();
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh_rounded, size: 16, color: AppColors.accent),
                              const SizedBox(width: 6),
                              Text('تعذّر الوصول لأي سيرفر متاح — اضغط لإعادة المحاولة',
                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.accent)),
                            ],
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                            ),
                            const SizedBox(width: 8),
                            Text('جارٍ التحميل...', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                ),

              // ── Progress ────────────────────────────────────────────────
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  activeTrackColor: AppColors.accent,
                  inactiveTrackColor: AppColors.glassBorder,
                  thumbColor: AppColors.accent,
                ),
                child: Slider(
                  value: (_duration != null && _duration!.inMilliseconds > 0)
                      ? _position.inMilliseconds.clamp(0, _duration!.inMilliseconds).toDouble()
                      : 0,
                  max: (_duration?.inMilliseconds ?? 1).toDouble().clamp(1, double.infinity),
                  onChanged: _loadState == _LoadState.ready
                      ? (v) => quranAudioHandler.seek(Duration(milliseconds: v.toInt()))
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_position), style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted)),
                    Text(_duration != null ? _fmt(_duration!) : '--:--', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Main controls ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(Icons.replay_10_rounded, size: 26, color: AppColors.textSecondary),
                    onPressed: _loadState == _LoadState.ready ? () => _seekRelative(-10) : null,
                  ),
                  GestureDetector(
                    onTap: _loadState == _LoadState.ready
                        ? () => _isPlaying ? quranAudioHandler.pause() : quranAudioHandler.play()
                        : null,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
                      child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.forward_10_rounded, size: 26, color: AppColors.textSecondary),
                    onPressed: _loadState == _LoadState.ready ? () => _seekRelative(10) : null,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Secondary controls ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () => _setSpeed(_speed >= 2.0 ? 0.5 : _speed + 0.25),
                    child: Text('${_speed}x', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent)),
                  ),
                  IconButton(
                    icon: Icon(_isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _isFavorite ? AppColors.error : AppColors.textMuted),
                    onPressed: _toggleFavorite,
                  ),
                  _isDownloading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(value: _downloadProgress > 0 ? _downloadProgress : null, strokeWidth: 2, color: AppColors.accent),
                        )
                      : IconButton(
                          icon: Icon(_isCached ? Icons.download_done_rounded : Icons.download_rounded, color: _isCached ? AppColors.accentLight : AppColors.textMuted),
                          onPressed: _download,
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      color: AppColors.primaryMedium,
      child: Icon(Icons.graphic_eq_rounded, size: 72, color: AppColors.accent.withOpacity(0.5)),
    );
  }
}
