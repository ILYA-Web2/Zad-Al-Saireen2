import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/universal_share_sheet.dart';
import '../../../../core/utils/hijri_date_converter.dart';
import '../../../../services/hive_service.dart';
import '../../data/local/shia_events_data.dart';
import '../../data/local/official_hijri_overrides.dart';

/// Combines three layers, most authoritative first:
/// 1. [OfficialHijriOverrides] — a real announced month start, when known.
/// 2. The user's own manual calibration nudge (already baked into
///    [HijriDate] itself).
/// 3. Pure arithmetic (the tabular/Kuwaiti calendar) as the ultimate
///    fallback, so the calendar always works fully offline even if no
///    override has ever been entered for the year in question.
class ResolvedHijriDate {
  const ResolvedHijriDate._();

  static DateTime firstDayOfMonth(int year, int month) {
    final override = OfficialHijriOverrides.monthStarts['$year-$month'];
    return override ?? HijriDate.toGregorian(year: year, month: month, day: 1);
  }

  static int daysInMonth(int year, int month) {
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final start = firstDayOfMonth(year, month);
    final nextStart = firstDayOfMonth(nextYear, nextMonth);
    return nextStart.difference(start).inDays;
  }

  /// The reverse: given any Gregorian date, which resolved Hijri
  /// (day, month, year) does it fall on — checking the override table
  /// for the arithmetic guess's month and its two neighbors (in case an
  /// override shifts a date across what arithmetic thought the month
  /// boundary was), falling back to pure arithmetic if nothing around
  /// there has an override.
  static HijriDate fromGregorian(DateTime date) {
    final guess = HijriDate.fromGregorian(date);
    for (final deltaMonth in [-1, 0, 1]) {
      var m = guess.month + deltaMonth;
      var y = guess.year;
      if (m == 0) {
        m = 12;
        y -= 1;
      } else if (m == 13) {
        m = 1;
        y += 1;
      }
      final start = firstDayOfMonth(y, m);
      final nextM = m == 12 ? 1 : m + 1;
      final nextY = m == 12 ? y + 1 : y;
      final end = firstDayOfMonth(nextY, nextM);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (!normalizedDate.isBefore(start) && normalizedDate.isBefore(end)) {
        return HijriDate(day: normalizedDate.difference(start).inDays + 1, month: m, year: y);
      }
    }
    return guess; // no override anywhere nearby — pure arithmetic
  }
}

// ─── Riverpod state ─────────────────────────────────────────────────────────
// Defaults to the real current Hijri month/year (fixed bug: this used to
// default to the *Gregorian* month number, which is meaningless for a
// Hijri calendar).
final _selectedMonthProvider =
    StateProvider<int>((ref) => ResolvedHijriDate.fromGregorian(DateTime.now()).month);
final _selectedYearProvider =
    StateProvider<int>((ref) => ResolvedHijriDate.fromGregorian(DateTime.now()).year);

// Bumped every time the calibration offset changes, purely so widgets that
// `ref.watch` it re-render — the actual value lives in the static
// [HijriDate.calibrationOffsetDays] field (see that class for why).
final _calibrationTickProvider = StateProvider<int>((ref) => 0);

const List<String> _weekDaysShort = ['سبت', 'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'];

class IslamicCalendarScreen extends ConsumerWidget {
  const IslamicCalendarScreen({super.key});

  static const Map<ShiaEventType, Color> _typeColors = {
    ShiaEventType.martyrdom: Color(0xFFEF5350),
    ShiaEventType.birthday: Color(0xFFEC407A),
    ShiaEventType.celebration: Color(0xFFFFB300),
    ShiaEventType.occasion: Color(0xFF00D4FF),
    ShiaEventType.sadness: Color(0xFF9E9E9E),
  };

