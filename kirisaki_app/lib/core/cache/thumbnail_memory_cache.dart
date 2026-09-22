import 'dart:typed_data';

/// 缩略图内存缓存（LRU，仅缓存缩略图，不缓存原图）。
class ThumbnailMemoryCache {
  ThumbnailMemoryCache({
    this.maxEntries = defaultMaxEntries,
    this.maxBytes = 32 * 1024 * 1024,
  }) : assert(maxEntries >= 0),
       assert(maxBytes >= 0);
  final int maxBytes;
  int _sizeBytes = 0;
  int get sizeBytes => _sizeBytes;

  /// 默认最大缓存条数（防止内存持续上涨）。
  static const int defaultMaxEntries = 200;

  /// 全局共享实例。
  static final ThumbnailMemoryCache instance = ThumbnailMemoryCache();

  /// 缓存上限（超出后按 LRU 淘汰最旧条目）。
  final int maxEntries;

  // LinkedHashMap 保持插入顺序，即 LRU 淘汰顺序。
  final Map<String, Uint8List> _entries = <String, Uint8List>{};

  /// 命中返回图片字节，未命中返回 null。
  Uint8List? get(String key) {
    final bytes = _entries.remove(key);
    if (bytes != null) _entries[key] = bytes;
    return bytes;
  }

  /// 写入缓存；超上限时按 LRU 淘汰最旧条目。
  /// 重复写入同一 key 时先移除再插入，把该条目移到最新位置。
  void put(String key, Uint8List bytes) {
    _sizeBytes -= _entries.remove(key)?.length ?? 0;
    if (bytes.length > maxBytes) return;
    _entries[key] = bytes;
    _sizeBytes += bytes.length;
    while (_entries.length > maxEntries || _sizeBytes > maxBytes) {
      _sizeBytes -= _entries.remove(_entries.keys.first)!.length;
    }
  }

  /// 清空缓存。
  void clear() {
    _entries.clear();
    _sizeBytes = 0;
  }

  /// 当前缓存条数。
  int get length => _entries.length;
}
