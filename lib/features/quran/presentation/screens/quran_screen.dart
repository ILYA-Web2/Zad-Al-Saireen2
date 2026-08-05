import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../services/hive_service.dart';
import '../../../../main.dart' show quranAudioHandler;
import '../../../../services/quran_reciter_service.dart';
import '../../../../services/audio_cache_service.dart';
import '../../../downloads/data/models/history_model.dart';
import '../../../downloads/data/models/download_model.dart';
import '../../../downloads/presentation/providers/history_provider.dart';
import '../../domain/entities/surah_entity.dart';
import '../providers/quran_provider.dart';
import '../widgets/reciter_selector_sheet.dart';

class QuranScreen extends ConsumerWidget {
  const QuranScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(surahListProvider);
    final selectedReciter = ref.watch(selectedReciterProvider);

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 12),

          // ── Search field ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 50,
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      textDirection: TextDirection.rtl,
                      onChanged: (q) {
                        ref.read(surahListProvider.notifier).search(q);
                        if (q == AppConstants.adminUnlockCode && !HiveService.instance.isAdminUnlocked()) {
                          HiveService.instance.unlockAdminPanel();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم فتح لوحة الإدارة — راجع "المزيد من الأقسام"')),
                          );
                        }
                      },
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن سورة بالاسم أو الرقم...',
                        hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Reciter Selector ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => const ReciterSelectorSheet(),
              ),
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.record_voice_over_rounded, size: 18, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        selectedReciter != null ? 'القارئ: ${selectedReciter.arabicName}' : 'اختر القارئ...',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, size: 18, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Continue Reading ─────────────────────────────────────────────
          // Didn't exist before at all — closing the app mid-Surah lost your
          // place completely every time. Reads the bookmark
          // SurahReadScreen now saves automatically while scrolling.
          const _ContinueReadingCard(),

          // ── Full-text Ayah Search Results ─────────────────────────────────
          // Searches the actual wording of the Quran (not just Surah
          // names) — the repository call already existed but was never
          // wired to any UI before this.
          if (state.searchQuery.length >= 3 || state.isSearchingAyahText)
            _AyahSearchResultsSection(
              results: state.ayahSearchResults,
              isLoading: state.isSearchingAyahText,
            ),

          // ── Surah List ───────────────────────────────────────────────────
          Expanded(
            child: state.isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                : state.error != null
                    ? _ErrorState(onRetry: () => ref.read(surahListProvider.notifier).loadSurahs())
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                        itemCount: state.filteredSurahs.length,
                        itemBuilder: (context, index) {
                          final surah = state.filteredSurahs[index];
                          final tile = Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SurahTile(surah: surah, reciter: selectedReciter),
                          );
                          // Animating all 114 rows (each with its own
                          // AnimationController) was pure rendering
                          // overhead scaling with list length — a likely
                          // source of the reported lag. Only the first
                          // screenful gets the entrance animation now.
                          if (index >= 12) return tile;
                          return tile.animate(delay: (index * 20).ms).fadeIn(duration: 180.ms);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SurahTile extends ConsumerStatefulWidget {
  const _SurahTile({required this.surah, required this.reciter});
  final SurahEntity surah;
  final ReciterInfo? reciter;

  @override
  ConsumerState<_SurahTile> createState() => _SurahTileState();
}

class _SurahTileState extends ConsumerState<_SurahTile> {
  SurahEntity get surah => widget.surah;
  ReciterInfo? get reciter => widget.reciter;

  // Didn't exist anywhere in the Surah list before — a download button
  // only ever appeared inside the mini-player, which meant it was
  // invisible unless a Surah had already been played at least once.
  bool _isCached = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  ReciterInfo? _lastCheckedReciter;

  @override
  void initState() {
    super.initState();
    _checkCacheStatus();
  }

  @override
  void didUpdateWidget(covariant _SurahTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reciter != widget.reciter) _checkCacheStatus();
  }

  void _checkCacheStatus() {
    final r = reciter;
    if (r == null || r == _lastCheckedReciter) return;
    _lastCheckedReciter = r;
    final url = r.surahUrl(surah.number);
    AudioCacheService.instance.isCached(url).then((cached) {
      if (mounted) setState(() => _isCached = cached);
    });
  }

  Future<void> _download() async {
    if (reciter == null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const ReciterSelectorSheet(),
      );
      return;
    }
    if (_isDownloading || _isCached) return;
    final url = reciter!.surahUrl(surah.number);
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
      if (mounted) setState(() => _isCached = true);

      // Was completely invisible before — the file sat in the app's
      // silent playback cache with no way to browse or confirm it was
      // actually there, which is exactly why "downloaded Surahs" were
      // impossible to find. Registering it here surfaces it under
      // السجل ← القرآن, the same way every other download in the app
      // already works.
      try {
        final localPath = await AudioCacheService.instance.localPathIfCached(url);
        final size = await AudioCacheService.instance.fileSizeFor(url);
        if (localPath != null) {
          final model = DownloadModel(
            videoId: 'surah_${surah.number}_${reciter!.id}',
            title: 'سورة ${surah.name}',
            channelName: reciter!.arabicName,
            thumbnailUrl: '',
            category: DownloadCategory.quran,
            downloadedAt: DateTime.now(),
            localPath: localPath,
            fileSizeBytes: size,
          );
          await HiveService.instance.saveDownload(model.hiveKey, model.toMap());
        }
      } catch (_) {
        // Registration failing must never undo the download itself —
        // the audio is already safely cached and playable either way.
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

  Future<void> _listen(BuildContext context) async {
    if (reciter == null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const ReciterSelectorSheet(),
      );
      return;
    }
    try {
      await quranAudioHandler.loadSurah(
        surahNumber: surah.number,
        surahNameArabic: surah.name,
        reciter: reciter!,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر تشغيل السورة، حاول مرة أخرى')),
        );
      }
      return;
    }

    // Best-effort — never allowed to affect playback state.
    ref.read(historyProvider.notifier).logPlay(
          id: 'quran_${surah.number}',
          type: HistoryType.quran,
          title: surah.name,
          subtitle: 'القرآن الكريم — ${reciter!.arabicName}',
          thumbnailUrl: '',
          route: '/quran/${surah.number}?arabic=${surah.name}&type=${surah.revelationTypeArabic}',
        );
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withOpacity(0.15),
              border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 1),
            ),
            child: Center(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  '${surah.number}',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stripArabicDiacritics(surah.name),
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${surah.numberOfAyahs} آية  •  ${surah.revelationTypeArabic}',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          _ActionButton(
            icon: Icons.menu_book_rounded,
            label: 'قراءة',
            onTap: () {
              final uri = Uri(
                path: '/quran/${surah.number}',
                queryParameters: {'arabic': surah.name, 'type': surah.revelationTypeArabic},
              );
              context.push(uri.toString());
            },
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.headphones_rounded,
            label: 'استماع',
            filled: true,
            onTap: () => _listen(context),
          ),
          const SizedBox(width: 8),
          _isDownloading
              ? SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                )
              : _ActionButton(
                  icon: _isCached ? Icons.download_done_rounded : Icons.download_rounded,
                  label: _isCached ? 'محمَّل' : 'تحميل',
                  onTap: _download,
                ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? AppColors.accent : AppColors.glassFill,
          borderRadius: BorderRadius.circular(8),
          border: filled ? null : Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.white : AppColors.textSecondary),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 9,
                color: filled ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text('تعذّر تحميل السور', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.accent)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AyahSearchResultsSection extends StatelessWidget {
  const _AyahSearchResultsSection({required this.results, required this.isLoading});
  final List<AyahEntity> results;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (!isLoading && results.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.manage_search_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  isLoading ? 'جارٍ البحث في نص القرآن…' : 'نتائج من نص القرآن (${results.length})',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
            if (isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(color: AppColors.accent, backgroundColor: AppColors.glassBorder),
              )
            else
              ...results.take(6).map((ayah) => Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: GestureDetector(
                      onTap: () => context.push('/quran/${ayah.surahNumber}'),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${ayah.surahNumber}:${ayah.numberInSurah}',
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.accent)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ayah.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(fontFamily: 'Amiri', fontSize: 14, color: AppColors.textSecondary, height: 1.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard();

  @override
  Widget build(BuildContext context) {
    final surahNumber = HiveService.instance.getSetting<int>('quran_last_read_surah');
    final surahName = HiveService.instance.getSetting<String>('quran_last_read_surah_name');
    final revelationType = HiveService.instance.getSetting<String>('quran_last_read_type') ?? '';
    if (surahNumber == null || surahName == null || surahName.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: () => context.push(
          '/quran/$surahNumber?arabic=${Uri.encodeComponent(surahName)}&type=${Uri.encodeComponent(revelationType)}',
        ),
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.menu_book_rounded, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('متابعة القراءة',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text('سورة $surahName',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ],
                ),
              ),
              Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
