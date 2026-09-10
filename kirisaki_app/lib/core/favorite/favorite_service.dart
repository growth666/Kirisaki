import 'package:flutter/foundation.dart';

import '../source/image_item.dart';
import 'favorite_store.dart';

/// 收藏管理服务：添加/取消收藏、判断是否已收藏、列表去重。
///
/// 继承 [ChangeNotifier]（Flutter 内置，不引入状态管理库），
/// 收藏变更后通知监听者 → 收藏页与预览页收藏按钮状态实时同步。
class FavoriteService extends ChangeNotifier {
  FavoriteService();

  /// 全局共享实例（收藏页/预览页共用同一数据源）。
  static final FavoriteService instance = FavoriteService();

  /// 持久化仓库（惰性创建：仅在实际 load/persist 时触碰平台通道，
  /// 纯内存操作如 contains 不依赖平台实现）。
  FavoriteStore? _store;

  FavoriteStore get _ensureStore => _store ??= FavoriteStore();

  final List<ImageItem> _items = <ImageItem>[];

  /// 是否已从持久化加载过（load 幂等）。
  bool _loaded = false;

  /// 当前收藏列表（按收藏顺序，只读视图）。
  List<ImageItem> get items => List<ImageItem>.unmodifiable(_items);

  /// 从持久化加载收藏列表（幂等：仅首次调用生效）。
  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _items
      ..clear()
      ..addAll(await _ensureStore.load());
    notifyListeners();
  }

  /// [imageUrl] 是否已收藏。
  bool contains(String imageUrl) =>
      _items.any((ImageItem item) => item.imageUrl == imageUrl);

  /// 添加收藏；按 imageUrl 去重（已存在则跳过）。
  Future<void> add(ImageItem item) async {
    if (contains(item.imageUrl)) {
      return;
    }
    _items.add(item);
    notifyListeners();
    await _persist();
  }

  /// 取消收藏 [imageUrl]；不存在则无操作。
  Future<void> remove(String imageUrl) async {
    final int before = _items.length;
    _items.removeWhere((ImageItem item) => item.imageUrl == imageUrl);
    if (_items.length == before) {
      return;
    }
    notifyListeners();
    await _persist();
  }

  /// 批量取消收藏（长按多选删除用）；全部不存在时无操作。
  Future<void> removeAll(Iterable<String> imageUrls) async {
    final Set<String> urls = imageUrls.toSet();
    final int before = _items.length;
    _items.removeWhere((ImageItem item) => urls.contains(item.imageUrl));
    if (_items.length == before) {
      return;
    }
    notifyListeners();
    await _persist();
  }

  /// 清空全部收藏（设置页"清空本地数据"用），一次持久化。
  Future<void> clearAll() async {
    if (_items.isEmpty) {
      return;
    }
    _items.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() => _ensureStore.save(_items);
}
