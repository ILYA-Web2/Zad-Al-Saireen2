import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../services/hive_service.dart';
import '../../../../services/quran_reciter_service.dart';
import '../../data/repositories/quran_repository_impl.dart';
import '../../domain/entities/surah_entity.dart';
import '../../domain/repositories/quran_repository.dart';

// ─── Service / Repository Providers ────────────────────────────────────────────
final httpClientProvider = Provider<http.Client>((ref) => http.Client());

final quranRepositoryProvider = Provider<QuranRepository>((ref) {
  return QuranRepositoryImpl(ref.read(httpClientProvider));
});

/// Strips Arabic diacritics (fatha, kasra, damma, sukun, shadda, tanween,
/// etc.) from [text] — used both for search matching (so "الفاتحة" matches
/// "الفَاتِحَة") and for display (a plain Surah name reads more cleanly in
/// a list than one with full diacritical marks).
String stripArabicDiacritics(String text) {
  return text.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
}

// ─── Surah List State ──────────────────────────────────────────────────────────
class SurahListState {
  const SurahListState({
    this.surahs = const [],
    this.filteredSurahs = const [],
    this.isLoading = true,
    this.error,
    this.searchQuery = '',
    this.ayahSearchResults = const [],
    this.isSearchingAyahText = false,
  });

  final List<SurahEntity> surahs;
  final List<SurahEntity> filteredSurahs;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  // Full-text search across the entire Quran's wording (not just Surah
  // names/numbers) — the repository already had a working `searchAyahs()`
  // calling alquran.cloud's real search API, it just was never actually
  // wired up to anything in the UI until now.
  final List<AyahEntity> ayahSearchResults;
  final bool isSearchingAyahText;

  SurahListState copyWith({
    List<SurahEntity>? surahs,
    List<SurahEntity>? filteredSurahs,
    bool? isLoading,
    String? error,
    // See the fix + full explanation in HomeState.copyWith
    // (home_provider.dart) — without this flag, `search()` below (called
    // on every keystroke) silently wiped out any real load error, since
    // it never passes `error` itself.
    bool clearError = false,
    String? searchQuery,
    List<AyahEntity>? ayahSearchResults,
    bool? isSearchingAyahText,
  }) {
    return SurahListState(
      surahs: surahs ?? this.surahs,
      filteredSurahs: filteredSurahs ?? this.filteredSurahs,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      ayahSearchResults: ayahSearchResults ?? this.ayahSearchResults,
      isSearchingAyahText: isSearchingAyahText ?? this.isSearchingAyahText,
    );
  }
}

class SurahListNotifier extends StateNotifier<SurahListState> {
  SurahListNotifier(this._repository) : super(const SurahListState()) {
    loadSurahs();
  }

  final QuranRepository _repository;
  Timer? _ayahSearchDebounce;
  int _searchGeneration = 0;

