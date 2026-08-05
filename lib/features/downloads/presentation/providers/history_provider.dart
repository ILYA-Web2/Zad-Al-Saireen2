import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/hive_service.dart';
import '../../data/models/history_model.dart';

class HistoryState {
  const HistoryState({this.entries = const [], this.isLoading = false});
  final List<HistoryEntry> entries;
  final bool isLoading;

  HistoryState copyWith({List<HistoryEntry>? entries, bool? isLoading}) {
    return HistoryState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  HistoryNotifier() : super(const HistoryState()) {
    load();
  }

  /// History is a nice-to-have record, never a requirement for playback to
  /// work — every method here swallows its own errors (e.g. local storage
  /// briefly unavailable) instead of letting them surface to whatever
  /// screen just started playing audio. A logging failure must never look
  /// like "playback stopped".
  void load() {
    try {
      state = state.copyWith(isLoading: true);
      final raw = HiveService.instance.getAllHistory();
      final entries = raw.map((m) => HistoryEntry.fromMap(m)).toList();
      state = state.copyWith(entries: entries, isLoading: false);
    } catch (e) {
      debugPrint('[HistoryNotifier] load failed — $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Logs (or bumps) a play event. Call this from any screen that starts
  /// playing Quran audio, a video, or a Dua. Never throws.
  Future<void> logPlay({
    required String id,
    required HistoryType type,
    required String title,
    required String subtitle,
    required String thumbnailUrl,
    required String route,
  }) async {
    try {
      final entry = HistoryEntry(
        id: id,
        type: type,
        title: title,
        subtitle: subtitle,
        thumbnailUrl: thumbnailUrl,
        route: route,
        playedAt: DateTime.now(),
      );
      await HiveService.instance.addHistoryEntry(id, entry.toMap());
      load();
    } catch (e) {
      debugPrint('[HistoryNotifier] logPlay failed — $e');
    }
  }

  Future<void> remove(String id) async {
    try {
      await HiveService.instance.removeHistoryEntry(id);
      load();
    } catch (e) {
      debugPrint('[HistoryNotifier] remove failed — $e');
    }
  }

  Future<void> clear() async {
    try {
      await HiveService.instance.clearHistory();
      load();
    } catch (e) {
      debugPrint('[HistoryNotifier] clear failed — $e');
    }
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier();
});
