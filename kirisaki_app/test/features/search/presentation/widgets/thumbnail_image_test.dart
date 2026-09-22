import 'dart:async';

import 'package:kirisaki_app/core/cache/thumbnail_disk_cache.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kirisaki_app/core/cache/thumbnail_memory_cache.dart';
import 'package:kirisaki_app/features/search/presentation/widgets/thumbnail_image.dart';

/// 1x1 透明 PNG 字节（合法图片数据，避免 Image.memory 解码报错）。
final Uint8List _validPng = Uint8List.fromList(const <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class _DiskCache extends ThumbnailDiskCache {
  final written = Completer<void>();
  @override
  Future<Uint8List?> get(String key) async => null;
  @override
  Future<void> put(String key, Uint8List bytes) => written.future;
}

void main() {
  testWidgets('缓存命中直接展示，不发请求', (WidgetTester tester) async {
    final ThumbnailMemoryCache cache = ThumbnailMemoryCache();
    const String url = 'https://example.test/t.jpg';
    // 预置缓存（VM 环境无代理，缓存 key 即原始 url）。
    cache.put(url, _validPng);
    final http.Client client = MockClient(
      (http.Request request) async => fail('命中缓存不应发请求'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ThumbnailImage(
          url: url,
          client: client,
          cache: cache,
          diskCache: _DiskCache(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('未命中时请求成功并写入缓存', (WidgetTester tester) async {
    final ThumbnailMemoryCache cache = ThumbnailMemoryCache();
    const String url = 'https://example.test/t.jpg';
    final http.Client client = MockClient(
      (http.Request request) async => http.Response.bytes(_validPng, 200),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ThumbnailImage(
          url: url,
          client: client,
          cache: cache,
          diskCache: _DiskCache(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(cache.get(url), _validPng);
  });

  testWidgets('请求失败显示错误占位图标，不写入缓存', (WidgetTester tester) async {
    final ThumbnailMemoryCache cache = ThumbnailMemoryCache();
    final http.Client client = MockClient(
      (http.Request request) async => throw http.ClientException('boom'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ThumbnailImage(
          url: 'https://example.test/t.jpg',
          client: client,
          cache: cache,
          diskCache: _DiskCache(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(cache.length, 0);
  });
}
