import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局设置服务（主题模式等），SharedPreferencesAsync 持久化，
/// 平台缺失/IO 异常静默容错（同记录服务模式）。
class SettingsService extends ChangeNotifier {
  SettingsService();

  /// 全局共享实例。
  static final SettingsService instance = SettingsService();

  static const String themeModeKey = 'theme_mode';
  static const String downloadDirKey = 'download_dir';
  static const String showAdultContentKey = 'show_adult_content';
  static const String refreshRateKey = 'refresh_rate_mode';

  SharedPreferencesAsync? _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  String? _downloadDir;
  bool _showAdultContent = false;
  RefreshRateMode _refreshRateMode = RefreshRateMode.system;

  /// 当前主题模式（默认跟随系统）。
  ThemeMode get themeMode => _themeMode;

  /// 自定义下载位置（桌面为目录路径、Android 为 SAF tree URI；
  /// null = 系统默认下载目录）。Web 端无目录概念（下载时弹系统保存对话框）。
  String? get downloadDir => _downloadDir;
  bool get showAdultContent => _showAdultContent;
  RefreshRateMode get refreshRateMode => _refreshRateMode;

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
      if (raw != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (ThemeMode m) => m.name == raw,
          orElse: () => ThemeMode.system,
        );
      }
      // 下载位置独立于主题读取（主题未设置时同样要恢复）。
      _downloadDir = await prefs.getString(downloadDirKey);
      _showAdultContent = await prefs.getBool(showAdultContentKey) ?? false;
      final rawRefresh = await prefs.getString(refreshRateKey);
      _refreshRateMode = RefreshRateMode.values.firstWhere(
        (mode) => mode.name == rawRefresh,
        orElse: () => RefreshRateMode.system,
      );
      notifyListeners();
    } catch (_) {
      // 损坏数据容错。
    }
  }

  Future<void> setShowAdultContent(bool value) async {
    if (_showAdultContent == value) return;
    _showAdultContent = value;
    notifyListeners();
    final prefs = _ensurePrefs;
    if (prefs == null) return;
    try {
      await prefs.setBool(showAdultContentKey, value);
    } catch (_) {}
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

  /// 设置自定义下载位置并持久化。
  Future<void> setDownloadDir(String dir) async {
    _downloadDir = dir;
    notifyListeners();
    final SharedPreferencesAsync? prefs = _ensurePrefs;
    if (prefs == null) {
      return;
    }
    try {
      await prefs.setString(downloadDirKey, dir);
    } catch (_) {
      // IO 异常静默。
    }
  }

  /// 重置为系统默认下载位置（清空持久化值）。
  Future<void> resetDownloadDir() async {
    _downloadDir = null;
    notifyListeners();
    final SharedPreferencesAsync? prefs = _ensurePrefs;
    if (prefs == null) {
      return;
    }
    try {
      await prefs.remove(downloadDirKey);
    } catch (_) {
      // IO 异常静默。
    }
  }

  Future<void> setRefreshRateMode(RefreshRateMode mode) async {
    if (_refreshRateMode == mode) return;
    _refreshRateMode = mode;
    notifyListeners();
    try {
      await (_ensurePrefs)?.setString(refreshRateKey, mode.name);
    } catch (_) {}
  }
}

enum RefreshRateMode { system, standard, high }