  Future<void> loadSurahs() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final surahs = await _repository.getAllSurahs();
      state = state.copyWith(
        surahs: surahs,
        filteredSurahs: surahs,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void search(String query) {
    _ayahSearchDebounce?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      state = state.copyWith(
        filteredSurahs: state.surahs,
        searchQuery: '',
        ayahSearchResults: [],
        isSearchingAyahText: false,
      );
      return;
    }
    final normalized = stripArabicDiacritics(trimmed);
    final results = state.surahs.where((s) {
      return stripArabicDiacritics(s.name).contains(normalized) ||
          s.englishName.toLowerCase().contains(normalized.toLowerCase()) ||
          s.englishNameTranslation
              .toLowerCase()
              .contains(normalized.toLowerCase()) ||
          s.number.toString() == normalized;
    }).toList();
    state = state.copyWith(filteredSurahs: results, searchQuery: normalized, ayahSearchResults: []);

    // Full-text search across the actual Quran wording — separate from
    // the instant local Surah-name filter above, since it needs a real
    // network call. Debounced so it only fires ~500ms after typing
    // pauses, and only for 3+ characters (a 1-2 letter query would match
    // an enormous, useless number of Ayahs).
    if (trimmed.length < 3) return;
    final generation = ++_searchGeneration;
    _ayahSearchDebounce = Timer(const Duration(milliseconds: 500), () async {
      state = state.copyWith(isSearchingAyahText: true);
      try {
        final ayahResults = await _repository.searchAyahs(trimmed);
        // Drops a stale response if the user kept typing and a newer
        // search has since started — otherwise a slow older request
        // completing last could overwrite fresher results with old ones.
        if (generation == _searchGeneration) {
          state = state.copyWith(ayahSearchResults: ayahResults, isSearchingAyahText: false);
        }
      } catch (_) {
        if (generation == _searchGeneration) {
          state = state.copyWith(ayahSearchResults: [], isSearchingAyahText: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _ayahSearchDebounce?.cancel();
    super.dispose();
  }
}

final surahListProvider =
    StateNotifierProvider<SurahListNotifier, SurahListState>((ref) {
  return SurahListNotifier(ref.read(quranRepositoryProvider));
});

// ─── Reciter Selection ──────────────────────────────────────────────────────────
final reciterServiceProvider = Provider<QuranReciterService>((ref) {
  return QuranReciterService.instance;
});

/// The live (or cached/fallback) list of reciters — each with one
/// continuous audio file per Surah.
final reciterListProvider = FutureProvider<List<ReciterInfo>>((ref) async {
  return ref.read(reciterServiceProvider).getReciters();
});

class SelectedReciterNotifier extends StateNotifier<ReciterInfo?> {
  SelectedReciterNotifier(this._service) : super(null) {
    _restoreOrDefault();
  }

  final QuranReciterService _service;

  Future<void> _restoreOrDefault() async {
    final reciters = await _service.getReciters();
    if (reciters.isEmpty) return;
    final savedId = HiveService.instance.getSetting<int>('selected_reciter_id');
    if (savedId != null) {
      final saved = reciters.where((r) => r.id == savedId);
      if (saved.isNotEmpty) {
        state = saved.first;
        return;
      }
    }
    // No saved preference — default to a specifically verified-working
    // reciter (Mishari Alafasy) rather than whichever entry the live API
    // happens to list first, which could be any reciter, including one
    // with a poor-quality or unreliable recording.
    final knownGood = reciters.where(
      (r) => r.relativePath.contains('mishaari_raashid_al_3afaasee'),
    );
    state = knownGood.isNotEmpty ? knownGood.first : reciters.first;
  }

  void select(ReciterInfo reciter) {
    state = reciter;
    HiveService.instance.setSetting('selected_reciter_id', reciter.id);
  }
}

final selectedReciterProvider =
    StateNotifierProvider<SelectedReciterNotifier, ReciterInfo?>((ref) {
  return SelectedReciterNotifier(ref.read(reciterServiceProvider));
});

// ─── Surah Reader State ─────────────────────────────────────────────────────────
class SurahReaderState {
  const SurahReaderState({
    this.ayahs = const [],
    this.isLoading = true,
    this.error,
    this.fontSize = 22.0,
    this.lineHeight = 1.8,
  });

  final List<AyahEntity> ayahs;
  final bool isLoading;
  final String? error;
  final double fontSize;
  final double lineHeight;

  SurahReaderState copyWith({
    List<AyahEntity>? ayahs,
    bool? isLoading,
    String? error,
    // Same fix as SurahListState/HomeState/PrayerTimesState above —
    // without this, setFontSize()/setLineHeight() (called every time the
    // user drags the font-size slider) silently erased a real "failed to
    // load ayahs" error each time, since neither passes `error`.
    bool clearError = false,
    double? fontSize,
    double? lineHeight,
  }) {
    return SurahReaderState(
      ayahs: ayahs ?? this.ayahs,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }
}

class SurahReaderNotifier extends StateNotifier<SurahReaderState> {
  SurahReaderNotifier(this._repository, this.surahNumber)
      : super(SurahReaderState(
          fontSize: HiveService.instance.getFontSize(),
          lineHeight: HiveService.instance.getLineHeight(),
        )) {
    loadAyahs();
  }

  final QuranRepository _repository;
  final int surahNumber;

  Future<void> loadAyahs() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ayahs = await _repository.getSurahAyahs(surahNumber);
      state = state.copyWith(ayahs: ayahs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setFontSize(double size) async {
    await HiveService.instance.setFontSize(size);
    state = state.copyWith(fontSize: size);
  }

  Future<void> setLineHeight(double height) async {
    await HiveService.instance.setLineHeight(height);
    state = state.copyWith(lineHeight: height);
  }
}

final surahReaderProvider = StateNotifierProvider.family<SurahReaderNotifier,
    SurahReaderState, int>((ref, surahNumber) {
  return SurahReaderNotifier(ref.read(quranRepositoryProvider), surahNumber);
});
