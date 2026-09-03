import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'source_config.dart';

/// 自定义图源持久化仓库。
///
/// 仅持久化用户新增的**自定义图源**；内置图源（BuiltinSources）
/// 不参与持久化。App 重启后自定义图源不丢失。
/// 使用 [SharedPreferencesAsync]（官方推荐新 API）。
class CustomSourceStore {
  CustomSourceStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  /// 自定义图源存储 key。
  static const String storageKey = 'custom_sources';

  final SharedPreferencesAsync _preferences;

  /// 读取自定义图源列表；无数据或数据损坏时返回空列表（容错不崩溃）。
  Future<List<SourceConfig>> load() async {
    final String? raw = await _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return <SourceConfig>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) {
        return <SourceConfig>[];
      }
      return decoded
          .whereType<Map<String, Object?>>()
          .map(SourceConfig.fromJson)
          .toList();
    } catch (_) {
      // 损坏数据容错：返回空列表，不向调用方抛异常。
      return <SourceConfig>[];
    }
  }

  /// 保存自定义图源列表（整体覆盖写入）。
  Future<void> save(List<SourceConfig> sources) async {
    final String raw =
        jsonEncode(sources.map((SourceConfig s) => s.toJson()).toList());
    await _preferences.setString(storageKey, raw);
  }
}
