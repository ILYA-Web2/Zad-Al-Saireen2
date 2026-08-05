import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/hive_service.dart';
import '../../data/models/tasbih_model.dart';

// ─── General (Free) Counter ───────────────────────────────────────────────────
class GeneralTasbihNotifier extends StateNotifier<int> {
  GeneralTasbihNotifier() : super(HiveService.instance.getTasbihCount());

  Future<void> increment() async {
    state = state + 1;
    await HiveService.instance.saveTasbihCount(state);
    await HiveService.instance.logTasbihActivity(1);
  }

  Future<void> reset() async {
    state = 0;
    await HiveService.instance.saveTasbihCount(0);
  }
}

final generalTasbihProvider =
    StateNotifierProvider<GeneralTasbihNotifier, int>((ref) {
  return GeneralTasbihNotifier();
});

// ─── Fatima's Tasbih (34 / 33 / 33) ────────────────────────────────────────────
class FatimaTasbihState {
  const FatimaTasbihState({
    this.phase = TasbihPhase.allahuAkbar,
    this.currentCount = 0,
    this.totalCompleted = 0,
    this.isCycleComplete = false,
  });

  final TasbihPhase phase;
  final int currentCount;
  final int totalCompleted;
  final bool isCycleComplete;

  double get progress => currentCount / phase.target;

  FatimaTasbihState copyWith({
    TasbihPhase? phase,
    int? currentCount,
    int? totalCompleted,
    bool? isCycleComplete,
  }) {
    return FatimaTasbihState(
      phase: phase ?? this.phase,
      currentCount: currentCount ?? this.currentCount,
      totalCompleted: totalCompleted ?? this.totalCompleted,
      isCycleComplete: isCycleComplete ?? this.isCycleComplete,
    );
  }
}

class FatimaTasbihNotifier extends StateNotifier<FatimaTasbihState> {
  // Was always `const FatimaTasbihState()` — meaning totalCompleted reset
  // to 0 every single time this provider was recreated (every app
  // restart, since it isn't autoDispose but also isn't kept across
  // process restarts). Now restores whatever was actually completed
  // before, same pattern as the general counter right above.
  FatimaTasbihNotifier()
      : super(FatimaTasbihState(totalCompleted: HiveService.instance.getFatimaTotalCompleted()));

  /// Returns true if a phase transition (haptic-distinct) just occurred.
  bool increment() {
    final newCount = state.currentCount + 1;
    unawaited(HiveService.instance.logTasbihActivity(1));

    if (newCount >= state.phase.target) {
      if (state.phase == TasbihPhase.subhanAllah) {
        // Full cycle completed (34 + 33 + 33 = 100)
        final total = state.totalCompleted + 1;
        state = state.copyWith(
          phase: TasbihPhase.allahuAkbar,
          currentCount: 0,
          totalCompleted: total,
          isCycleComplete: true,
        );
        unawaited(HiveService.instance.saveFatimaTotalCompleted(total));
      } else {
        state = state.copyWith(
          phase: state.phase.next,
          currentCount: 0,
          isCycleComplete: false,
        );
      }
      return true; // phase changed -> distinct haptic
    } else {
      state = state.copyWith(currentCount: newCount, isCycleComplete: false);
      return false;
    }
  }

  void reset() {
    // Resetting the in-progress cycle does NOT erase the historical
    // totalCompleted count — that's a lifetime achievement counter, not
    // part of the current cycle's progress.
    state = FatimaTasbihState(totalCompleted: state.totalCompleted);
  }
}

final fatimaTasbihProvider =
    StateNotifierProvider<FatimaTasbihNotifier, FatimaTasbihState>((ref) {
  return FatimaTasbihNotifier();
});

// ─── Active Tab ───────────────────────────────────────────────────────────────
final tasbihTabProvider = StateProvider<int>((ref) => 0);
