import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kirisaki_app/core/source/image_item.dart';
import 'package:kirisaki_app/features/preview/presentation/pages/image_preview_page.dart';

void main() {
  setUpAll(() {
    // CachedNetworkImage 默认缓存依赖 path_provider 插件，
    // 测试环境无插件实现，mock 通道返回系统临时目录。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => Directory.systemTemp.path,
    );
  });

  testWidgets('渲染原图区域与标签', (WidgetTester tester) async {
    const ImageItem item = ImageItem(
      imageUrl: 'https://example.test/image/a.jpg',
      tags: <String>['blue_sky', 'cloud'],
    );
    await tester.pumpWidget(
      const MaterialApp(home: ImagePreviewPage(item: item)),
    );
    // 注：测试环境图片网络加载为真实异步 IO，fake-async 下不会收敛，
    // 此处只断言不依赖图片加载结果的结构内容；"图片加载失败"占位组件
    // 属于 CachedNetworkImage errorWidget 路径，以 Web 运行验证（优先 Web 调试）。
    await tester.pump();

    expect(find.text('图片预览'), findsOneWidget);
    expect(find.text('#blue_sky'), findsOneWidget);
    expect(find.text('#cloud'), findsOneWidget);
    expect(find.textContaining('/image/a.jpg'), findsOneWidget);
  });

  testWidgets('无 item 且无 url 时显示未找到图片信息', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ImagePreviewPage()));
    await tester.pump();

    expect(find.text('未找到图片信息'), findsOneWidget);
  });
}
