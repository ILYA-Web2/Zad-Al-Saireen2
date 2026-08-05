import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/universal_share_sheet.dart';
import '../../../../services/hive_service.dart';
import '../../data/local/infallibles_data.dart';

class InfallibleDetailScreen extends StatefulWidget {
  const InfallibleDetailScreen({super.key, required this.entity});
  final InfallibleEntity entity;

  @override
  State<InfallibleDetailScreen> createState() => _InfallibleDetailScreenState();
}

class _InfallibleDetailScreenState extends State<InfallibleDetailScreen> {
  late bool _isBookmarked =
      HiveService.instance.getBookmarkedInfallibleIds().contains(widget.entity.id);
  double _bioFontSize = 17;

  void _toggleBookmark() {
    HapticFeedback.lightImpact();
    setState(() => _isBookmarked = !_isBookmarked);
    HiveService.instance.toggleBookmarkedInfallible(widget.entity.id);
  }

  void _share() {
    showUniversalShareSheet(
      context,
      title: widget.entity.name,
      body: widget.entity.bio,
      sourceLabel: widget.entity.epithet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final entity = widget.entity;
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Sticky header ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.backgroundDeep,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.glassFill,
                  border:
                      Border.all(color: AppColors.glassBorder, width: 1),
                ),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 18, color: AppColors.textSecondary),
              ),
            ),
            actions: [
              // Bookmark + share — didn't exist before at all.
              GestureDetector(
                onTap: _toggleBookmark,
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.glassFill,
                    border: Border.all(color: AppColors.glassBorder, width: 1),
                  ),
                  child: Icon(
                    _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    size: 18,
                    color: AppColors.accent,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _share,
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8, left: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.glassFill,
                    border: Border.all(color: AppColors.glassBorder, width: 1),
                  ),
                  child: Icon(Icons.share_rounded, size: 18, color: AppColors.textSecondary),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.accent.withOpacity(0.18),
                      AppColors.backgroundDeep,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withOpacity(0.15),
                            border: Border.all(
                                color: AppColors.accent.withOpacity(0.5),
                                width: 2),
                          ),
                          child: Icon(Icons.star_rounded,
                              size: 32, color: AppColors.accent),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          entity.name,
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          entity.epithet,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: AppColors.accentLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Vital info grid ─────────────────────────────────────────
                _SectionHeader(title: 'المعلومات الأساسية',
                    icon: Icons.info_outline_rounded),
                const SizedBox(height: 8),
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(label: 'الاسم الكامل', value: entity.name),
                      _InfoRow(label: 'اللقب / الكنية', value: entity.epithet),
                      _InfoRow(label: 'الأب', value: entity.fatherName),
                      _InfoRow(label: 'الأم', value: entity.mother),
                      _InfoRow(label: 'تاريخ الولادة', value: entity.birthDate),
                      _InfoRow(label: 'مكان الولادة', value: entity.birthPlace),
                      _InfoRow(
                          label: entity.martyr ? 'تاريخ الشهادة' : 'الوضع',
                          value: entity.martyr
                              ? entity.martyrdomDate
                              : 'في غيبة كبرى حتى الظهور المأمول'),
                      if (entity.martyr)
                        _InfoRow(
                            label: 'مكان الشهادة',
                            value: entity.martyrdomPlace),
                      if (entity.causeOfMartyrdom.isNotEmpty)
                        _InfoRow(
                            label: 'سبب الشهادة',
                            value: entity.causeOfMartyrdom,
                            isLast: true),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Biography ──────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _SectionHeader(
                          title: 'نبذة تاريخية',
                          icon: Icons.history_edu_rounded),
                    ),
                    // Font-size control — didn't exist before; the bio is
                    // often the longest text block on the whole screen.
                    _FontSizeButton(
                      icon: Icons.text_decrease_rounded,
                      onTap: () => setState(() => _bioFontSize = (_bioFontSize - 1).clamp(13, 24)),
                    ),
                    const SizedBox(width: 6),
                    _FontSizeButton(
                      icon: Icons.text_increase_rounded,
                      onTap: () => setState(() => _bioFontSize = (_bioFontSize + 1).clamp(13, 24)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GlassContainer(
                  padding: const EdgeInsets.all(18),
                  child: SelectableText(
                    entity.bio,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: _bioFontSize,
                      height: 2.0,
                      color: AppColors.textArabic,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Key Events (real connected timeline) ─────────────────────
                _SectionHeader(
                    title: 'أبرز المحطات',
                    icon: Icons.timeline_rounded),
                const SizedBox(height: 8),
                ...entity.keyEvents.asMap().entries.map((entry) {
                  final i = entry.key;
                  final event = entry.value;
                  final isLast = i == entity.keyEvents.length - 1;
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent.withOpacity(0.15),
                                border: Border.all(
                                    color: AppColors.accent.withOpacity(0.4),
                                    width: 1),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ),
                            // The connecting line that makes this an actual
                            // timeline instead of a plain numbered list.
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  color: AppColors.accent.withOpacity(0.25),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: GlassContainer(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                event,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 6),

                // ── Quotes ─────────────────────────────────────────────────
                _SectionHeader(
                    title: 'من أقواله الشريفة',
                    icon: Icons.format_quote_rounded),
                const SizedBox(height: 8),
                ...entity.quotes.map((quote) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => showUniversalShareSheet(
                          context,
                          title: 'من أقوال ${entity.name}',
                          body: quote,
                          attribution: entity.name,
                        ),
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          Clipboard.setData(ClipboardData(text: quote));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تم نسخ الاقتباس',
                                style: TextStyle(fontFamily: 'Cairo'),
                              ),
                              duration: Duration(seconds: 2),
                              backgroundColor: AppColors.primaryMedium,
                            ),
                          );
                        },
                        child: GlassContainer(
                          padding: const EdgeInsets.all(16),
                          showGlow: true,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 3,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  quote,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.textArabic,
                                    height: 1.8,
                                  ),
                                ),
                              ),
                              Icon(Icons.share_rounded, size: 14, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    )),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _FontSizeButton extends StatelessWidget {
  const _FontSizeButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
        child: Icon(icon, size: 16, color: AppColors.accent),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(color: AppColors.glassBorder, height: 1),
      ],
    );
  }
}
