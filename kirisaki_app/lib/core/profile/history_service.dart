import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../source/image_item.dart';

/// 浏览历史服务：每次打开大图预览自动记录，去重保留最新，
/// 最新在前、上限 [maxEntries]，SharedPreferencesAsync 持久化。
///
/// 平台通道缺失/IO 异常全部静默容错（内存操作不受影响），
/// 保证既有页面测试无需平台 mock 也可运行。
class HistoryService extends ChangeNotifier {
  HistoryService();

  /// 全局共享实例。
  static final HistoryService instance = HistoryService();

  static const String storageKey = 'browse_history';
  static const int maxEntries = 100;

  SharedPreferencesAsync? _prefs;
  final List<ImageItem> _items = <ImageItem>[];
  bool _loaded = false;

  /// 浏览历史（最新在前，只读视图）。
  List<ImageItem> get items => List<ImageItem>.unmodifiable(_items);

  /// 浏览总数（数据概览用）。
  int get count => _items.length;

  SharedPreferencesAsync? get _ensurePrefs {
    try {
      return _prefs ??= SharedPreferencesAsync();
    } catch (_) {
      return null; // 平台实例未设置等：持久化不可用，仅内存。
    }
  }

  /// 从持久化加载（幂等）。
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
        _items
          ..clear()
          ..addAll(
            decoded
                .whereType<Map<String, Object?>>()
                .map(ImageItem.fromJson),
          );
        notifyListeners();
      }
    } catch (_) {
      // 损坏数据容错：保持内存现状。
    }
  }

  /// 记录一次浏览：按 imageUrl 去重（重复项移到最前）。
  Future<void> record(ImageItem item) async {
    _items.removeWhere((ImageItem e) => e.imageUrl == item.imageUrl);
    _items.insert(0, item);
    if (_items.length > maxEntries) {
      _items.removeRange(maxEntries, _items.length);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    if (_items.isEmpty) {
      return;
    }
    _items.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final SharedPreferencesAsync? prefs = _ensurePrefs;
    if (prefs == null) {
      return;
    }
    try {
      await prefs.setString(
        storageKey,
        jsonEncode(_items.map((ImageItem i) => i.toJson()).toList()),
      );
    } catch (_) {
      // IO 异常静默：下次写入重试。
    }
  }
}
