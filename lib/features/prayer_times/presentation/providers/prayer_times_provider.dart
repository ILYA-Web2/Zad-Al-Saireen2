import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../../../services/hive_service.dart';
import '../../data/repositories/prayer_times_repository_impl.dart';
import '../../domain/entities/prayer_times_entity.dart';

final prayerTimesRepositoryProvider =
    Provider<PrayerTimesRepositoryImpl>((ref) {
  return PrayerTimesRepositoryImpl(http.Client());
});

class PrayerTimesState {
  const PrayerTimesState({
    this.times,
    this.isLoading = false,
    this.error,
    this.now,
    this.locationLabel = '',
    this.useGps = true,
    this.manualCity = '',
  });

  final PrayerTimesEntity? times;
  final bool isLoading;
  final String? error;
  final DateTime? now;
  final String locationLabel;
  final bool useGps;
  final String manualCity;
  HijriInfo? get hijriDate => times == null
      ? null
      : HijriInfo(
          day: times!.hijriDay,
          monthAr: times!.hijriMonthAr,
          year: times!.hijriYear,
        );

  String get city => manualCity.isNotEmpty ? manualCity : locationLabel;
  String get country => "العراق";
  // Was a hardcoded `=> 0.0` stub before — paired with the screen's own
  // `if (state.qiblaDirection > 0)` guard, that meant the Qibla card
  // never rendered at all, for any user, ever. Now a real great-circle
  // bearing computed from whatever coordinates Aladhan resolved (works
  // for both GPS and manually-typed city). Null while no coordinates are
  // available yet (e.g. very first load) rather than a misleading 0.
  double? get qiblaDirection => times?.qiblaBearing;

  String get nextPrayerLabel {
    if (times == null || now == null) return '';
    return times!.nextPrayer(now!)?.name ?? 'انتهت أوقات اليوم';
  }

  String get timeUntilNext {
    if (times == null || now == null) return '';
    final dur = times!.timeUntilNextPrayer(now!);
    if (dur == null) return '';
    final h = dur.inHours.toString().padLeft(2, '0');
    final m = (dur.inMinutes % 60).toString().padLeft(2, '0');
    final s = (dur.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  PrayerTimesState copyWith({
    PrayerTimesEntity? times,
    bool? isLoading,
    String? error,
    // See the identical fix + explanation in HomeState.copyWith
    // (home_provider.dart). This one was the most severe instance of the
    // bug in the whole app: `_startClock()` calls `copyWith(now: ...)`
    // every single second, and without this flag that silently reset
    // `error` to null every second too — meaning a real fetch error
    // (bad GPS permission, failed API call, etc.) was wiped out within
    // ~1 second of being set, so it could never actually be seen or
    // rendered on screen.
    bool clearError = false,
    DateTime? now,
    String? locationLabel,
    bool? useGps,
    String? manualCity,
  }) {
    return PrayerTimesState(
      times: times ?? this.times,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      now: now ?? this.now,
      locationLabel: locationLabel ?? this.locationLabel,
      useGps: useGps ?? this.useGps,
      manualCity: manualCity ?? this.manualCity,
    );
  }
}

class PrayerTimesNotifier extends StateNotifier<PrayerTimesState> {
  PrayerTimesNotifier(this._repo) : super(const PrayerTimesState()) {
    _startClock();
    fetchByGps();
  }

  final PrayerTimesRepositoryImpl _repo;
  Timer? _clockTimer;

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) state = state.copyWith(now: DateTime.now());
    });
  }

  Future<void> fetchByGps() async {
    state = state.copyWith(isLoading: true, clearError: true, useGps: true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { await _fallbackToSavedOrDefault(); return; }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        await _fallbackToSavedOrDefault(); return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      await HiveService.instance.setSetting('last_lat', position.latitude);
      await HiveService.instance.setSetting('last_lon', position.longitude);
      final times = await _repo.fetchByCoordinates(
        latitude: position.latitude, longitude: position.longitude, cityName: 'موقعك الحالي',
      );
      state = state.copyWith(times: times, isLoading: false, now: DateTime.now(), locationLabel: 'موقعك الحالي');
    } catch (e) { await _fallbackToSavedOrDefault(); }
  }

  Future<void> fetchByCity(String city, String country) async {
    if (city.trim().isEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true, useGps: false, manualCity: city);
    try {
      final times = await _repo.fetchByCity(city: city, country: country);
      state = state.copyWith(times: times, isLoading: false, now: DateTime.now(), locationLabel: city);
    } catch (e) { state = state.copyWith(isLoading: false, error: e.toString()); }
  }

  Future<void> _fallbackToSavedOrDefault() async {
    try {
      final lat = HiveService.instance.getSetting<double>('last_lat');
      final lon = HiveService.instance.getSetting<double>('last_lon');
      if (lat != null && lon != null) {
        final times = await _repo.fetchByCoordinates(latitude: lat, longitude: lon, cityName: 'آخر موقع');
        state = state.copyWith(times: times, isLoading: false, now: DateTime.now(), locationLabel: 'آخر موقع');
      } else {
        final times = await _repo.fetchByCity(city: 'Karbala', country: 'Iraq');
        state = state.copyWith(times: times, isLoading: false, now: DateTime.now(), locationLabel: 'كربلاء المقدسة');
      }
    } catch (e) { state = state.copyWith(isLoading: false, error: e.toString()); }
  }

  @override
  void dispose() { _clockTimer?.cancel(); super.dispose(); }
}

// .autoDispose is essential here: PrayerTimesNotifier runs a
// Timer.periodic every second for as long as it's alive. Without
// autoDispose, a Riverpod provider stays alive for the entire app
// session once first read — meaning that 1-second timer (and the state
// rebuild it triggers) never stopped even after navigating away to a
// completely different screen, silently draining battery for the rest
// of the session. autoDispose lets it shut down (PrayerTimesNotifier's
// existing dispose() already cancels the timer) the moment the Prayer
// Times screen is no longer being watched by anyone.
final prayerTimesProvider = StateNotifierProvider.autoDispose<
    PrayerTimesNotifier, PrayerTimesState>((ref) {
  return PrayerTimesNotifier(ref.read(prayerTimesRepositoryProvider));
});


/// Small display-only wrapper around the Hijri fields already present on
/// [PrayerTimesEntity], used by the Hijri-date card.
class HijriInfo {
  const HijriInfo({required this.day, required this.monthAr, required this.year});
  final String day;
  final String monthAr;
  final String year;

  String get fullArabic => '$day $monthAr $year هـ';
}
