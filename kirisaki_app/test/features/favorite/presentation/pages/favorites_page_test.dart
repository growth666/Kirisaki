import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kirisaki_app/core/favorite/favorite_service.dart';
import 'package:kirisaki_app/core/source/image_item.dart';
import 'package:kirisaki_app/features/favorite/presentation/pages/favorites_page.dart';
import 'package:kirisaki_app/features/preview/presentation/pages/image_preview_page.dart';

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
}
