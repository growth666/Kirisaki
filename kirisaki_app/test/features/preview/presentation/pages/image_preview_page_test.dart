import 'dart:io';

import 'package:flutter/gestures.dart';
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
    // 缩放容器（双指缩放 + 滚轮缩放挂载点）。
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('#blue_sky'), findsOneWidget);
    expect(find.text('#cloud'), findsOneWidget);
    expect(find.textContaining('/image/a.jpg'), findsOneWidget);
  });

  testWidgets('滚轮滚动放大视图矩阵', (WidgetTester tester) async {
    const ImageItem item = ImageItem(
      imageUrl: 'https://example.test/image/a.jpg',
    );
    await tester.pumpWidget(
      const MaterialApp(home: ImagePreviewPage(item: item)),
    );
    await tester.pump();

    // 在图片区域中心派发向上滚动事件（放大）。
    final Offset center = tester.getCenter(find.byType(InteractiveViewer));
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, -100),
      ),
    );
    await tester.pump();

    // InteractiveViewer 内部 Transform 的缩放应大于 1。
    final Transform transform = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(InteractiveViewer),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(transform.transform.getMaxScaleOnAxis(), greaterThan(1.0));
  });

  testWidgets('无 item 且无 url 时显示未找到图片信息', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ImagePreviewPage()));
    await tester.pump();

    expect(find.text('未找到图片信息'), findsOneWidget);
  });

  group('zoomMatrixAt', () {
    test('向上滚动放大、向下滚动缩小', () {
      final Matrix4 zoomed = zoomMatrixAt(
        Matrix4.identity(),
        1.1,
        focal: const Offset(100, 100),
      );
      expect(zoomed.getMaxScaleOnAxis(), closeTo(1.1, 1e-6));

      final Matrix4 back = zoomMatrixAt(
        zoomed,
        1 / 1.1,
        focal: const Offset(100, 100),
      );
      expect(back.getMaxScaleOnAxis(), closeTo(1.0, 1e-6));
    });

    test('缩放被 clamp 到 [1, 8]', () {
      final Matrix4 up = zoomMatrixAt(
        Matrix4.identity(),
        100,
        focal: Offset.zero,
      );
      expect(up.getMaxScaleOnAxis(), closeTo(8.0, 1e-6));

      final Matrix4 down = zoomMatrixAt(
        Matrix4.identity(),
        0.01,
        focal: Offset.zero,
      );
      expect(down.getMaxScaleOnAxis(), closeTo(1.0, 1e-6));
    });

    test('焦点缩放保持焦点位置不变', () {
      const Offset focal = Offset(120, 80);
      final Matrix4 zoomed =
          zoomMatrixAt(Matrix4.identity(), 2.0, focal: focal);

      final Offset mapped = MatrixUtils.transformPoint(zoomed, focal);
      expect(mapped.dx, closeTo(focal.dx, 1e-6));
      expect(mapped.dy, closeTo(focal.dy, 1e-6));
    });

    test('非法因子返回原矩阵', () {
      final Matrix4 identity = Matrix4.identity();
      expect(
        identical(
          zoomMatrixAt(identity, 0, focal: Offset.zero),
          identity,
        ),
        isTrue,
      );
    });
  });
}
