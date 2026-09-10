import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 搜索历史服务：记录/删除/清空/跨页快速搜索，
/// 去重保留最新、最新在前、上限 [maxEntries]，SharedPreferencesAsync 持久化。
///
/// [select] 触发「快速搜索」事件：SearchPage 与 HomeShell 监听
/// 本服务，收到后自动执行搜索并切回主页 tab。
class SearchHistoryService extends ChangeNotifier {
  SearchHistoryService();

  /// 全局共享实例。
  static final SearchHistoryService instance = SearchHistoryService();

  static const String storageKey = 'search_history';
  static const int maxEntries = 50;

  SharedPreferencesAsync? _prefs;
  final List<String> _keywords = <String>[];
  bool _loaded = false;
  String? _selectedKeyword;

  /// 搜索历史（最新在前，只读视图）。
  List<String> get keywords => List<String>.unmodifiable(_keywords);

  /// 最近一次被选中的关键词（快速搜索事件负载）。
  String? get selectedKeyword => _selectedKeyword;

  SharedPreferencesAsync? get _ensurePrefs {
    try {
      return _prefs ??= SharedPreferencesAsync();
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    final SharedPreferencesAsync? prefs = _ensurePrefs;
    if (prefs == null) {
      return;
    }
    try {
      final String? raw = await prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is List<Object?>) {
        _keywords
          ..clear()
          ..addAll(decoded.map((Object? k) => '$k'));
        notifyListeners();
      }
    } catch (_) {
      // 损坏数据容错：保持内存现状。
    }
  }

  /// 记录一次搜索（trim 后去重，移到最前）。
  Future<void> add(String keyword) async {
    final String k = keyword.trim();
    if (k.isEmpty) {
      return;
    }
    _keywords.remove(k);
    _keywords.insert(0, k);
    if (_keywords.length > maxEntries) {
      _keywords.removeRange(maxEntries, _keywords.length);
    }
    notifyListeners();
    await _persist();
  }

  /// 删除单条。
  Future<void> remove(String keyword) async {
    if (!_keywords.remove(keyword)) {
      return;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    if (_keywords.isEmpty) {
      return;
    }
    _keywords.clear();
    notifyListeners();
    await _persist();
  }

  /// 触发快速搜索：记录负载并通知监听者（SearchPage/HomeShell）。
  Future<void> select(String keyword) async {
    _selectedKeyword = keyword;
    notifyListeners();
  }

  /// 快速搜索已被消费（SearchPage 处理后复位）。
  void consumeSelection() {
    if (_selectedKeyword == null) {
      return;
    }
    _selectedKeyword = null;
    notifyListeners();
  }

  Future<void> _persist() async {
    final SharedPreferencesAsync? prefs = _ensurePrefs;
    if (prefs == null) {
      return;
    }
    try {
      await prefs.setString(storageKey, jsonEncode(_keywords));
    } catch (_) {
      // IO 异常静默：下次写入重试。
    }
  }
}
