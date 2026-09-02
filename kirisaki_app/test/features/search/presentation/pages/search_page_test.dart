import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kirisaki_app/core/source/source_parse_service.dart';
import 'package:kirisaki_app/features/preview/presentation/pages/image_preview_page.dart';
import 'package:kirisaki_app/features/search/presentation/pages/search_page.dart';

/// 按 Moebooru 真实结构编写的 fixture（与 BuiltinSources 的选择器对应）。
const String _moebooruFixture = '''
<div id="post-list">
  <ul id="post-list-posts">
    <li id="p101" class="javascript-hide" style="width: 160px;">
      <div class="inner" style="width: 150px; height: 150px;">
        <a class="thumb" href="/post/show/101">
          <img src="/data/preview/a1.jpg" class="preview"
               alt="Rating: safe Score: 5 Tags: blue_sky cloud User: alice"
               title="Rating: safe Score: 5 Tags: blue_sky cloud User: alice"
               width="150" height="100">
        </a>
      </div>
      <a class="directlink largeimg" href="/image/original/a1.jpg"></a>
    </li>
    <li id="p102" class="javascript-hide" style="width: 160px;">
      <div class="inner" style="width: 150px; height: 150px;">
        <a class="thumb" href="/post/show/102">
          <img src="/data/preview/b2.jpg" class="preview"
               alt="Rating: safe Score: 3 Tags: night User: bob"
               title="Rating: safe Score: 3 Tags: night User: bob"
               width="150" height="150">
        </a>
      </div>
      <a class="directlink smallimg" href="/image/original/b2.jpg"></a>
    </li>
  </ul>
</div>
''';

/// 测试专用路由：'/' 挂注入 mock 服务的搜索页，'/preview' 挂预览页。
GoRouter _testRouter(SourceParseService service) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            SearchPage(service: service),
      ),
      GoRoute(
        path: '/preview',
        builder: (BuildContext context, GoRouterState state) =>
            ImagePreviewPage(imageUrl: state.uri.queryParameters['url']),
      ),
    ],
  );
}

void main() {
  testWidgets('初始提示展示', (WidgetTester tester) async {
    final SourceParseService service = SourceParseService(
      client: MockClient(
        (http.Request request) async => http.Response('', 200),
      ),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pump();

    expect(find.text('输入关键词，搜索二次元图片'), findsOneWidget);
  });

  testWidgets('搜索后展示瀑布流卡片，点击跳转预览页', (WidgetTester tester) async {
    final SourceParseService service = SourceParseService(
      client: MockClient((http.Request request) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response(_moebooruFixture, 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('searchInput')), 'blue_sky');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();

    // 加载中：展示加载动画。
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // 瀑布流卡片：两张卡片、标签文本可见。
    expect(find.byType(Card), findsNWidgets(2));
    expect(find.text('#blue_sky'), findsOneWidget);
    expect(find.text('#night'), findsOneWidget);

    // 点击第一张卡片跳转预览页。
    await tester.tap(find.byType(Card).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('图片预览'), findsOneWidget);
    expect(find.textContaining('/image/original/a1.jpg'), findsOneWidget);
  });
}
