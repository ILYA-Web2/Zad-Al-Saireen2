import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../services/archive_service.dart';
import '../../../../services/quick_audio_player_service.dart';
import '../../../../services/audio_cache_service.dart';
import '../../../downloads/data/models/history_model.dart';
import '../../../downloads/presentation/providers/history_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/video_card.dart';
import '../widgets/hussaini_search_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeProvider);

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Top padding (below AppBar) ─────────────────────────────────────
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Search Bar ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: HussainiSearchBar(
                onSearch: (q) => ref.read(homeProvider.notifier).searchVideos(q),
                recentSearches: state.recentSearches,
                onRemoveSearch: (q) => ref.read(homeProvider.notifier).removeRecentSearch(q),
                onClearSearches: () => ref.read(homeProvider.notifier).clearRecentSearches(),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Section Header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.library_music_rounded,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.query.isNotEmpty
                          ? 'نتائج: ${state.query}'
                          : 'المحتوى الحسيني',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (state.isLoading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.accent),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 4)),

          // ── Alternative suggestions (when no matching results) ─────────────
          if (state.hasNoResults && state.alternativeSuggestions.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: GlassContainer(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tips_and_updates_rounded,
                              size: 16, color: AppColors.accent),
                          SizedBox(width: 6),
                          Text(
                            'لم نجد نتائج مطابقة — جرّب:',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: state.alternativeSuggestions
                            .map((s) => GestureDetector(
                                  onTap: () => ref
                                      .read(homeProvider.notifier)
                                      .searchVideos(s),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AppColors.accent.withOpacity(0.4),
                                          width: 0.8),
                                    ),
                                    child: Text(
                                      s,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        color: AppColors.accentLight,
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Error state ────────────────────────────────────────────────────
          if (state.error != null || state.isOffline)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GlassContainer(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: Column(
                    children: [
                      Icon(
                        state.isOffline
                            ? Icons.wifi_off_rounded
                            : Icons.error_outline_rounded,
                        size: 36,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.isOffline
                            ? 'تعذّر الاتصال — تحقق من الإنترنت'
                            : (state.error ?? 'حدث خطأ غير متوقع'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => ref
                            .read(homeProvider.notifier)
                            .searchVideos(AppConstants.hussainiKeywords.first),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.accent.withOpacity(0.5),
                                width: 1),
                          ),
                          child: Text(
                            'إعادة المحاولة',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Video list (YouTube-style: one full-width card per row) ─────────
          if (state.isLoading && state.videos.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList.separated(
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) => const _SkeletonCard(),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
              sliver: SliverList.separated(
                itemCount: state.videos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) =>
                    VideoCard(video: state.videos[index])
                        .animate(delay: (index * 40).ms)
                        .fadeIn(duration: 250.ms)
                        .slideY(begin: 0.08, end: 0),
              ),
            ),

          // ── Archive.org results (free, public-domain, offline-capable) ──────
          if (state.archiveResults.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.public_rounded, size: 16, color: AppColors.accentLight),
                    const SizedBox(width: 6),
                    Text(
                      'مصادر صوتية إضافية',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (state.isArchiveLoading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentLight),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ArchiveResultTile(result: state.archiveResults[index])
                        .animate(delay: (index * 40).ms)
                        .fadeIn(duration: 250.ms),
                  ),
                  childCount: state.archiveResults.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: AppColors.glassBorder, width: 1),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 10,
          width: 120,
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _ArchiveResultTile extends ConsumerStatefulWidget {
  const _ArchiveResultTile({required this.result});
  final ArchiveAudioResult result;

  @override
  ConsumerState<_ArchiveResultTile> createState() => _ArchiveResultTileState();
}

class _ArchiveResultTileState extends ConsumerState<_ArchiveResultTile> {
  bool _playing = false;
  bool _isCached = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    AudioCacheService.instance.isCached(widget.result.streamUrl).then((cached) {
      if (mounted) setState(() => _isCached = cached);
    });
  }

  Future<void> _download() async {
    if (_isDownloading || _isCached) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
    try {
      await AudioCacheService.instance.downloadForOffline(
        widget.result.streamUrl,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      if (mounted) setState(() => _isCached = true);
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

  Future<void> _toggle() async {
    final r = widget.result;
    try {
      await QuickAudioPlayerService.instance.playOrToggle(r.streamUrl);
      if (mounted) {
        setState(() => _playing = QuickAudioPlayerService.instance.player.playing);
      }
    } catch (e) {
      if (mounted) setState(() => _playing = false);
      return;
    }

    // Best-effort — never allowed to affect playback state (see
    // HistoryNotifier for why).
    ref.read(historyProvider.notifier).logPlay(
          id: 'archive_${r.identifier}_${r.fileName}',
          type: HistoryType.dua,
          title: r.title,
          subtitle: 'Archive.org',
          thumbnailUrl: r.thumbnailUrl,
          route: r.streamUrl,
        );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return GlassContainer(
      padding: const EdgeInsets.all(10),
      borderRadius: 14,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withOpacity(0.18),
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 20,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textPrimary),
                ),
                if (r.artist != null && r.artist!.isNotEmpty)
                  Text(
                    r.artist!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _isDownloading
              ? SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: _download,
                  child: Icon(
                    _isCached ? Icons.download_done_rounded : Icons.download_rounded,
                    size: 20,
                    color: _isCached ? AppColors.accentLight : AppColors.textMuted,
                  ),
                ),
          const SizedBox(width: 6),
          Icon(Icons.offline_bolt_rounded, size: 14, color: AppColors.accentLight),
        ],
      ),
    );
  }
}
