import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/angular_frame.dart';
import '../../data/models/tasbih_model.dart';
import '../providers/tasbih_provider.dart';
import '../../../../services/hive_service.dart';

class TasbihScreen extends ConsumerWidget {
  const TasbihScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = ref.watch(tasbihTabProvider);

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // ── Tabs ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.glassFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.glassBorder, width: 1),
              ),
              child: Row(
                children: [
                  _TabButton(
                    label: 'التسبيح العام',
                    isSelected: tabIndex == 0,
                    onTap: () => ref.read(tasbihTabProvider.notifier).state = 0,
                  ),
                  _TabButton(
                    label: 'تسبيح الزهراء عليها السلام',
                    isSelected: tabIndex == 1,
                    onTap: () => ref.read(tasbihTabProvider.notifier).state = 1,
                  ),
                  _TabButton(
                    label: 'الإحصائيات',
                    isSelected: tabIndex == 2,
                    onTap: () => ref.read(tasbihTabProvider.notifier).state = 2,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Expanded(
            child: switch (tabIndex) {
              0 => const _GeneralTasbihView(),
              1 => const _FatimaTasbihView(),
              _ => const _TasbihStatsView(),
            },
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withOpacity(0.2) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? AppColors.accent : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── General Free Counter ──────────────────────────────────────────────────────
class _GeneralTasbihView extends ConsumerStatefulWidget {
  const _GeneralTasbihView();

  @override
  ConsumerState<_GeneralTasbihView> createState() =>
      _GeneralTasbihViewState();
}

class _GeneralTasbihViewState extends ConsumerState<_GeneralTasbihView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(generalTasbihProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            _pulseController.forward(from: 0).then((_) {
              _pulseController.reverse();
            });
            ref.read(generalTasbihProvider.notifier).increment();
          },
          child: AngularFrame(
            cornerSize: 20,
            padding: const EdgeInsets.all(14),
            child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 - (_pulseController.value * 0.05);
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: AppConstants.tasbihCircleSize,
              height: AppConstants.tasbihCircleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.tasbihIdleGradient,
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'اضغط للتسبيح',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: () {
            HapticFeedback.heavyImpact();
            ref.read(generalTasbihProvider.notifier).reset();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.glassBorder, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 16, color: AppColors.error),
                SizedBox(width: 8),
                Text(
                  'إعادة التصفير',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Fatima's Tasbih (34 / 33 / 33) ────────────────────────────────────────────
class _FatimaTasbihView extends ConsumerStatefulWidget {
  const _FatimaTasbihView();

  @override
  ConsumerState<_FatimaTasbihView> createState() => _FatimaTasbihViewState();
}

class _FatimaTasbihViewState extends ConsumerState<_FatimaTasbihView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onTap() {
    final notifier = ref.read(fatimaTasbihProvider.notifier);
    final phaseChanged = notifier.increment();

    if (phaseChanged) {
      // Distinct, stronger haptic for phase transitions
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    _pulseController.forward(from: 0).then((_) => _pulseController.reverse());
  }

  Gradient _gradientForPhase(TasbihPhase phase, bool isComplete) {
    if (isComplete) return AppColors.tasbihCompleteGradient;
    return AppColors.tasbihActiveGradient;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fatimaTasbihProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── Phase indicator pills ───────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: TasbihPhase.values.map((phase) {
            final isActive = state.phase == phase;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.accent.withOpacity(0.2)
                    : AppColors.glassFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive
                      ? AppColors.accent.withOpacity(0.6)
                      : AppColors.glassBorder,
                  width: 1.2,
                ),
              ),
              child: Text(
                '${phase.label} (${phase.target})',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? AppColors.accent : AppColors.textMuted,
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 32),

        // ── Counter Circle ───────────────────────────────────────────────────
        GestureDetector(
          onTap: _onTap,
          child: AngularFrame(
            cornerSize: 20,
            padding: const EdgeInsets.all(14),
            child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 - (_pulseController.value * 0.05);
              return Transform.scale(scale: scale, child: child);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: AppConstants.tasbihCircleSize,
                  height: AppConstants.tasbihCircleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        _gradientForPhase(state.phase, state.isCycleComplete),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: AppColors.glowShadow,
                  ),
                ),
                SizedBox(
                  width: AppConstants.tasbihCircleSize - 16,
                  height: AppConstants.tasbihCircleSize - 16,
                  child: CircularProgressIndicator(
                    value: state.progress,
                    strokeWidth: 5,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.accent),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.phase.label,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${state.currentCount} / ${state.phase.target}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 16, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                'دورات مكتملة: ${state.totalCompleted}',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        GestureDetector(
          onTap: () {
            HapticFeedback.heavyImpact();
            ref.read(fatimaTasbihProvider.notifier).reset();
          },
          child: Text(
            'إعادة من البداية',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: AppColors.error,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Stats (daily / weekly / monthly) ──────────────────────────────────────────
// Didn't exist at all before — every bead counted just vanished into a
// single running total with no sense of "how much did I do today / this
// week". Built on top of HiveService.logTasbihActivity(), which now
// records a per-day count every time either counter above increments.
class _TasbihStatsView extends StatelessWidget {
  const _TasbihStatsView();

  @override
  Widget build(BuildContext context) {
    final last30 = HiveService.instance.getTasbihActivityForLastDays(30);
    final last7 = last30.sublist(last30.length - 7);
    final today = last30.last;
    final thisWeek = last7.fold<int>(0, (a, b) => a + b);
    final thisMonth = last30.fold<int>(0, (a, b) => a + b);
    final maxInWeek = last7.isEmpty ? 1 : last7.reduce((a, b) => a > b ? a : b);

    final weekdayLabels = _lastNWeekdayLabels(7);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _StatCard(label: 'اليوم', value: today)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'هذا الأسبوع', value: thisWeek)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'هذا الشهر', value: thisMonth)),
            ],
          ),
          const SizedBox(height: 24),
          GlassContainer(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'آخر 7 أيام',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 110,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final value = last7[i];
                      final heightFraction = maxInWeek == 0 ? 0.0 : value / maxInWeek;
                      final isToday = i == 6;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                value > 0 ? '$value' : '',
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                height: 70 * heightFraction.clamp(0.04, 1.0),
                                decoration: BoxDecoration(
                                  color: isToday ? AppColors.accent : AppColors.accent.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                weekdayLabels[i],
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                                  color: isToday ? AppColors.accent : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  static List<String> _lastNWeekdayLabels(int n) {
    const arabicWeekdayShort = ['اثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'];
    final now = DateTime.now();
    return List.generate(n, (i) {
      final date = now.subtract(Duration(days: n - 1 - i));
      return arabicWeekdayShort[date.weekday - 1];
    });
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
