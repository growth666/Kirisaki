import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../source/image_item.dart';

/// 收藏图片持久化仓库（仅本地持久化，不同步云端）。
///
/// 复用 [SharedPreferencesAsync]（与 CustomSourceStore 同模式）。
class FavoriteStore {
  FavoriteStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  /// 收藏数据存储 key。
  static const String storageKey = 'favorite_images';

  final SharedPreferencesAsync _preferences;

  /// 读取收藏列表；无数据或数据损坏时返回空列表（容错不崩溃）。
  Future<List<ImageItem>> load() async {
    final String? raw = await _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return <ImageItem>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) {
        return <ImageItem>[];
      }
      return decoded
          .whereType<Map<String, Object?>>()
          .map(ImageItem.fromJson)
          .toList();
    } catch (_) {
      // 损坏数据容错：返回空列表，不向调用方抛异常。
      return <ImageItem>[];
    }
  }

  /// 整体覆盖写入收藏列表。
  Future<void> save(List<ImageItem> items) async {
    final String raw =
        jsonEncode(items.map((ImageItem item) => item.toJson()).toList());
    await _preferences.setString(storageKey, raw);
  }
}
