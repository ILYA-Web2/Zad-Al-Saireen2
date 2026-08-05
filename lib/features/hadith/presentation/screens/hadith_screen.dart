import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/universal_share_sheet.dart';
import '../../../../services/hive_service.dart';
import '../../data/local/hadith_data.dart';

final _selectedCategoryProvider = StateProvider<String>((ref) => 'الكل');

class HadithScreen extends ConsumerWidget {
  const HadithScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(_selectedCategoryProvider);
    final hadiths = HadithLocalDataSource.getByCategory(selectedCategory);
    final todayHadith = HadithLocalDataSource.getForDay(DateTime.now());
    final categories = HadithLocalDataSource.categories;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.format_quote_rounded,
                            size: 22, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text(
                          'أحاديث أهل البيت',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Daily hadith banner ──────────────────────────────────
                    _DailyHadithBanner(hadith: todayHadith),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Category pills ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = cat == selectedCategory;
                    return GestureDetector(
                      onTap: () => ref
                          .read(_selectedCategoryProvider.notifier)
                          .state = cat,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accent.withOpacity(0.2)
                              : AppColors.glassFill,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accent.withOpacity(0.6)
                                : AppColors.glassBorder,
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Hadiths list ─────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final hadith = hadiths[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _HadithCard(hadith: hadith)
                          .animate(delay: (index * 40).ms)
                          .fadeIn(duration: 220.ms),
                    );
                  },
                  childCount: hadiths.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyHadithBanner extends StatelessWidget {
  const _DailyHadithBanner({required this.hadith});
  final HadithModel hadith;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      showGlow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.today_rounded,
                        size: 12, color: AppColors.accent),
                    SizedBox(width: 4),
                    Text(
                      'حديث اليوم',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hadith.text,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 17,
              height: 1.9,
              color: AppColors.textArabic,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline_rounded,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hadith.narrator,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => showUniversalShareSheet(
                  context,
                  title: 'حديث اليوم',
                  body: hadith.text,
                  attribution: hadith.narrator,
                  sourceLabel: hadith.source,
                ),
                child: Icon(Icons.share_rounded,
                    size: 18, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HadithCard extends StatefulWidget {
  const _HadithCard({required this.hadith});
  final HadithModel hadith;

  @override
  State<_HadithCard> createState() => _HadithCardState();
}

class _HadithCardState extends State<_HadithCard> {
  late bool _isFavorite = HiveService.instance.getFavoriteHadithIds().contains(widget.hadith.id);

  void _toggleFavorite() {
    HapticFeedback.lightImpact();
    setState(() => _isFavorite = !_isFavorite);
    HiveService.instance.toggleFavoriteHadith(widget.hadith.id);
  }

  @override
  Widget build(BuildContext context) {
    final hadith = widget.hadith;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              hadith.category,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                color: AppColors.accentLight,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Hadith text
          SelectableText(
            hadith.text,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 16,
              height: 1.9,
              color: AppColors.textArabic,
            ),
          ),

          const SizedBox(height: 10),
          Divider(color: AppColors.glassBorder, height: 1),
          const SizedBox(height: 8),

          // Narrator + Source + actions
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hadith.narrator,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                    Text(
                      hadith.source,
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
                onTap: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(ClipboardData(
                    text:
                        '${hadith.text}\n\n— ${hadith.narrator}\n${hadith.source}',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم نسخ الحديث',
                          style: TextStyle(fontFamily: 'Cairo')),
                      duration: Duration(seconds: 2),
                      backgroundColor: AppColors.primaryMedium,
                    ),
                  );
                },
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.copy_rounded,
                      size: 16, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => showUniversalShareSheet(
                  context,
                  title: 'حديث شريف',
                  body: hadith.text,
                  attribution: hadith.narrator,
                  sourceLabel: hadith.source,
                ),
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.share_rounded,
                      size: 16, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _toggleFavorite,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 16,
                    color: _isFavorite ? AppColors.error : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
