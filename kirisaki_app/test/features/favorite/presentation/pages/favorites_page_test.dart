import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kirisaki_app/core/favorite/favorite_service.dart';
import 'package:kirisaki_app/core/source/image_item.dart';
import 'package:kirisaki_app/features/favorite/presentation/pages/favorites_page.dart';
import 'package:kirisaki_app/features/preview/presentation/pages/image_preview_page.dart';
import 'package:kirisaki_app/features/search/presentation/widgets/thumbnail_image.dart';

/// 测试专用路由：收藏页 + 复用现有预览页（extra 传完整 ImageItem）。
GoRouter _router(FavoriteService service) {
  return GoRouter(
    initialLocation: '/favorites',
    routes: <RouteBase>[
      GoRoute(
        path: '/favorites',
        builder: (BuildContext context, GoRouterState state) =>
            FavoritesPage(favoriteService: service),
      ),
      GoRoute(
        path: '/preview',
        builder: (BuildContext context, GoRouterState state) =>
            ImagePreviewPage(
          item: state.extra is ImageItem ? state.extra! as ImageItem : null,
          imageUrl: state.uri.queryParameters['url'],
        ),
      ),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('空收藏显示空态提示', (WidgetTester tester) async {
    final FavoriteService service = FavoriteService();
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(service)),
    );
    await tester.pump();

    expect(find.text('暂无收藏'), findsOneWidget);
  });

  testWidgets('收藏列表渲染并点击跳转复用预览页', (WidgetTester tester) async {
    final FavoriteService service = FavoriteService();
    await service.add(const ImageItem(
      imageUrl: 'https://example.test/f.jpg',
      tags: <String>['fav'],
    ));

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(service)),
    );
    await tester.pump();

    expect(find.text('#fav'), findsOneWidget);

    await tester.tap(find.byType(Card));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('图片预览'), findsOneWidget);
    expect(find.textContaining('/f.jpg'), findsOneWidget);
  });

  testWidgets('统计显示与倒序排列（最新收藏在前）', (WidgetTester tester) async {
    final FavoriteService service = FavoriteService();
    // 先收藏 a，再收藏 b → 页面按倒序展示，b 排在第一张。
    await service.add(const ImageItem(imageUrl: 'https://example.test/a.jpg'));
    await service.add(const ImageItem(imageUrl: 'https://example.test/b.jpg'));

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(service)),
    );
    await tester.pump();

    expect(find.text('共 2 张'), findsOneWidget);
    expect(service.items, hasLength(2)); // 服务本身按添加序存储

    // 页面倒序展示：第一张卡片的缩略图应为 b.jpg。
    final ThumbnailImage first = tester.widget<ThumbnailImage>(
      find.descendant(
        of: find.byType(Card).first,
        matching: find.byType(ThumbnailImage),
      ),
    );
    expect(first.url, contains('b.jpg'));
  });

  testWidgets('长按进入多选删除，统计实时更新', (WidgetTester tester) async {
    final FavoriteService service = FavoriteService();
    await service.add(const ImageItem(imageUrl: 'https://example.test/a.jpg'));
    await service.add(const ImageItem(imageUrl: 'https://example.test/b.jpg'));

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(service)),
    );
    await tester.pump();

    expect(find.text('共 2 张'), findsOneWidget);

    // 长按第一张卡片进入选择模式。
    await tester.longPress(find.byType(Card).first);
    await tester.pump();

    expect(find.text('已选 1 张'), findsOneWidget);

    // 点选第二张 → 已选 2 张。
    await tester.tap(find.byType(Card).last);
    await tester.pump();
    expect(find.text('已选 2 张'), findsOneWidget);

    // 删除全部选中。
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.pump();

    // 收藏清空，退出选择模式，回到空态。
    expect(service.items, isEmpty);
    expect(find.text('暂无收藏'), findsOneWidget);
  });
}
