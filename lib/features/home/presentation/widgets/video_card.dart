import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/angular_frame.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/video_entity.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../services/hive_service.dart';
import '../providers/home_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// YouTube-style result card: full-width, undistorted 16:9 thumbnail on
/// top, title/metadata below it. The whole card is a single tap target —
/// there is no separate "video"/"audio" button anymore (audio-only
/// playback has been removed app-wide; every result opens the real video
/// player).
class VideoCard extends ConsumerStatefulWidget {
  const VideoCard({super.key, required this.video});
  final VideoEntity video;

  @override
  ConsumerState<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends ConsumerState<VideoCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    // The real, persistent source of truth — not whatever provider list
    // this particular VideoCard instance happens to be rendered inside.
    // Checking against a specific provider's in-memory list (as this used
    // to) meant the heart icon never reflected reality for video cards
    // shown anywhere other than the home screen's own search results —
    // related videos in the player, for instance — even though the tap
    // itself was correctly saving the favorite the whole time.
    _isFav = HiveService.instance.hasDownload('favorite_${widget.video.id}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openPlayer() {
    if (widget.video.id.isEmpty) {
      // Defensive guard — every known source of video results now filters
      // this out already, but this makes it impossible for a future
      // regression anywhere upstream to ever produce the
      // "GoException: no routes for location" crash again from this tap.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح هذا الفيديو — بيانات غير مكتملة')),
      );
      return;
    }
    HapticFeedback.lightImpact();
    final uri = Uri(
      path: '/player/${widget.video.id}',
      queryParameters: {
        'title': widget.video.title,
        'channel': widget.video.channelTitle,
        'thumbnail': widget.video.thumbnailUrl,
      },
    );
    context.push(uri.toString());
  }

  bool _isFav = false;

  bool get _isWatched => HiveService.instance.hasWatched('video_${widget.video.id}');

  String? get _durationLabel {
    final seconds = parseDurationToSeconds(widget.video.duration);
    if (seconds == null) return null;
    return formatDuration(seconds);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: _openPlayer,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Thumbnail (real 16:9, never stretched/distorted) ───────────
            AngularFrame(
              padding: EdgeInsets.zero,
              child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.video.thumbnailUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 150),
                      placeholder: (context, url) => Container(
                        color: AppColors.primaryMedium,
                        child: Center(
                          child: Icon(
                            Icons.image_rounded,
                            color: AppColors.textMuted,
                            size: 30,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.primaryMedium,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: AppColors.textMuted,
                            size: 30,
                          ),
                        ),
                      ),
                    ),

                    // Real "already watched" indicator — checked against
                    // the same history entry the player itself writes on
                    // play, not a guess.
                    if (_isWatched)
                      Container(color: Colors.black.withOpacity(0.45)),
                    if (_isWatched)
                      const Positioned(
                        bottom: 8,
                        left: 8,
                        child: _WatchedBadge(),
                      ),

                    // Centered play glyph so it always reads as "tap to play"
                    // without ever distorting into an oval — wrapped in
                    // Center rather than relying on Stack/Positioned math.
                    Center(
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.38),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),

                    // Duration badge — YouTube-style, bottom-right, real
                    // parsed value (handles both the ISO8601 format the
                    // YouTube API gives and the plain-seconds format the
                    // Piped/Invidious fallbacks give).
                    if (_durationLabel != null)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _durationLabel!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),

                    // Favorite toggle, top-right corner of the thumbnail.
                    Positioned(
                      top: 8,
                      left: 8,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _isFav = !_isFav);
                          ref
                              .read(homeProvider.notifier)
                              .toggleFavorite(widget.video);
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 16,
                            color: _isFav
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Title + metadata, below the thumbnail ───────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.video.channelTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small "already watched" checkmark badge — sits opposite the duration
/// badge so neither ever collides with the other.
class _WatchedBadge extends StatelessWidget {
  const _WatchedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 12, color: AppColors.accent),
          const SizedBox(width: 3),
          const Text(
            'شوهد',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
