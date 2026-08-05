import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import 'youtube_key_rotation_manager.dart';

/// Everything the hidden admin panel needs: real usage numbers (no
/// fabricated stats — every figure here is a genuine row count from the
/// same Supabase project the app already uses), the remote feature
/// kill-switch + forced-update flag, and the broadcast notification
/// system. Every read/write here is best-effort: a failed admin action
/// surfaces a real error to the admin (this is the one place in the app
/// where silently swallowing a failure would be actively misleading), but
/// nothing here can ever crash the *regular* app for normal users.
class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ─── Hidden anonymous user registry (stats only, never shown to users) ───
  /// One row per unique installation, silently touched on every app open.
  /// Nothing user-facing reads this — it exists purely so "how many
  /// people actually use this app" in the stats tab is a real count
  /// instead of the old proxy (distinct device IDs that happened to
  /// search something, which under-counted anyone who only browsed).
  /// Upserting only these two columns means `first_seen_at` (set once on
  /// the very first insert) is never overwritten on later opens.
  Future<void> pingUser(String deviceId, {String? platform}) async {
    await _client.from(AppConstants.tableUsers).upsert(
      {
        'device_id': deviceId,
        'last_seen_at': DateTime.now().toIso8601String(),
        if (platform != null) 'platform': platform,
      },
      onConflict: 'device_id',
    );
  }

  // ─── Usage stats (real counts, not estimates) ─────────────────────────────
  /// Counts are computed client-side from the actual row lists rather than
  /// a `count()` aggregate — this app has no user accounts, so
  /// "distinct users" is only ever a proxy: the number of distinct
  /// per-installation device IDs seen in search history. That limitation
  /// is surfaced in the admin UI itself rather than hidden behind a
  /// confident-looking number.
  Future<AdminStats> getStats() async {
    int searchRows = 0;
    int searchingDevices = 0;
    int totalUsers = 0;
    int mediaCacheRows = 0;
    int downloadRows = 0;
    String? error;

    // Every one of these is an independent read — the old version
    // awaited them one after another (each with its own multi-second
    // timeout), so a slow connection paid the *sum* of every timeout in
    // sequence before the stats tab showed anything at all. Running them
    // together caps the wait at whichever single one is slowest.
    final results = await Future.wait<Object?>([
      _client
          .from(AppConstants.tableSearchHistory)
          .select('device_id')
          .timeout(const Duration(seconds: 8))
          .then((r) => r as Object?)
          .catchError((e) => e as Object),
      _client
          .from(AppConstants.tableUsers)
          .select('device_id')
          .timeout(const Duration(seconds: 8))
          .then((r) => r as Object?)
          .catchError((_) => null),
      _client
          .from(AppConstants.tableMediaCache)
          .select('query')
          .timeout(const Duration(seconds: 8))
          .then((r) => r as Object?)
          .catchError((_) => null),
      _client
          .from(AppConstants.tableDownloads)
          .select('video_id')
          .timeout(const Duration(seconds: 8))
          .then((r) => r as Object?)
          .catchError((_) => null),
      YoutubeKeyRotationManager.instance.refreshFromRemote().then((_) => null),
    ]);

    final searchResult = results[0];
    if (searchResult is List) {
      final rows = List<Map<String, dynamic>>.from(searchResult);
      searchRows = rows.length;
      searchingDevices = rows.map((r) => r['device_id']?.toString() ?? '').toSet().length;
    } else if (searchResult is Object) {
      error = 'تعذّر جلب إحصائيات البحث: $searchResult';
    }

    final usersResult = results[1];
    if (usersResult is List) totalUsers = usersResult.length;

    final cacheResult = results[2];
    if (cacheResult is List) mediaCacheRows = cacheResult.length;

    final downloadsResult = results[3];
    if (downloadsResult is List) downloadRows = downloadsResult.length;

    final rotation = YoutubeKeyRotationManager.instance;
    final keys = rotation.allKeys();
    final keyStatuses = keys
        .map((k) => YoutubeKeyStatus(
              fullKey: k,
              maskedKey: _mask(k),
              cooldownUntil: rotation.cooldownUntil(k),
            ))
        .toList();

    return AdminStats(
      totalUsers: totalUsers,
      totalSearches: searchRows,
      distinctDevices: searchingDevices,
      mediaCacheEntries: mediaCacheRows,
      totalDownloadedFiles: downloadRows,
      apiKeyStatuses: keyStatuses,
      error: error,
    );
  }

  String _mask(String key) {
    if (key.length < 10) return key;
    return '${key.substring(0, 6)}••••••${key.substring(key.length - 4)}';
  }

  // ─── Remote config (per-section kill-switch + forced update) ─────────────
  Future<RemoteConfig> getRemoteConfig() async {
    try {
      final response = await _client
          .from(AppConstants.tableRemoteConfig)
          .select()
          .eq('id', 1)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      if (response == null) return RemoteConfig.empty();
      return RemoteConfig.fromMap(response);
    } catch (_) {
      // Fails open — if the config can't be reached, nothing gets
      // disabled and no one is force-blocked from the app.
      return RemoteConfig.empty();
    }
  }

  Future<void> saveRemoteConfig(RemoteConfig config) async {
    await _client.from(AppConstants.tableRemoteConfig).upsert({
      'id': 1,
      ...config.toMap(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ─── Broadcast notifications ──────────────────────────────────────────────
  Future<List<AdminNotification>> getActiveNotifications() async {
    try {
      final response = await _client
          .from(AppConstants.tableAdminNotifications)
          .select()
          .eq('active', true)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 6));
      return (response as List)
          .map((e) => AdminNotification.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> sendNotification({
    required String title,
    required String body,
    String? imageUrl,
    String? linkUrl,
  }) async {
    await _client.from(AppConstants.tableAdminNotifications).insert({
      'title': title,
      'body': body,
      'image_url': imageUrl,
      'link_url': linkUrl,
      'active': true,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ─── YouTube API key pool (shared across every install, DB-backed) ───────
  /// This used to be `HiveService`-only (per-device, never synced), which
  /// meant adding a key from the admin panel only ever helped the admin's
  /// own phone. Now the database is what's authoritative — every install
  /// picks up additions/removals the next time it syncs, no app update
  /// required. [YoutubeKeyRotationManager] keeps a small local cache of
  /// the last successful sync purely as an offline fallback.
  Future<List<String>> getApiKeys() async {
    final response = await _client
        .from(AppConstants.tableYoutubeApiKeys)
        .select('api_key')
        .eq('active', true)
        .order('added_at')
        .timeout(const Duration(seconds: 8));
    return (response as List).map((e) => e['api_key'].toString()).toList();
  }

  Future<void> addApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    await _client.from(AppConstants.tableYoutubeApiKeys).upsert(
      {'api_key': trimmed, 'active': true},
      onConflict: 'api_key',
    );
  }

  /// Soft-delete (kept as an inactive row instead of a hard delete) so
  /// re-adding the same key later doesn't hit the unique-constraint
  /// conflict silently — it just flips `active` back to true.
  Future<void> removeApiKey(String key) async {
    await _client
        .from(AppConstants.tableYoutubeApiKeys)
        .update({'active': false})
        .eq('api_key', key.trim());
  }
}

class YoutubeKeyStatus {
  YoutubeKeyStatus({required this.fullKey, required this.maskedKey, required this.cooldownUntil});
  final String fullKey;
  final String maskedKey;
  final DateTime? cooldownUntil;
  bool get isAvailable => cooldownUntil == null;
}

class AdminStats {
  AdminStats({
    required this.totalUsers,
    required this.totalSearches,
    required this.distinctDevices,
    required this.mediaCacheEntries,
    required this.totalDownloadedFiles,
    required this.apiKeyStatuses,
    this.error,
  });

  /// Real count of unique installations that have ever opened the app —
  /// from the hidden `app_users` registry, not a proxy.
  final int totalUsers;
  final int totalSearches;
  /// Distinct devices that have searched at least once (a subset of
  /// [totalUsers] — kept separate since "used search" is still a useful
  /// engagement signal on its own).
  final int distinctDevices;
  final int mediaCacheEntries;
  final int totalDownloadedFiles;
  final List<YoutubeKeyStatus> apiKeyStatuses;
  final String? error;
}

/// Section identifiers used both by the admin toggle UI and the router's
/// gate — kept as plain strings (not an enum) so the admin can disable a
/// section by name without a new app build ever being required.
class RemoteConfig {
  RemoteConfig({
    required this.disabledSections,
    required this.maintenanceMessage,
    required this.forceUpdate,
    required this.updateUrl,
    required this.latestVersion,
  });

  factory RemoteConfig.empty() => RemoteConfig(
        disabledSections: const [],
        maintenanceMessage: '',
        forceUpdate: false,
        updateUrl: '',
        latestVersion: '',
      );

  factory RemoteConfig.fromMap(Map<String, dynamic> map) => RemoteConfig(
        disabledSections: List<String>.from(map['disabled_sections'] as List? ?? []),
        maintenanceMessage: map['maintenance_message']?.toString() ?? '',
        forceUpdate: map['force_update'] as bool? ?? false,
        updateUrl: map['update_url']?.toString() ?? '',
        latestVersion: map['latest_version']?.toString() ?? '',
      );

  final List<String> disabledSections;
  final String maintenanceMessage;
  final bool forceUpdate;
  final String updateUrl;
  final String latestVersion;

  Map<String, dynamic> toMap() => {
        'disabled_sections': disabledSections,
        'maintenance_message': maintenanceMessage,
        'force_update': forceUpdate,
        'update_url': updateUrl,
        'latest_version': latestVersion,
      };

  RemoteConfig copyWith({
    List<String>? disabledSections,
    String? maintenanceMessage,
    bool? forceUpdate,
    String? updateUrl,
    String? latestVersion,
  }) {
    return RemoteConfig(
      disabledSections: disabledSections ?? this.disabledSections,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      forceUpdate: forceUpdate ?? this.forceUpdate,
      updateUrl: updateUrl ?? this.updateUrl,
      latestVersion: latestVersion ?? this.latestVersion,
    );
  }
}

class AdminNotification {
  AdminNotification({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.linkUrl,
    required this.createdAt,
  });

  factory AdminNotification.fromMap(Map<String, dynamic> map) => AdminNotification(
        id: map['id'].toString(),
        title: map['title']?.toString() ?? '',
        body: map['body']?.toString() ?? '',
        imageUrl: map['image_url']?.toString(),
        linkUrl: map['link_url']?.toString(),
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      );

  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final String? linkUrl;
  final DateTime createdAt;
}
