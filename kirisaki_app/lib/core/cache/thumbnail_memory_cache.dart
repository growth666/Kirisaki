import 'dart:typed_data';

/// 缩略图内存缓存（FIFO，仅缓存缩略图，不缓存原图）。
class ThumbnailMemoryCache {
  ThumbnailMemoryCache({this.maxEntries = defaultMaxEntries});

  /// 默认最大缓存条数（防止内存持续上涨）。
  static const int defaultMaxEntries = 200;

  /// 全局共享实例。
  static final ThumbnailMemoryCache instance = ThumbnailMemoryCache();

  /// 缓存上限（超出后按 FIFO 淘汰最旧条目）。
  final int maxEntries;

  // LinkedHashMap 保持插入顺序，即 FIFO 淘汰顺序。
  final Map<String, Uint8List> _entries = <String, Uint8List>{};

  /// 命中返回图片字节，未命中返回 null。
  Uint8List? get(String key) => _entries[key];

  /// 写入缓存；超上限时按 FIFO 淘汰最旧条目。
  /// 重复写入同一 key 时先移除再插入，把该条目移到最新位置。
  void put(String key, Uint8List bytes) {
    _entries.remove(key);
    _entries[key] = bytes;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// 清空缓存。
  void clear() => _entries.clear();

  /// 当前缓存条数。
  int get length => _entries.length;
}
