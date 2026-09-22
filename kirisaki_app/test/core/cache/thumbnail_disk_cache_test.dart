import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kirisaki_app/core/cache/thumbnail_disk_cache_io.dart';

void main() {
  late Directory directory;
  setUp(
    () async => directory = await Directory.systemTemp.createTemp(
      'kirisaki_cache_test_',
    ),
  );
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('long URLs survive writes, overwrite and clearing', () async {
    final cache = ThumbnailDiskCache(directory: directory);
    final key = 'https://example.test/${'a' * 3000}';
    await cache.put(key, Uint8List.fromList([1, 2]));
    expect(await cache.get(key), [1, 2]);
    await cache.put(key, Uint8List.fromList([3]));
    expect(await cache.get(key), [3]);
    expect(await cache.sizeBytes, 1);
    await cache.clear();
    expect(await cache.get(key), isNull);
    await cache.put(key, Uint8List.fromList([4, 5]));
    expect(await cache.get(key), [4, 5]);
    expect(await cache.sizeBytes, 2);
  });

  test('concurrent writes respect capacity and queued clear', () async {
    final cache = ThumbnailDiskCache(directory: directory, maxBytes: 4);
    await Future.wait([
      cache.put('a', Uint8List.fromList([1, 2, 3])),
      cache.put('b', Uint8List.fromList([4, 5, 6])),
    ]);
    expect(await cache.get('a'), isNull);
    expect(await cache.get('b'), [4, 5, 6]);
    expect(await cache.sizeBytes, 3);
    await Future.wait([cache.put('c', Uint8List(2)), cache.clear()]);
    expect(await cache.sizeBytes, 0);
    expect(await cache.get('c'), isNull);
  });

  test(
    'reopening accounts for previous files without discarding entries',
    () async {
      await ThumbnailDiskCache(directory: directory).put('a', Uint8List(3));
      final reopened = ThumbnailDiskCache(directory: directory, maxBytes: 4);
      expect(await reopened.get('a'), hasLength(3));
      expect(await reopened.sizeBytes, 3);
      await reopened.put('b', Uint8List(2));
      expect(await reopened.get('a'), isNull);
      expect(await reopened.sizeBytes, 2);
    },
  );
}
