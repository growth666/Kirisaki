import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:kirisaki_app/core/cache/thumbnail_memory_cache.dart';

void main() {
  test('put/get 与未命中', () {
    final ThumbnailMemoryCache cache = ThumbnailMemoryCache(maxEntries: 2);
    final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);

    expect(cache.get('a'), isNull);
    cache.put('a', bytes);
    expect(cache.get('a'), bytes);
    expect(cache.length, 1);
  });

  test('超过上限按 FIFO 淘汰最旧条目', () {
    final ThumbnailMemoryCache cache = ThumbnailMemoryCache(maxEntries: 2);
    cache.put('a', Uint8List.fromList(<int>[1]));
    cache.put('b', Uint8List.fromList(<int>[2]));
    cache.put('c', Uint8List.fromList(<int>[3]));

    expect(cache.length, 2);
    expect(cache.get('a'), isNull); // 最旧条目被淘汰
    expect(cache.get('b'), isNotNull);
    expect(cache.get('c'), isNotNull);
  });

  test('重复 put 同一 key 更新值并移到最新位置', () {
    final ThumbnailMemoryCache cache = ThumbnailMemoryCache(maxEntries: 2);
    cache.put('a', Uint8List.fromList(<int>[1]));
    cache.put('b', Uint8List.fromList(<int>[2]));
    cache.put('a', Uint8List.fromList(<int>[9])); // 更新 a 并移到最新
    cache.put('c', Uint8List.fromList(<int>[3])); // 淘汰最旧的 b

    expect(cache.get('a'), Uint8List.fromList(<int>[9]));
    expect(cache.get('b'), isNull);
    expect(cache.get('c'), isNotNull);
  });

  test('clear 清空全部条目', () {
    final ThumbnailMemoryCache cache = ThumbnailMemoryCache();
    cache.put('a', Uint8List.fromList(<int>[1]));
    cache.clear();

    expect(cache.length, 0);
    expect(cache.get('a'), isNull);
  });
}
