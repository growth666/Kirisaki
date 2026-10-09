import 'package:flutter/foundation.dart';

import '../source/image_item.dart';
import 'favorite_store.dart';

class FavoriteService extends ChangeNotifier {
  FavoriteService({FavoriteStore? store}) : _store = store ?? FavoriteStore();
  static final FavoriteService instance = FavoriteService();
  FavoriteStore? _store;
  FavoriteStore get _ensureStore => _store ??= FavoriteStore();
  List<ImageItem> _items = [];
  bool _loaded = false;
  Future<void>? _loading;
  Future<void> _queue = Future.value();
  String? loadError;
  List<ImageItem> get items => List.unmodifiable(_items);
  bool contains(String url) => _items.any((item) => item.imageUrl == url);

  Future<void> load() {
    if (_loaded) return Future.value();
    return _loading ??= _read().whenComplete(() => _loading = null);
  }

  Future<void> _read() async {
    try {
      final stored = await _ensureStore.load();
      final changed = stored.isNotEmpty || loadError != null;
      _items = stored;
      _loaded = true;
      loadError = null;
      if (changed) notifyListeners();
    } catch (_) {
      loadError = '收藏读取失败，原数据已保留，请重试';
      notifyListeners();
    }
  }

  Future<void> _change(void Function(List<ImageItem>) edit) {
    final operation = _queue.then((_) async {
      await load();
      if (!_loaded) throw StateError(loadError!);
      final next = [..._items];
      edit(next);
      if (listEquals(next, _items)) return;
      await _ensureStore.save(next);
      _items = next;
      notifyListeners();
    });
    _queue = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<void> add(ImageItem item) => _change((next) {
    if (!next.any((e) => e.imageUrl == item.imageUrl)) next.add(item);
  });
  Future<void> remove(String url) =>
      _change((next) => next.removeWhere((e) => e.imageUrl == url));
  Future<void> removeAll(Iterable<String> urls) {
    final selected = urls.toSet();
    return _change(
      (next) => next.removeWhere((e) => selected.contains(e.imageUrl)),
    );
  }

  Future<void> clearAll() => _change((next) => next.clear());
}
