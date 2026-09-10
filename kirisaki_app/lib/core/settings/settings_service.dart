import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局设置服务（主题模式等），SharedPreferencesAsync 持久化，
/// 平台缺失/IO 异常静默容错（同记录服务模式）。
class SettingsService extends ChangeNotifier {
  SettingsService();

  /// 全局共享实例。
  static final SettingsService instance = SettingsService();

  static const String themeModeKey = 'theme_mode';

  SharedPreferencesAsync? _prefs;
  ThemeMode _themeMode = ThemeMode.system;

  /// 当前主题模式（默认跟随系统）。
  ThemeMode get themeMode => _themeMode;

  SharedPreferencesAsync? get _ensurePrefs {
    try {
      return _prefs ??= SharedPreferencesAsync();
    } catch (_) {
      return null;
    }
  }

  /// 从持久化加载（幂等）。
  Future<void> load() async {
    final SharedPreferencesAsync? prefs = _ensurePrefs;
    if (prefs == null) {
      return;
    }
    try {
      final String? raw = await prefs.getString(themeModeKey);
      if (raw == null) {
        return;
      }
      _themeMode = ThemeMode.values.firstWhere(
        (ThemeMode m) => m.name == raw,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    } catch (_) {
      // 损坏数据容错。
    }
  }

  /// 设置主题模式并持久化（全局页面即时生效）。
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    final SharedPreferencesAsync? prefs = _ensurePrefs;
    if (prefs == null) {
      return;
    }
    try {
      await prefs.setString(themeModeKey, mode.name);
    } catch (_) {
      // IO 异常静默。
    }
  }
}
