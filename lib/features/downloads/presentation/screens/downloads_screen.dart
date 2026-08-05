import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../services/quick_audio_player_service.dart';
import '../../../../main.dart' show quranAudioHandler;
import '../../../../services/quran_reciter_service.dart';
import '../../data/models/download_model.dart';
import '../../data/models/history_model.dart';
import '../providers/downloads_provider.dart';
import '../providers/history_provider.dart';

/// "السجل" (History & Record) — renamed from the old "التحميل" (Downloads)
/// tab. Nested tabs: تاريخ الاستماع (everything played, replayable offline
/// once cached) / التنزيلات (المرئيات المحمّلة) / المفضلة.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SafeArea(
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            SizedBox(height: 12),
            _HistoryHeader(),
            SizedBox(height: 12),
            _HistoryTabBar(),
            SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                physics: BouncingScrollPhysics(),
                children: [
                  _HistoryTab(),
                  _DownloadsTab(category: DownloadCategory.audio),
                  _DownloadsTab(category: DownloadCategory.quran),
                  _DownloadsTab(category: DownloadCategory.favorite),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryHeader extends ConsumerWidget {
  const _HistoryHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalSize = ref.watch(downloadsProvider.select((s) => s.formattedTotalSize));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 20, color: AppColors.accent),
          SizedBox(width: 8),
          Text(
            'السجل',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          // Total on-device storage used by everything downloaded — this
          // screen never told the user this number before at all.
          Icon(Icons.sd_storage_rounded, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            totalSize,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _HistoryTabBar extends StatelessWidget {
  const _HistoryTabBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            isScrollable: false,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
            ),
            tabs: [
              Tab(text: 'الاستماع'),
              Tab(text: 'التنزيلات'),
              Tab(text: 'القرآن'),
              Tab(text: 'المفضلة'),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Tab 1 — تاريخ الاستماع (everything played: Quran, duas, latmiyat, video)
// ─────────────────────────────────────────────────────────────────────────
class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyProvider);

    if (state.entries.isEmpty) {
      return const _EmptyState(
        icon: Icons.history_toggle_off_rounded,
        message: 'لم تستمع إلى أي شيء بعد',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemCount: state.entries.length,
      itemBuilder: (context, index) {
        final entry = state.entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _HistoryTile(entry: entry)
              .animate(delay: (index * 40).ms)
              .fadeIn(duration: 250.ms)
              .slideX(begin: 0.05, end: 0),
        );
      },
    );
  }
}

class _HistoryTile extends ConsumerStatefulWidget {
  const _HistoryTile({required this.entry});
  final HistoryEntry entry;

  @override
  ConsumerState<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends ConsumerState<_HistoryTile> {
  bool _playing = false;

  Future<void> _play() async {
    final entry = widget.entry;
    if (entry.type == HistoryType.video) {
      final uri = Uri(
        path: '/player/${entry.id.replaceFirst('video_', '')}',
        queryParameters: {'title': entry.title, 'channel': entry.subtitle},
      );
      if (mounted) context.push(uri.toString());
      return;
    }
    if (entry.type == HistoryType.quran) {
      context.push(entry.route);
      return;
    }
    // Dua / Latmiya — replay directly, offline if already cached.
    try {
      await QuickAudioPlayerService.instance.playOrToggle(entry.route);
      if (mounted) {
        setState(() => _playing = QuickAudioPlayerService.instance.player.playing);
      }
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return GlassContainer(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: entry.thumbnailUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: entry.thumbnailUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => _fallbackIcon(entry.type),
                  )
                : _fallbackIcon(entry.type),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.offline_bolt_rounded,
                        size: 12,
                        color: AppColors.accentLight.withOpacity(0.8)),
                    const SizedBox(width: 4),
                    Text(
                      entry.subtitle,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _play,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withOpacity(0.2),
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 18,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(historyProvider.notifier).remove(entry.id);
            },
            child: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _fallbackIcon(HistoryType type) {
    return Container(
      width: 56,
      height: 56,
      color: AppColors.primaryMedium,
      child: Icon(
        type == HistoryType.video ? Icons.videocam_rounded : Icons.menu_book_rounded,
        color: AppColors.textMuted,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Tabs 2-4 — التنزيلات (المرئيات المحمّلة) / المفضلة
// (existing explicit-download system, reused as-is per category)
// ─────────────────────────────────────────────────────────────────────────
class _DownloadsTab extends ConsumerWidget {
  const _DownloadsTab({required this.category});
  final DownloadCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadsProvider);
    final items = state.downloads.where((d) => d.category == category).toList();

    if (items.isEmpty) {
      return _EmptyState(
        icon: category == DownloadCategory.favorite
            ? Icons.favorite_border_rounded
            : Icons.download_done_rounded,
        message: 'لا توجد ${category.label} بعد',
      );
    }

    return Column(
      children: [
        if (state.isSelectionMode) _SelectionActionBar(items: items),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DownloadTile(download: items[index])
                    .animate(delay: (index * 50).ms)
                    .fadeIn(duration: 250.ms)
                    .slideX(begin: 0.05, end: 0),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Appears only while at least one item is selected — shows the count,
/// a "select all" shortcut for the current category/tab, and the actual
/// bulk-delete action. Didn't exist before: deleting several old
/// downloads meant tapping the per-row trash icon once per item.
class _SelectionActionBar extends ConsumerWidget {
  const _SelectionActionBar({required this.items});
  final List<DownloadModel> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCount = ref.watch(downloadsProvider.select((s) => s.selectedKeys.length));
    final notifier = ref.read(downloadsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Text(
              '$selectedCount محدَّد',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                final allKeys = items.map((d) => d.hiveKey).toSet();
                final alreadyAllSelected =
                    ref.read(downloadsProvider).selectedKeys.containsAll(allKeys);
                notifier.setSelection(allKeys, selected: !alreadyAllSelected);
              },
              child: Text(
                'تحديد الكل',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.accent),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: notifier.exitSelectionMode,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                await notifier.deleteSelected();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 4),
                    Text('حذف', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.error)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({required this.download});
  final DownloadModel download;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelectionMode = ref.watch(downloadsProvider.select((s) => s.isSelectionMode));
    final isSelected = ref.watch(downloadsProvider.select((s) => s.selectedKeys.contains(download.hiveKey)));
    final notifier = ref.read(downloadsProvider.notifier);

    return GestureDetector(
      onLongPress: () {
        if (!isSelectionMode) {
          HapticFeedback.mediumImpact();
          notifier.toggleSelection(download.hiveKey);
        }
      },
      onTap: isSelectionMode ? () => notifier.toggleSelection(download.hiveKey) : null,
      child: GlassContainer(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            if (isSelectionMode) ...[
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 22,
                color: isSelected ? AppColors.accent : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: download.thumbnailUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 64,
                  height: 64,
                  color: AppColors.primaryMedium,
                  child: Icon(Icons.music_note_rounded, color: AppColors.textMuted),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    download.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    download.channelName,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    download.formattedSize,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      color: AppColors.accentLight,
                    ),
                  ),
                ],
              ),
            ),
            if (!isSelectionMode)
              Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (download.category == DownloadCategory.quran) {
                        // 'surah_<number>_<reciterId>' — not a real
                        // YouTube video ID, so this must never go through
                        // the video player route below (which is exactly
                        // what silently made these downloads unplayable
                        // from this screen before).
                        final parts = download.videoId.split('_');
                        final surahNumber = int.tryParse(parts.length > 1 ? parts[1] : '');
                        final reciterId = int.tryParse(parts.length > 2 ? parts[2] : '');
                        if (surahNumber == null || reciterId == null) return;
                        final reciters = await QuranReciterService.instance.getReciters();
                        ReciterInfo? reciter;
                        for (final r in reciters) {
                          if (r.id == reciterId) {
                            reciter = r;
                            break;
                          }
                        }
                        if (reciter == null) return;
                        await quranAudioHandler.loadSurah(
                          surahNumber: surahNumber,
                          surahNameArabic: download.title,
                          reciter: reciter,
                        );
                        return;
                      }
                      final uri = Uri(
                        path: '/player/${download.videoId}',
                        queryParameters: {
                          'title': download.title,
                          'channel': download.channelName,
                          'thumbnail': download.thumbnailUrl,
                        },
                      );
                      context.push(uri.toString());
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withOpacity(0.2),
                      ),
                      child: Icon(Icons.play_arrow_rounded, size: 18, color: AppColors.accent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(downloadsProvider.notifier).removeDownload(download);
                    },
                    child: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
