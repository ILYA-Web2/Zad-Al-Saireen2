import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/admin_service.dart';

/// Fetched once, in the background, right after `runApp()` — never awaited
/// during startup, so a slow/unreachable Supabase project can never delay
/// the splash screen. Starts "empty" (nothing disabled, no forced
/// update), which fails open: if this never loads, the app behaves
/// exactly as if there were no admin panel at all.
final remoteConfigProvider =
    StateNotifierProvider<RemoteConfigNotifier, RemoteConfig>(
  (ref) => RemoteConfigNotifier(),
);

class RemoteConfigNotifier extends StateNotifier<RemoteConfig> {
  RemoteConfigNotifier() : super(RemoteConfig.empty()) {
    refresh();
  }

  Future<void> refresh() async {
    final config = await AdminService.instance.getRemoteConfig();
    if (mounted) state = config;
  }

  bool isSectionDisabled(String sectionKey) => state.disabledSections.contains(sectionKey);
}
