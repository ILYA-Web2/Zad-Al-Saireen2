import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../domain/entities/prayer_times_entity.dart';
import '../providers/prayer_times_provider.dart';

class PrayerTimesScreen extends ConsumerStatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  ConsumerState<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends ConsumerState<PrayerTimesScreen> {
  // `_now` used to be driven by its own local Timer.periodic(1s) calling
  // setState — completely redundant with prayerTimesProvider's own
  // 1-second clock timer, which already forces a rebuild of this screen
  // via ref.watch below. Having both meant this screen rebuilt twice a
  // second for no benefit. Now `_now` is just a read of whatever the
  // provider's own ticking clock last reported.
  DateTime _now = DateTime.now();

  String _formatCountdown(String prayerTime) {
    final parts = prayerTime.split(':');
    final target = DateTime(
      _now.year, _now.month, _now.day,
      int.parse(parts[0]), int.parse(parts[1]),
    );
    var diff = target.difference(_now);
    if (diff.isNegative) return '';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    return h > 0
        ? '${h}س ${m.toString().padLeft(2, '0')}د'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prayerTimesProvider);
    // The provider's own clock timer ticks `state.now` every second and
    // that rebuilds this widget already — just read it instead of running
    // a second, redundant timer here.
    _now = state.now ?? DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            children: [
              // ── Header + Hijri Date ───────────────────────────────────────
              _HijriDateCard(
                hijri: state.hijriDate,
                now: _now,
                city: state.city,
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              // ── City selector ─────────────────────────────────────────────
              _CitySelector(state: state),

              const SizedBox(height: 16),

              // ── Next prayer countdown ─────────────────────────────────────
              if (state.times != null)
                _NextPrayerCard(
                  timings: state.times!,
                  now: _now,
                  formatCountdown: _formatCountdown,
                ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              // ── Five prayers grid ─────────────────────────────────────────
              if (state.isLoading && state.times == null)
                Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              else if (state.error != null)
                _ErrorCard(
                    error: state.error!,
                    onRetry: () => ref
                        .read(prayerTimesProvider.notifier)
                        .fetchByCity(state.city, state.country))
              else if (state.times != null)
                _PrayersGrid(
                  timings: state.times!,
                  now: _now,
                ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              // ── Qibla direction card ──────────────────────────────────────
              // Was `if (state.qiblaDirection > 0)` against a permanently
              // hardcoded `0.0` — meaning this card could never render for
              // any user. Now qiblaDirection is nullable and only omitted
              // while real coordinates genuinely aren't available yet.
              if (state.qiblaDirection != null)
                _QiblaCard(direction: state.qiblaDirection!)
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Hijri Date Card ──────────────────────────────────────────────────────────
class _HijriDateCard extends StatelessWidget {
  const _HijriDateCard({required this.hijri, required this.now, required this.city});
  final HijriInfo? hijri;
  final DateTime now;
  final String city;

  @override
  Widget build(BuildContext context) {
    final weekdays = ['الإثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
    final weekday = weekdays[(now.weekday - 1) % 7];
    final months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      showGlow: true,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$weekday، ${now.day} ${months[now.month - 1]} ${now.year}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hijri?.fullArabic ?? '...',
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.location_on_rounded,
                        size: 14, color: AppColors.accent),
                    Text(
                      city,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── City Selector ────────────────────────────────────────────────────────────
class _CitySelector extends ConsumerWidget {
  const _CitySelector({required this.state});
  final PrayerTimesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showCityPicker(context, ref),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.location_city_rounded,
                      size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'المدينة: ${state.city}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded,
                      size: 16, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(prayerTimesProvider.notifier).fetchByGps();
          },
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            showGlow: state.useGps,
            child: state.isLoading && state.useGps
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                : Row(
                    children: [
                      Icon(Icons.my_location_rounded,
                          size: 16,
                          color: state.useGps
                              ? AppColors.accent
                              : AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'GPS',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: state.useGps
                              ? AppColors.accent
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  void _showCityPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CityPickerSheet(
        onSelect: (city, country) {
          ref.read(prayerTimesProvider.notifier).fetchByCity(city, country);
        },
      ),
    );
  }
}

class _CityPickerSheet extends StatelessWidget {
  static const List<Map<String, String>> iraqiCities = [
        {"city": "البصرة", "country": "العراق"},
        {"city": "بغداد", "country": "العراق"},
        {"city": "النجف", "country": "العراق"},
        {"city": "كربلاء", "country": "العراق"},
        {"city": "الموصل", "country": "العراق"},
        {"city": "ميسان", "country": "العراق"},
        {"city": "ذي قار", "country": "العراق"}
      ];

  const _CityPickerSheet({required this.onSelect});
  final void Function(String city, String country) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: AppColors.backgroundDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
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
          const SizedBox(height: 16),
          Text(
            'اختر مدينتك',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: iraqiCities.length,
              itemBuilder: (context, index) {
                final c = iraqiCities[index];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(c['city']!, c['country']!);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mosque_rounded,
                            size: 16, color: AppColors.accent),
                        const SizedBox(width: 12),
                        Text(
                          '${c['city']} — ${c['country']}',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Next Prayer Countdown ────────────────────────────────────────────────────
class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard({
    required this.timings,
    required this.now,
    required this.formatCountdown,
  });
  final PrayerTimesEntity timings;
  final DateTime now;
  final String Function(String) formatCountdown;

  @override
  Widget build(BuildContext context) {
    final next = timings.nextPrayer(now);
    if (next == null) return const SizedBox.shrink();

    final countdown = formatCountdown(next.time);

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      showGlow: true,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withOpacity(0.2),
              border: Border.all(color: AppColors.accent.withOpacity(0.5)),
            ),
            child: Icon(Icons.access_time_rounded,
                color: AppColors.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الصلاة القادمة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  next.name,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                next.time,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
              if (countdown.isNotEmpty)
                Text(
                  'بعد $countdown',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Five Prayers Grid ────────────────────────────────────────────────────────
class _PrayersGrid extends StatelessWidget {
  const _PrayersGrid({required this.timings, required this.now});
  final PrayerTimesEntity timings;
  final DateTime now;

  bool _isPast(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return false;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final t = DateTime(now.year, now.month, now.day, h, m);
    return t.isBefore(now);
  }

  @override
  Widget build(BuildContext context) {
    // Shia jurisprudence observes five daily prayers — exclude the purely
    // informational Sunrise / Midnight markers from this grid.
    final prayers = timings.allPrayers
        .where((p) => p.name != 'الشروق' && p.name != 'منتصف الليل')
        .toList();
    return Column(
      children: prayers.asMap().entries.map((entry) {
        final i = entry.key;
        final prayer = entry.value;
        final past = _isPast(prayer.time);
        final isNext = timings.nextPrayer(now)?.name == prayer.name;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            showGlow: isNext,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isNext
                        ? AppColors.accent.withOpacity(0.25)
                        : past
                            ? AppColors.success.withOpacity(0.12)
                            : AppColors.glassFill,
                    border: Border.all(
                      color: isNext
                          ? AppColors.accent.withOpacity(0.6)
                          : past
                              ? AppColors.success.withOpacity(0.4)
                              : AppColors.glassBorder,
                    ),
                  ),
                  child: Center(
                    child: past
                        ? Icon(Icons.check_rounded,
                            size: 18, color: AppColors.success)
                        : Icon(
                            _prayerIcon(i),
                            size: 18,
                            color: isNext
                                ? AppColors.accent
                                : AppColors.textMuted,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    prayer.name,
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 18,
                      fontWeight: isNext ? FontWeight.w700 : FontWeight.w400,
                      color: isNext
                          ? AppColors.textPrimary
                          : past
                              ? AppColors.textMuted
                              : AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  prayer.time,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isNext
                        ? AppColors.accent
                        : past
                            ? AppColors.textMuted
                            : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ).animate(delay: (i * 60).ms).fadeIn(duration: 250.ms).slideX(begin: 0.05);
      }).toList(),
    );
  }

  IconData _prayerIcon(int index) {
    const icons = [
      Icons.nights_stay_rounded,
      Icons.wb_sunny_rounded,
      Icons.wb_cloudy_rounded,
      Icons.wb_twilight_rounded,
      Icons.dark_mode_rounded,
    ];
    return icons[index % icons.length];
  }
}

// ─── Qibla Card ───────────────────────────────────────────────────────────────
class _QiblaCard extends StatelessWidget {
  const _QiblaCard({required this.direction});
  final double direction;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'اتجاه القبلة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.glassBorder, width: 1.5),
                  ),
                ),
                Transform.rotate(
                  angle: (direction * math.pi) / 180.0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.navigation_rounded,
                          color: AppColors.accent, size: 40),
                      Text(
                        'الكعبة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${direction.toStringAsFixed(1)}° من الشمال',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 36, color: AppColors.error),
          const SizedBox(height: 8),
          Text(
            'تعذّر تحميل أوقات الصلاة',
            style: TextStyle(
                fontFamily: 'Cairo',
                color: AppColors.textSecondary,
                fontSize: 14),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'إعادة المحاولة',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.accent,
                    fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