  void _openCalibrationSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CalibrationSheet(),
    );
  }

  void _goToMonth(WidgetRef ref, {required int deltaMonths}) {
    var month = ref.read(_selectedMonthProvider) + deltaMonths;
    var year = ref.read(_selectedYearProvider);
    while (month > 12) {
      month -= 12;
      year += 1;
    }
    while (month < 1) {
      month += 12;
      year -= 1;
    }
    ref.read(_selectedMonthProvider.notifier).state = month;
    ref.read(_selectedYearProvider.notifier).state = year;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_calibrationTickProvider); // rebuild this whole tree on recalibration
    final selectedMonth = ref.watch(_selectedMonthProvider);
    final selectedYear = ref.watch(_selectedYearProvider);
    final events = ShiaEventsLocalDataSource.getEventsForMonth(selectedMonth);
    final monthName = ShiaEventsLocalDataSource.hijriMonthNames[selectedMonth - 1];

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    const SizedBox(width: 40), // balances the calibration icon on the other side
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 22, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text(
                            'التقويم الهجري',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _openCalibrationSheet(context, ref),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.glassFill,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.glassBorder, width: 1),
                        ),
                        child: Icon(Icons.tune_rounded, size: 18, color: AppColors.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Today (Hijri) + next occasion countdown ────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _TodayAndNextEventCard(typeColors: _typeColors),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Month/Year navigator ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavArrow(icon: Icons.chevron_right_rounded, onTap: () => _goToMonth(ref, deltaMonths: -1)),
                    Column(
                      children: [
                        Text(
                          monthName,
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        Text(
                          '$selectedYear هـ',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    _NavArrow(icon: Icons.chevron_left_rounded, onTap: () => _goToMonth(ref, deltaMonths: 1)),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Legend ───────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: ShiaEventType.values.map((type) {
                    return Container(
                      margin: const EdgeInsets.only(left: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: _typeColors[type] ?? AppColors.accent),
                          ),
                          const SizedBox(width: 4),
                          Text(type.label, style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // ── Full month grid (dual Hijri/Gregorian dates) ────────────────
            // Didn't exist before at all — the old screen only ever showed a
            // scrollable list of this month's occasions, with no actual
            // calendar grid, no Gregorian equivalent per day, and no way to
            // tap an arbitrary day to see what it corresponds to.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MonthGrid(
                  year: selectedYear,
                  month: selectedMonth,
                  events: events,
                  typeColors: _typeColors,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Events list (same month, full descriptions) ─────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'كل مناسبات $monthName',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
            ),
            if (events.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'لا توجد مناسبات مسجلة في هذا الشهر',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textMuted),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final color = _typeColors[event.type] ?? AppColors.accent;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _EventCard(event: event, color: color, year: selectedYear)
                          .animate(delay: (index * 55).ms)
                          .fadeIn(duration: 250.ms)
                          .slideX(begin: 0.05, end: 0),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
        child: Icon(icon, size: 18, color: AppColors.accent),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.year,
    required this.month,
    required this.events,
    required this.typeColors,
  });

  final int year;
  final int month;
  final List<ShiaEvent> events;
  final Map<ShiaEventType, Color> typeColors;

  @override
  Widget build(BuildContext context) {
    final daysCount = ResolvedHijriDate.daysInMonth(year, month);
    final firstDayGregorian = ResolvedHijriDate.firstDayOfMonth(year, month);
    // Arabic week convention: Saturday first, Friday last.
    final startOffset = (firstDayGregorian.weekday % 7 + 1) % 7;
    final todayHijri = ResolvedHijriDate.fromGregorian(DateTime.now());
    final eventsByDay = <int, ShiaEvent>{for (final e in events) e.day: e};

    return GlassContainer(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: _weekDaysShort
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d, style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.85,
            ),
            itemCount: startOffset + daysCount,
            itemBuilder: (context, index) {
              if (index < startOffset) return const SizedBox.shrink();
              final hDay = index - startOffset + 1;
              final gregorianDate = firstDayGregorian.add(Duration(days: hDay - 1));
              final event = eventsByDay[hDay];
              final isToday = todayHijri.year == year && todayHijri.month == month && todayHijri.day == hDay;
              final color = event != null ? (typeColors[event.type] ?? AppColors.accent) : null;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _DayDetailSheet(
                      hijriDay: hDay,
                      hijriMonth: month,
                      hijriYear: year,
                      gregorianDate: gregorianDate,
                      event: event,
                      eventColor: color,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: color != null ? color.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isToday ? AppColors.accent : (color?.withOpacity(0.4) ?? Colors.transparent),
                      width: isToday ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$hDay',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color ?? (isToday ? AppColors.accent : AppColors.textPrimary),
                        ),
                      ),
                      Text(
                        '${gregorianDate.day}/${gregorianDate.month}',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 8, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayDetailSheet extends StatelessWidget {
  const _DayDetailSheet({
    required this.hijriDay,
    required this.hijriMonth,
    required this.hijriYear,
    required this.gregorianDate,
    required this.event,
    required this.eventColor,
  });

  final int hijriDay;
  final int hijriMonth;
  final int hijriYear;
  final DateTime gregorianDate;
  final ShiaEvent? event;
  final Color? eventColor;

  static const _gregorianMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  @override
  Widget build(BuildContext context) {
    final monthName = ShiaEventsLocalDataSource.hijriMonthNames[hijriMonth - 1];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDeep,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.glassBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '$hijriDay $monthName $hijriYear هـ',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'الموافق ${gregorianDate.day} ${_gregorianMonths[gregorianDate.month - 1]} ${gregorianDate.year} م',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          if (event != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: eventColor?.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(event!.type.label, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: eventColor)),
            ),
            const SizedBox(height: 10),
            Text(
              event!.title,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.5),
            ),
            if (event!.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                event!.description,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary, height: 1.7),
              ),
            ],
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => showUniversalShareSheet(
                context,
                title: event!.title,
                body: event!.description.isNotEmpty
                    ? event!.description
                    : '$hijriDay $monthName $hijriYear هـ',
                sourceLabel: 'التقويم الهجري — $monthName $hijriYear هـ',
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.glassBorder, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share_rounded, size: 14, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text('مشاركة المناسبة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.accent)),
                  ],
                ),
              ),
            ),
          ] else
            Text(
              'لا توجد مناسبة مسجلة بهذا اليوم',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}

class _CalibrationSheet extends ConsumerStatefulWidget {
  const _CalibrationSheet();

  @override
  ConsumerState<_CalibrationSheet> createState() => _CalibrationSheetState();
}

class _CalibrationSheetState extends ConsumerState<_CalibrationSheet> {
  late int _offset = HijriDate.calibrationOffsetDays;

  void _apply(int newOffset) {
    setState(() => _offset = newOffset.clamp(-3, 3));
    HijriDate.calibrationOffsetDays = _offset;
    HiveService.instance.saveHijriCalibrationOffset(_offset);
    ref.read(_calibrationTickProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDeep,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('معايرة بداية الشهر الهجري',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Text(
            'هذا التقويم يعتمد حساباً فلكياً تقريبياً افتراضياً، ويُستبدَل '
            'تلقائياً بتاريخ حقيقي عند توفره في قاعدة بيانات التطبيق (تُحدَّث '
            'دورياً من إعلانات العتبات المقدسة). لحين توفر ذلك لشهر معيّن، '
            'استخدم هذا الضبط لمطابقة أي إعلان تعرفه بنفسك مؤقتاً.',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted, height: 1.7),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NavArrow(icon: Icons.remove_rounded, onTap: () => _apply(_offset - 1)),
              const SizedBox(width: 20),
              Text('${_offset >= 0 ? '+' : ''}$_offset يوم',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.accent)),
              const SizedBox(width: 20),
              _NavArrow(icon: Icons.add_rounded, onTap: () => _apply(_offset + 1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.color, required this.year});
  final ShiaEvent event;
  final Color color;
  final int year;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.4), width: 1.2),
            ),
            child: Center(
              child: Text(
                '${event.day}',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.4),
                ),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.description,
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted, height: 1.4),
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(event.type.label, style: TextStyle(fontFamily: 'Cairo', fontSize: 9, fontWeight: FontWeight.w600, color: color)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayAndNextEventCard extends StatelessWidget {
  const _TodayAndNextEventCard({required this.typeColors});
  final Map<ShiaEventType, Color> typeColors;

  @override
  Widget build(BuildContext context) {
    final today = ResolvedHijriDate.fromGregorian(DateTime.now());
    final monthName = today.month >= 1 && today.month <= 12
        ? ShiaEventsLocalDataSource.hijriMonthNames[today.month - 1]
        : '';
    final next = ShiaEventsLocalDataSource.getNextEvent(today.day, today.month);

    int? daysUntilNext;
    if (next != null) {
      final monthsAway = (next.month - today.month) % 12;
      daysUntilNext = monthsAway * 30 + (next.day - today.day);
      if (daysUntilNext < 0) daysUntilNext += 354;
    }

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      showGlow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.brightness_2_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'اليوم: ${today.day} $monthName ${today.year} هـ',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 10),
            Divider(color: AppColors.glassBorder, height: 1),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: typeColors[next.type], shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المناسبة القادمة', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        next.title,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      if (daysUntilNext != null && daysUntilNext > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('خلال ~$daysUntilNext يوم', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.accentLight)),
                        )
                      else if (daysUntilNext == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('اليوم', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
