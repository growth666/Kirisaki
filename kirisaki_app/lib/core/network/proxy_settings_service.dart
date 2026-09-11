import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局代理配置服务：代理地址/端口/启用开关，SharedPreferencesAsync 持久化
/// （重启不丢失），默认关闭（不影响原有逻辑）。
///
/// 说明：海外 booru 图源需配置代理才能正常访问；国内图源（推荐流、
/// 百度/必应聚合等）无需代理即可使用。Web 端浏览器 fetch 不支持系统
/// 代理，仍走 CORS 代理开关（SourceParseService.webCorsProxyEnabled）。
class ProxySettingsService extends ChangeNotifier {
  ProxySettingsService();

  /// 全局共享实例。
  static final ProxySettingsService instance = ProxySettingsService();

  static const String enabledKey = 'proxy_enabled';
  static const String hostKey = 'proxy_host';
  static const String portKey = 'proxy_port';

  SharedPreferencesAsync? _prefs;

  bool _enabled = false;
  String _host = '';
  int _port = 1080;

  /// 是否启用代理（默认关闭）。
  bool get enabled => _enabled;

  /// 代理地址（如 127.0.0.1）。
  String get host => _host;

  /// 代理端口。
  int get port => _port;

  /// 配置是否完整（启用且地址非空、端口合法）。
  bool get isValid => _host.trim().isNotEmpty && _port > 0 && _port <= 65535;

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
      _enabled = await prefs.getBool(enabledKey) ?? false;
      _host = await prefs.getString(hostKey) ?? '';
      _port = await prefs.getInt(portKey) ?? 1080;
      notifyListeners();
    } catch (_) {
      // 损坏数据容错。
    }
  }

  /// 保存配置（即存即生效 + 持久化）。
  Future<void> save({required bool enabled, required String host, required int port}) async {
    _enabled = enabled;
    _host = host.trim();
    _port = port;
    notifyListeners();
    final SharedPreferencesAsync? prefs = _ensurePrefs;
    if (prefs == null) {
      return;
    }
    try {
      await prefs.setBool(enabledKey, _enabled);
      await prefs.setString(hostKey, _host);
      await prefs.setInt(portKey, _port);
    } catch (_) {
      // IO 异常静默。
    }
  }
}
