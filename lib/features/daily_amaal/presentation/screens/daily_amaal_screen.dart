import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../data/local/daily_amaal_data.dart';

class DailyAmaalScreen extends StatefulWidget {
  const DailyAmaalScreen({super.key});

  @override
  State<DailyAmaalScreen> createState() => _DailyAmaalScreenState();
}

class _DailyAmaalScreenState extends State<DailyAmaalScreen> {
  late DailyAmaalModel _todayAmaal;
  late int _selectedWeekday;

  @override
  void initState() {
    super.initState();
    _selectedWeekday = DateTime.now().weekday;
    _todayAmaal = DailyAmaalLocalDataSource.getForWeekday(_selectedWeekday);
  }

  void _selectDay(int weekday) {
    setState(() {
      _selectedWeekday = weekday;
      _todayAmaal = DailyAmaalLocalDataSource.getForWeekday(weekday);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                          child: Icon(Icons.check_circle_outline_rounded,
                              size: 22, color: AppColors.accent),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'أعمال اليوم',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'المستحبات والعبادات اليومية',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Day selector ─────────────────────────────────────────
                    SizedBox(
                      height: 52,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 7,
                        itemBuilder: (context, index) {
                          final weekday = index + 1;
                          final amaal = DailyAmaalLocalDataSource
                              .getForWeekday(weekday);
                          final isSelected = weekday == _selectedWeekday;
                          final isToday =
                              weekday == DateTime.now().weekday;
                          return GestureDetector(
                            onTap: () => _selectDay(weekday),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.accent.withOpacity(0.2)
                                    : AppColors.glassFill,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.accent.withOpacity(0.6)
                                      : isToday
                                          ? AppColors.success
                                              .withOpacity(0.5)
                                          : AppColors.glassBorder,
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    amaal.arabicDay,
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
                                  if (isToday)
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.success,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Dua of the day ──────────────────────────────────────────
                  _DuaSection(amaal: _todayAmaal),
                  const SizedBox(height: 16),

                  // ── Surah Recommendation ─────────────────────────────────
                  GlassContainer(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success.withOpacity(0.15),
                          ),
                          child: Icon(Icons.menu_book_rounded,
                              size: 18, color: AppColors.success),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'السورة المستحبة',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              _todayAmaal.surahRecommendation,
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 250.ms),

                  if (_todayAmaal.specialNote.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    GlassContainer(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _todayAmaal.specialNote,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Acts list ─────────────────────────────────────────────
                  const _SectionHeader('الأعمال المستحبة'),
                  const SizedBox(height: 10),
                  ..._todayAmaal.acts.asMap().entries.map((entry) {
                    final i = entry.key;
                    final act = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AmaalActCard(act: act, index: i)
                          .animate(delay: (i * 60).ms)
                          .fadeIn(duration: 220.ms)
                          .slideY(begin: 0.05, end: 0),
                    );
                  }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DuaSection extends StatelessWidget {
  const _DuaSection({required this.amaal});
  final DailyAmaalModel amaal;

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
              Icon(Icons.format_quote_rounded,
                  size: 16, color: AppColors.accent),
              SizedBox(width: 8),
              Text(
                'دعاء اليوم',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amaal.dua,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 16,
              height: 2.0,
              color: AppColors.textArabic,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmaalActCard extends StatefulWidget {
  const _AmaalActCard({required this.act, required this.index});
  final AmaalAct act;
  final int index;

  @override
  State<_AmaalActCard> createState() => _AmaalActCardState();
}

class _AmaalActCardState extends State<_AmaalActCard> {
  bool _done = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      showGlow: _done,
      glowColor: AppColors.success,
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _done = !_done),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _done
                        ? AppColors.success
                        : AppColors.glassFill,
                    border: Border.all(
                      color: _done
                          ? AppColors.success
                          : AppColors.glassBorder,
                      width: 1.5,
                    ),
                  ),
                  child: _done
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white)
                      : Center(
                          child: Text(
                            '${widget.index + 1}',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.act.title,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _done
                        ? AppColors.success
                        : AppColors.textPrimary,
                    decoration: _done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 10),
            Divider(color: AppColors.glassBorder, height: 1),
            const SizedBox(height: 10),
            Text(
              widget.act.description,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.success.withOpacity(0.25), width: 0.8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'الثواب: ${widget.act.reward}',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: AppColors.success,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
