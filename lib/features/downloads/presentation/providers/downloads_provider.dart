import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/hive_service.dart';
import '../../../../services/supabase_service.dart';
import '../../data/models/download_model.dart';

class DownloadsState {
  const DownloadsState({
    this.downloads = const [],
    this.isLoading = false,
    this.selectedCategory = DownloadCategory.audio,
    this.selectedKeys = const {},
  });

  final List<DownloadModel> downloads;
  final bool isLoading;
  final DownloadCategory selectedCategory;
  // Multi-select for bulk delete — didn't exist before at all, so
  // clearing several old downloads meant tapping the trash icon one at a
  // time, in and out of a rebuilding list, for however many items you had.
  final Set<String> selectedKeys;

  List<DownloadModel> get filtered =>
      downloads.where((d) => d.category == selectedCategory).toList();

  bool get isSelectionMode => selectedKeys.isNotEmpty;

  /// Total size across every download in every category — shown as a
  /// single at-a-glance number, since nothing on this screen previously
  /// told the user how much device storage all of this was actually
  /// using.
  int get totalSizeBytes => downloads.fold<int>(0, (sum, d) => sum + d.fileSizeBytes);

  String get formattedTotalSize {
    if (totalSizeBytes <= 0) return '0 م.ب';
    final mb = totalSizeBytes / (1024 * 1024);
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(2)} غ.ب';
    return '${mb.toStringAsFixed(1)} م.ب';
  }

  DownloadsState copyWith({
    List<DownloadModel>? downloads,
    bool? isLoading,
    DownloadCategory? selectedCategory,
    Set<String>? selectedKeys,
  }) {
    return DownloadsState(
      downloads: downloads ?? this.downloads,
      isLoading: isLoading ?? this.isLoading,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedKeys: selectedKeys ?? this.selectedKeys,
    );
  }
}

class DownloadsNotifier extends StateNotifier<DownloadsState> {
  DownloadsNotifier() : super(const DownloadsState()) {
    loadDownloads();
  }

  void loadDownloads() {
    state = state.copyWith(isLoading: true);
    final raw = HiveService.instance.getAllDownloads();
    final downloads = raw.map((m) => DownloadModel.fromMap(m)).toList();
    state = state.copyWith(downloads: downloads, isLoading: false);
  }

  Future<void> addDownload(DownloadModel download) async {
    await HiveService.instance.saveDownload(download.hiveKey, download.toMap());
    try {
      await SupabaseService.instance.saveDownload(download);
    } catch (_) {
      // Offline-safe: local storage already persisted
    }
    loadDownloads();
  }

  Future<void> removeDownload(DownloadModel download) async {
    await HiveService.instance.removeDownload(download.hiveKey);
    try {
      await SupabaseService.instance.removeDownload(download.videoId);
    } catch (_) {}
    loadDownloads();
  }

  void selectCategory(DownloadCategory category) {
    state = state.copyWith(selectedCategory: category);
  }

  bool isAlreadyDownloaded(String videoId) {
    return state.downloads.any((d) => d.videoId == videoId);
  }

  void toggleSelection(String hiveKey) {
    final updated = Set<String>.from(state.selectedKeys);
    if (!updated.add(hiveKey)) updated.remove(hiveKey);
    state = state.copyWith(selectedKeys: updated);
  }

  /// Selects or deselects every one of [keys] at once — used by "تحديد
  /// الكل" (select all) in the current tab.
  void setSelection(Iterable<String> keys, {required bool selected}) {
    final updated = Set<String>.from(state.selectedKeys);
    if (selected) {
      updated.addAll(keys);
    } else {
      updated.removeAll(keys);
    }
    state = state.copyWith(selectedKeys: updated);
  }

  void exitSelectionMode() {
    state = state.copyWith(selectedKeys: {});
  }

  /// Deletes every currently-selected download (bulk delete) — both from
  /// local storage and, best-effort, from the Supabase mirror. Each
  /// removal already independently fails-soft (see removeDownload above),
  /// so one bad entry can't stop the rest of the batch from being
  /// cleared.
  Future<void> deleteSelected() async {
    final toDelete = state.downloads.where((d) => state.selectedKeys.contains(d.hiveKey)).toList();
    for (final download in toDelete) {
      await HiveService.instance.removeDownload(download.hiveKey);
      try {
        await SupabaseService.instance.removeDownload(download.videoId);
      } catch (_) {}
    }
    state = state.copyWith(selectedKeys: {});
    loadDownloads();
  }
}

final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, DownloadsState>((ref) {
  return DownloadsNotifier();
});
