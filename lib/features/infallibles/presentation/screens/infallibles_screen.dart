import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/universal_share_sheet.dart';
import '../../../../services/hive_service.dart';
import '../../data/local/infallibles_data.dart';
import 'infallible_detail_screen.dart';

class InfalliblesScreen extends StatefulWidget {
  const InfalliblesScreen({super.key});

  @override
  State<InfalliblesScreen> createState() => _InfalliblesScreenState();
}

class _InfalliblesScreenState extends State<InfalliblesScreen> {
  String _query = '';
  bool _showBookmarkedOnly = false;

  // A different quote each day (deterministic, not random) — picked from
  // whichever Infallible's quote list lands on today's index. Gives this
  // screen something fresh on repeat visits instead of being purely a
  // static reference list every single time.
  ({String name, String quote}) get _quoteOfTheDay {
    final all = InfalliblesLocalDataSource.all;
    final dayIndex = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    final person = all[dayIndex % all.length];
    if (person.quotes.isEmpty) {
      return (name: person.name, quote: '');
    }
    final quote = person.quotes[dayIndex % person.quotes.length];
    return (name: person.name, quote: quote);
  }

  List<InfallibleEntity> get _filtered {
    var list = InfalliblesLocalDataSource.all;
    if (_showBookmarkedOnly) {
      final bookmarks = HiveService.instance.getBookmarkedInfallibleIds();
      list = list.where((e) => bookmarks.contains(e.id)).toList();
    }
    final q = _query.trim();
    if (q.isEmpty) return list;
    return list.where((e) {
      return e.name.contains(q) || e.title.contains(q) || e.epithet.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = _filtered;
    final quote = _quoteOfTheDay;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withOpacity(0.15),
                            border: Border.all(
                                color: AppColors.accent.withOpacity(0.4),
                                width: 1.2),
                          ),
                          child: Icon(Icons.star_outline_rounded,
                              size: 22, color: AppColors.accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المعصومون الأربعة عشر',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'عليهم أفضل الصلاة والسلام',
                                style: TextStyle(
                                  fontFamily: 'Amiri',
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Bookmarks-only filter toggle — didn't exist before.
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _showBookmarkedOnly = !_showBookmarkedOnly);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _showBookmarkedOnly ? AppColors.accent.withOpacity(0.2) : AppColors.glassFill,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _showBookmarkedOnly ? AppColors.accent.withOpacity(0.6) : AppColors.glassBorder,
                              ),
                            ),
                            child: Icon(
                              _showBookmarkedOnly ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              size: 18,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Quote of the Day ─────────────────────────────────────
                    // Didn't exist before — the rich `quotes` list on every
                    // single entity was stored but never surfaced anywhere.
                    if (quote.quote.isNotEmpty)
                      GestureDetector(
                        onTap: () => showUniversalShareSheet(
                          context,
                          title: 'اقتباس اليوم',
                          body: quote.quote,
                          attribution: quote.name,
                        ),
                        child: GlassContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          showGlow: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.format_quote_rounded, size: 14, color: AppColors.accent),
                                  const SizedBox(width: 6),
                                  Text('اقتباس اليوم', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted)),
                                  const Spacer(),
                                  Icon(Icons.share_rounded, size: 14, color: AppColors.textMuted),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                quote.quote,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(fontFamily: 'Amiri', fontSize: 14, color: AppColors.textSecondary, height: 1.7),
                              ),
                              const SizedBox(height: 6),
                              Text('— ${quote.name}',
                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentLight)),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // ── Search ────────────────────────────────────────────────
                    // Didn't exist before — the only way to find a specific
                    // Infallible was scrolling through all 14 by hand.
                    GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              textDirection: TextDirection.rtl,
                              onChanged: (v) => setState(() => _query = v),
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'ابحث بالاسم أو اللقب...',
                                hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (all.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      _showBookmarkedOnly ? 'لا توجد عناصر محفوظة بعد' : 'لا نتائج مطابقة',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textMuted),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entity = all[index];
                      final originalIndex = InfalliblesLocalDataSource.all.indexOf(entity);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _InfallibleCard(
                          entity: entity,
                          index: originalIndex,
                        )
                            .animate(delay: (index * 55).ms)
                            .fadeIn(duration: 280.ms)
                            .slideX(begin: 0.05, end: 0),
                      );
                    },
                    childCount: all.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfallibleCard extends StatelessWidget {
  const _InfallibleCard({required this.entity, required this.index});
  final InfallibleEntity entity;
  final int index;

  static const List<Color> _accentColors = [
    Color(0xFF4A90E2),
    Color(0xFF27AE60),
    Color(0xFFE67E22),
    Color(0xFF8E44AD),
    Color(0xFFC0392B),
    Color(0xFF2980B9),
    Color(0xFF16A085),
    Color(0xFF2C3E50),
    Color(0xFFD35400),
    Color(0xFF1ABC9C),
    Color(0xFF8E44AD),
    Color(0xFFE74C3C),
    Color(0xFF3498DB),
    Color(0xFFF39C12),
  ];

  Color get _color => _accentColors[index % _accentColors.length];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InfallibleDetailScreen(entity: entity),
        ),
      ),
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Rank circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _color.withOpacity(0.15),
                border: Border.all(color: _color.withOpacity(0.5), width: 1.5),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _color,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entity.name,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entity.title,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _InfoChip(
                        label: entity.birthDate.split(' ').take(3).join(' '),
                        icon: Icons.circle_outlined,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      if (entity.martyr)
                        _InfoChip(
                          label: 'شهيد',
                          icon: Icons.shield_rounded,
                          color: AppColors.error,
                        )
                      else
                        _InfoChip(
                          label: 'غائب',
                          icon: Icons.hourglass_empty_rounded,
                          color: AppColors.accent,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Epithet tag
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _color.withOpacity(0.35), width: 0.8),
                  ),
                  child: Text(
                    entity.epithet.split(' / ').first,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _color,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (HiveService.instance.getBookmarkedInfallibleIds().contains(entity.id))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.bookmark_rounded, size: 14, color: AppColors.accent),
                  ),
                Icon(Icons.chevron_left_rounded,
                    size: 18, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(
      {required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 9,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
