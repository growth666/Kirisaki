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

/// 空结果 fixture：列表容器存在但没有任何 post 节点（对应"没有更多"）。
const String _emptyFixture = '''
<div id="post-list">
  <ul id="post-list-posts"></ul>
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

  testWidgets('空结果显示空态提示', (WidgetTester tester) async {
    final SourceParseService service = SourceParseService(
      client: MockClient(
        (http.Request request) async => http.Response(_emptyFixture, 200),
      ),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('searchInput')), 'none');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();
    await tester.pump();

    expect(find.text('没有找到相关图片，换个关键词试试'), findsOneWidget);
  });

  testWidgets('网络异常显示错误态与重试按钮', (WidgetTester tester) async {
    final SourceParseService service = SourceParseService(
      client: MockClient(
        (http.Request request) async =>
            throw http.ClientException('network down'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('searchInput')), 'test');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();
    await tester.pump();

    expect(find.text('网络连接失败，请检查网络'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('上拉分页：第二页为空时显示"没有更多了"', (WidgetTester tester) async {
    // 缩小测试视口，保证内容溢出可滚动，滚动触底才能触发分页监听。
    await tester.binding.setSurfaceSize(const Size(400, 250));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final SourceParseService service = SourceParseService(
      client: MockClient((http.Request request) async {
        final int page = int.parse(request.url.queryParameters['page'] ?? '1');
        return http.Response(
          page == 1 ? _moebooruFixture : _emptyFixture,
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('searchInput')), 'blue_sky');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();
    await tester.pump();

    expect(find.byType(Card), findsNWidgets(2));

    // 上拉触底触发 _loadMore → 第二页空结果 → hasMore=false。
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('没有更多了'), findsOneWidget);
  });

  testWidgets('连点搜索按钮只发起一次请求（请求锁）', (WidgetTester tester) async {
    int pageOneRequests = 0;
    final SourceParseService service = SourceParseService(
      client: MockClient((http.Request request) async {
        final int page = int.parse(request.url.queryParameters['page'] ?? '1');
        if (page == 1) {
          pageOneRequests++;
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response(
          page == 1 ? _moebooruFixture : _emptyFixture,
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter(service)),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('searchInput')), 'blue_sky');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump(); // 进入加载态，按钮已禁用

    // 第二击：按钮禁用，不应再发起首页请求。
    await tester.tap(find.byIcon(Icons.arrow_forward), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(pageOneRequests, 1);
    // 排空可能的分页请求计时器，避免测试结束时有遗留 Timer。
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  });

  testWidgets('切换图源清空列表回到初始提示', (WidgetTester tester) async {
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
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byType(Card), findsNWidgets(2));

    // 打开图源下拉并选择 konachan.net。
    // DropdownMenu 会同时渲染字段内文本与菜单项文本，用 first/last 消歧。
    await tester.tap(find.text('yande.re').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('konachan.net').last);
    await tester.pumpAndSettle();

    // 切换图源：列表清空、回到初始提示。
    expect(find.byType(Card), findsNothing);
    expect(find.text('输入关键词，搜索二次元图片'), findsOneWidget);
  });
}
