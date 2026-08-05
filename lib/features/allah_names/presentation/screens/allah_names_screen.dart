import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/universal_share_sheet.dart';
import '../../data/local/allah_names_data.dart';

class AllahNamesScreen extends StatefulWidget {
  const AllahNamesScreen({super.key});

  @override
  State<AllahNamesScreen> createState() => _AllahNamesScreenState();
}

class _AllahNamesScreenState extends State<AllahNamesScreen> {
  String _query = '';
  int? _expandedIndex;

  List<AllahName> get _filtered {
    if (_query.isEmpty) return AllahNamesData.all;
    return AllahNamesData.all
        .where((n) =>
            n.name.contains(_query) ||
            n.meaning.contains(_query) ||
            n.transliteration.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final names = _filtered;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
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
                        child: Icon(Icons.auto_awesome_rounded,
                            size: 22, color: AppColors.accent),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'أسماء الله الحسنى',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'تسعة وتسعون اسماً',
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
                  const SizedBox(height: 14),

                  // ── Hadith banner ──────────────────────────────────────────
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    showGlow: true,
                    child: Text(
                      'إِنَّ لِلَّهِ تِسْعَةً وَتِسْعِينَ اسْمًا مِئَةً إِلَّا وَاحِدًا مَنْ أَحْصَاهَا دَخَلَ الْجَنَّةَ.',
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 14,
                        height: 1.8,
                        color: AppColors.textArabic,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Name of the Day ──────────────────────────────────────────
                  // Didn't exist before — a small daily touchpoint so the
                  // section offers something new each time you open the
                  // app, not just a static reference list. Deterministic
                  // by day-of-year (not random) so it stays the same all
                  // day and is the same for everyone on the same date.
                  _NameOfTheDayCard(
                    name: AllahNamesData.all[
                        DateTime.now().difference(DateTime(DateTime.now().year)).inDays %
                            AllahNamesData.all.length],
                  ),

                  const SizedBox(height: 12),

                  // ── Search ─────────────────────────────────────────────────
                  GlassContainer(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded,
                            size: 18, color: AppColors.textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            textDirection: TextDirection.rtl,
                            onChanged: (v) =>
                                setState(() => _query = v),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ابحث عن اسم...',
                              hintStyle: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        Text(
                          '${names.length}/99',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // ── Names grid / list ────────────────────────────────────────────
            Expanded(
              child: _query.isEmpty
                  ? _NamesGrid(names: names, expandedIndex: _expandedIndex,
                      onExpand: (i) => setState(() =>
                          _expandedIndex = _expandedIndex == i ? null : i))
                  : _NamesList(names: names),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Grid view (default — shows all 99) ────────────────────────────────────────
class _NameOfTheDayCard extends StatelessWidget {
  const _NameOfTheDayCard({required this.name});
  final AllahName name;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => _NameDetailSheet(name: name),
        );
      },
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        showGlow: true,
        child: Row(
          children: [
            Icon(Icons.wb_sunny_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اسم اليوم',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    '${name.name}  —  ${name.meaning}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _NamesGrid extends StatelessWidget {
  const _NamesGrid(
      {required this.names,
      required this.expandedIndex,
      required this.onExpand});
  final List<AllahName> names;
  final int? expandedIndex;
  final void Function(int) onExpand;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: names.length,
      itemBuilder: (context, index) {
        final name = names[index];
        final isExpanded = expandedIndex == index;
        return _NameTile(
          name: name,
          isExpanded: isExpanded,
          onTap: () => onExpand(index),
        ).animate(delay: (index * 15).ms).fadeIn(duration: 200.ms);
      },
    );
  }
}

class _NameTile extends StatelessWidget {
  const _NameTile(
      {required this.name,
      required this.isExpanded,
      required this.onTap});
  final AllahName name;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
        if (!isExpanded) {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => _NameDetailSheet(name: name),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isExpanded
              ? AppColors.accent.withOpacity(0.15)
              : AppColors.glassFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isExpanded
                ? AppColors.accent.withOpacity(0.5)
                : AppColors.glassBorder,
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${name.number}',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                name.meaning.split('—').first.trim(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 9,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search results list ───────────────────────────────────────────────────────
class _NamesList extends StatelessWidget {
  const _NamesList({required this.names});
  final List<AllahName> names;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: names.length,
      itemBuilder: (context, index) {
        final name = names[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => _NameDetailSheet(name: name),
            ),
            child: GlassContainer(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withOpacity(0.12),
                      border: Border.all(
                          color: AppColors.accent.withOpacity(0.3),
                          width: 1),
                    ),
                    child: Center(
                      child: Text(
                        '${name.number}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.name,
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          name.meaning.split('—').first.trim(),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left_rounded,
                      size: 18, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Name Detail Bottom Sheet ──────────────────────────────────────────────────
class _NameDetailSheet extends StatelessWidget {
  const _NameDetailSheet({required this.name});
  final AllahName name;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: AppColors.backgroundDeep,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(
            top: BorderSide(color: AppColors.glassBorder, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Large name
          Text(
            name.name,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              shadows: [
                Shadow(
                  color: AppColors.accentGlow,
                  blurRadius: 20,
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          Text(
            name.transliteration,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: AppColors.accentLight,
              letterSpacing: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          // Meaning
          GlassContainer(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المعنى',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name.meaning,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Reflection
          GlassContainer(
            padding: const EdgeInsets.all(14),
            child: Text(
              name.reflection,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 14,
                height: 1.8,
                color: AppColors.textArabic,
              ),
            ),
          ),

          const Spacer(),

          // Share button
          GestureDetector(
            onTap: () => showUniversalShareSheet(
              context,
              title: name.name,
              body: '${name.meaning}\n\n${name.reflection}',
              sourceLabel: 'من أسماء الله الحسنى',
            ),
            child: GlassContainer(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              showGlow: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.share_rounded, size: 16, color: AppColors.accent),
                  SizedBox(width: 8),
                  Text(
                    'مشاركة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
