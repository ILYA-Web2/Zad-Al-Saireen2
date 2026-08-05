import 'package:flutter/material.dart';
import '../../services/hive_service.dart';
import 'app_theme_definition.dart';

/// Manages which of the 4 themes (see app_theme_definition.dart) is
/// active — a single, globally-observable source of truth. [AppColors]'s
/// getters read [definition] directly (no BuildContext needed, since
/// dozens of call-sites across the app reference `AppColors.xyz` as a
/// plain static value rather than through a widget tree), while the root
/// [MaterialApp] listens to this same controller via [ThemeController]
/// being a [ChangeNotifier], so both stay perfectly in sync.
class ThemeController extends ChangeNotifier {
  ThemeController._() {
    _theme = _themeFromName(HiveService.instance.getAppThemeName());
    _followSystem = HiveService.instance.getSetting<bool>('theme_follow_system') ?? false;
  }
  static final ThemeController instance = ThemeController._();

  static AppTheme _themeFromName(String name) {
    return AppTheme.values.firstWhere(
      (t) => t.name == name,
      orElse: () => AppTheme.layl,
    );
  }

  late AppTheme _theme;
  late bool _followSystem;

  /// The actual current platform brightness, used only when
  /// [followSystem] is true — updated by the root widget whenever
  /// `MediaQuery.platformBrightnessOf` changes, since this static
  /// controller has no BuildContext of its own to read it from directly.
  Brightness _systemBrightness = Brightness.dark;

  /// The theme actually in effect right now — if [followSystem] is on,
  /// this follows the device's own light/dark setting (mapped to ليل for
  /// dark, فجر for light) regardless of [selectedTheme]; otherwise it's
  /// exactly [selectedTheme].
  AppTheme get theme {
    if (_followSystem) {
      return _systemBrightness == Brightness.dark ? AppTheme.layl : AppTheme.fajr;
    }
    return _theme;
  }

  /// The theme explicitly picked in Settings, independent of whether
  /// "follow system" is currently overriding it — the theme picker UI
  /// should highlight this one as selected, not [theme].
  AppTheme get selectedTheme => _theme;

  bool get followSystem => _followSystem;

  ThemeDefinition get definition => theme.definition;

  /// Kept for the handful of call sites (chart/status-bar brightness
  /// logic) that only ever needed a plain dark/light boolean rather than
  /// the full theme identity.
  bool get isDark => definition.isDark;

  void setTheme(AppTheme newTheme) {
    _followSystem = false;
    HiveService.instance.setSetting('theme_follow_system', false);
    if (_theme == newTheme) {
      notifyListeners();
      return;
    }
    _theme = newTheme;
    HiveService.instance.setAppThemeName(newTheme.name);
    notifyListeners();
  }

  void setFollowSystem(bool value) {
    if (_followSystem == value) return;
    _followSystem = value;
    HiveService.instance.setSetting('theme_follow_system', value);
    notifyListeners();
  }

  void updateSystemBrightness(Brightness brightness) {
    if (_systemBrightness == brightness) return;
    _systemBrightness = brightness;
    if (_followSystem) notifyListeners();
  }
}
